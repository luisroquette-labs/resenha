using System.Text.Json;
using Resenha.Core;

return Run(args);

static int Run(string[] args)
{
    try
    {
        var options = Parse(args);
        using var artifact = OpenFile(options, "artifact");
        using var hosted = options.TryGetValue("hosted-artifact", out var hostedPath) ? OpenChecked(hostedPath) : null;
        var payload = OpenTree(Required(options, "payload"));
        try
        {
            var evidence = ReadTree(Required(options, "evidence"));
            var decision = ReleasePolicy.Evaluate(
                File.ReadAllText(Required(options, "manifest")),
                File.ReadAllText(Required(options, "schema")),
                new ReleaseEvidenceInputs(
                    Required(options, "source-commit"),
                    Required(options, "publisher"),
                    Required(options, "certificate-thumbprint").ToUpperInvariant(),
                    Required(options, "verifier-sha256").ToLowerInvariant(),
                    DateTimeOffset.UtcNow,
                    artifact,
                    payload,
                    evidence,
                    hosted));
            Console.WriteLine(JsonSerializer.Serialize(new
            {
                contractValid = decision.ContractValid,
                candidateReady = decision.CandidateReady,
                hostedReady = decision.HostedReady,
                canEnablePublicDownload = decision.CanEnablePublicDownload,
                errors = decision.Errors
            }));
            return decision.CandidateReady ? 0 : 2;
        }
        finally
        {
            foreach (var stream in payload.Values) stream.Dispose();
        }
    }
    catch (Exception exception) when (exception is ArgumentException or IOException or UnauthorizedAccessException or JsonException or FormatException)
    {
        Console.Error.WriteLine(JsonSerializer.Serialize(new { contractValid = false, error = exception.Message }));
        return 2;
    }
}

static Dictionary<string, string> Parse(string[] args)
{
    if (args.Length == 0 || args.Length % 2 != 0) throw new ArgumentException("Arguments must be --name value pairs.");
    var result = new Dictionary<string, string>(StringComparer.Ordinal);
    for (var index = 0; index < args.Length; index += 2)
    {
        if (!args[index].StartsWith("--", StringComparison.Ordinal) || args[index].Length < 3 || !result.TryAdd(args[index][2..], args[index + 1]))
            throw new ArgumentException("Unknown or duplicate verifier argument.");
    }
    var allowed = new HashSet<string>(["manifest", "schema", "artifact", "payload", "evidence", "source-commit", "publisher", "certificate-thumbprint", "verifier-sha256", "hosted-artifact"], StringComparer.Ordinal);
    if (result.Keys.Any(key => !allowed.Contains(key))) throw new ArgumentException("Unknown verifier argument.");
    return result;
}

static string Required(IReadOnlyDictionary<string, string> options, string key) =>
    options.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value) ? value : throw new ArgumentException($"Missing --{key}.");

static FileStream OpenFile(IReadOnlyDictionary<string, string> options, string key) => OpenChecked(Required(options, key));

static FileStream OpenChecked(string path)
{
    var info = new FileInfo(Path.GetFullPath(path));
    if (!info.Exists || info.LinkTarget is not null || info.Attributes.HasFlag(FileAttributes.ReparsePoint)) throw new IOException($"Unsafe or missing file: {path}");
    return new FileStream(info.FullName, FileMode.Open, FileAccess.Read, FileShare.Read);
}

static Dictionary<string, Stream> OpenTree(string root)
{
    var files = EnumerateTree(root);
    return files.ToDictionary(item => item.Relative, item => (Stream)OpenChecked(item.Full), StringComparer.Ordinal);
}

static Dictionary<string, ReadOnlyMemory<byte>> ReadTree(string root)
{
    var files = EnumerateTree(root);
    return files.ToDictionary(item => item.Relative, item => (ReadOnlyMemory<byte>)File.ReadAllBytes(item.Full), StringComparer.Ordinal);
}

static List<(string Full, string Relative)> EnumerateTree(string root)
{
    var directory = new DirectoryInfo(Path.GetFullPath(root));
    if (!directory.Exists || directory.LinkTarget is not null || directory.Attributes.HasFlag(FileAttributes.ReparsePoint)) throw new IOException($"Unsafe or missing directory: {root}");
    var items = new List<(string Full, string Relative)>();
    foreach (var path in Directory.EnumerateFiles(directory.FullName, "*", SearchOption.AllDirectories))
    {
        var info = new FileInfo(path);
        if (info.LinkTarget is not null || info.Attributes.HasFlag(FileAttributes.ReparsePoint)) throw new IOException($"Reparse points are forbidden: {path}");
        var relative = Path.GetRelativePath(directory.FullName, info.FullName).Replace('\\', '/');
        if (relative.StartsWith("../", StringComparison.Ordinal) || relative.Contains("/../", StringComparison.Ordinal)) throw new IOException($"Escaped tree path: {path}");
        items.Add((info.FullName, relative));
    }
    if (items.Count == 0) throw new IOException($"Directory contains no files: {root}");
    if (items.Select(item => item.Relative).Distinct(StringComparer.OrdinalIgnoreCase).Count() != items.Count) throw new IOException("Case-insensitive file collision.");
    return items;
}
