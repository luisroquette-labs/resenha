using System.Collections.Immutable;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Resenha.Core;

/// <summary>Independently supplied verifier inputs, never inferred from the manifest being checked.</summary>
public sealed record ReleaseEvidenceInputs(
    string ExpectedSourceCommit,
    string ExpectedPublisher,
    string ExpectedCertificateThumbprint,
    string ExpectedVerifierSha256,
    DateTimeOffset EvaluationTimeUtc,
    Stream Artifact,
    IReadOnlyDictionary<string, Stream> ExtractedPayload,
    IReadOnlyDictionary<string, ReadOnlyMemory<byte>> EvidenceFiles,
    Stream? HostedArtifact = null);

/// <summary>Synthetic contracts may validate, but can never become release-ready.</summary>
public sealed record ReleaseDecision(bool ContractValid, bool CandidateReady, bool HostedReady, ImmutableArray<string> Errors)
{
    public bool CanEnablePublicDownload => HostedReady;
}

/// <summary>
/// Pure, deterministic release boundary. This consumes supplied seekable streams, not the filesystem or clock.
/// The Windows verifier must independently extract/enumerate the payload, inspect real signatures/scans and
/// retain observations before calling it. Hashes establish consistency, not authenticity of human observations.
/// </summary>
public static class ReleasePolicy
{
    public const string SchemaSha256 = "3fc71b746406b7f5c9191282e0165a1c91d7dc3aa9cba2a16e885d1eb8802d59";
    private static readonly string[] RequiredPayload = ["Resenha.exe", "Resenha.TargetBroker.exe", "native/whisper-cli.exe", "unins000.exe"];

    public static ReleaseDecision Evaluate(string manifestJson, string schemaJson, ReleaseEvidenceInputs inputs)
    {
        ArgumentNullException.ThrowIfNull(inputs);
        var errors = new List<string>();
        try
        {
            Require(Hash(Encoding.UTF8.GetBytes(schemaJson)) == SchemaSha256, "schema.identity");
            using var schema = JsonDocument.Parse(schemaJson);
            using var manifest = JsonDocument.Parse(manifestJson);
            RejectDuplicateKeys(manifest.RootElement);
            ValidateShape(manifest.RootElement, schema.RootElement, schema.RootElement, "$", errors);
            if (errors.Count != 0) return Blocked(errors);
            var root = manifest.RootElement;
            Require(Regex.IsMatch(inputs.ExpectedSourceCommit, "^[0-9a-f]{40}$", RegexOptions.CultureInvariant), "expected.source");
            Require(!string.IsNullOrWhiteSpace(inputs.ExpectedPublisher), "expected.publisher");
            Require(Regex.IsMatch(inputs.ExpectedCertificateThumbprint, "^[0-9A-F]{40}$", RegexOptions.CultureInvariant), "expected.certificate");
            Require(Regex.IsMatch(inputs.ExpectedVerifierSha256, "^[0-9a-f]{64}$", RegexOptions.CultureInvariant), "expected.verifier");
            Require(inputs.EvaluationTimeUtc.Offset == TimeSpan.Zero, "expected.utc");
            ValidateIdentity(root, inputs);
            ValidatePayload(root, inputs);
            ValidateSignatures(root, inputs);
            ValidateScan(root, inputs);
            ValidatePhysical(root, inputs);
            ValidateHosting(root, inputs);
            ValidateReports(root, inputs);
            var verification = root.GetProperty("verification");
            Require(S(verification, "toolSha256") == inputs.ExpectedVerifierSha256, "verification.tool");
            Require(S(verification, "sourceCommit") == inputs.ExpectedSourceCommit, "verification.source");
            Require(S(verification, "artifactSha256") == S(root, "sha256"), "verification.artifact");
            Require(S(verification, "payloadInventorySha256") == S(root.GetProperty("payload"), "inventorySha256"), "verification.payload");
            Require(S(verification, "stage") == S(root, "stage"), "verification.stage");
            var verifiedAt = Time(verification, "verifiedAtUtc", inputs);
            var lastObservation = root.GetProperty("physical").EnumerateArray().Max(run => Time(run, "observedAtUtc", inputs));
            if (root.GetProperty("hosting").ValueKind != JsonValueKind.Null)
                lastObservation = Time(root.GetProperty("hosting"), "downloadedAtUtc", inputs);
            Require(verifiedAt >= lastObservation, "verification.order");
            var observed = S(root, "evidenceClass") == "observed";
            return new(true, observed, observed && S(root, "stage") == "hosted-ready", []);
        }
        catch (Exception exception) when (exception is JsonException or InvalidOperationException or KeyNotFoundException or FormatException or ArgumentException or IOException or NotSupportedException or OverflowException or RegexMatchTimeoutException)
        {
            errors.Add(exception is EvidenceException ? exception.Message : "malformed-or-unreadable-evidence");
            return Blocked(errors);
        }
    }

    public static string ExpectedAssetUrl(string version) =>
        $"https://github.com/luisroquette/resenha/releases/download/windows-v{version}/Resenha-{version}-windows-x64-setup.exe";

    private static void ValidateIdentity(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var version = S(root, "version");
        Require(S(root, "filename") == $"Resenha-{version}-windows-x64-setup.exe", "identity.filename");
        Require(S(root, "sourceCommit") == inputs.ExpectedSourceCommit, "identity.source");
        var actual = Measure(inputs.Artifact);
        Require(actual.IsPe, "artifact.pe");
        Require(actual.Hash == S(root, "sha256") && actual.Length == N(root, "byteLength"), "artifact.bytes");
        var build = root.GetProperty("build");
        Require(S(build, "sourceCommit") == inputs.ExpectedSourceCommit && S(build.GetProperty("preflight"), "sourceCommit") == inputs.ExpectedSourceCommit, "build.source");
        ValidateOs(build.GetProperty("host").GetProperty("os"), "windows11");
        _ = Time(build, "recordedAtUtc", inputs);
        var inputPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var input in build.GetProperty("inputs").EnumerateArray())
        {
            Require(inputPaths.Add(S(input, "path")), "build.duplicate-input");
            VerifyFile(input, inputs);
        }
        foreach (var path in new[] { "Windows/global.json", "Windows/toolchain-lock.json", "Windows/native/CMakePresets.json", "Windows/model-manifest.json" })
            Require(inputPaths.Contains(path), "build.missing-input:" + path);
        foreach (var project in new[] { "Resenha.Core", "Resenha.Core.Tests", "Resenha.Platform", "Resenha.Platform.Tests", "Resenha.ReleaseVerifier", "Resenha.TargetBroker", "Resenha.Windows" })
            Require(inputPaths.Contains($"Windows/{project}/packages.lock.json"), "build.dependency-locks");
        VerifyFile(build.GetProperty("preflight").GetProperty("report"), inputs);
    }

    private static void ValidatePayload(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var payload = root.GetProperty("payload");
        var files = payload.GetProperty("files");
        Require(Hash(CanonicalBytes(files)) == S(payload, "inventorySha256"), "payload.inventory-hash");
        Require(files.GetArrayLength() == inputs.ExtractedPayload.Count, "payload.inventory-count");
        var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        string? previous = null;
        foreach (var file in files.EnumerateArray())
        {
            var path = S(file, "path");
            SafePath(path);
            Require(paths.Add(path), "payload.duplicate-path");
            Require(previous is null || string.CompareOrdinal(previous, path) < 0, "payload.inventory-order");
            previous = path;
            Require(inputs.ExtractedPayload.TryGetValue(path, out var stream), "payload.missing-file");
            var actual = Measure(stream!);
            Require(actual.Hash == S(file, "sha256") && actual.Length == N(file, "byteLength"), "payload.bytes");
            Require(actual.IsPe == file.GetProperty("isPe").GetBoolean(), "payload.pe-classification");
            if (path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || path.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
                Require(actual.IsPe, "payload.invalid-pe");
        }
        foreach (var path in RequiredPayload) Require(paths.Contains(path), "payload.required-pe:" + path);
    }

    private static void ValidateSignatures(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var signatures = root.GetProperty("signatures");
        Require(S(signatures, "publisher") == inputs.ExpectedPublisher && S(signatures, "certificateThumbprint") == inputs.ExpectedCertificateThumbprint, "signatures.publisher");
        var verifiedAt = Time(signatures, "verifiedAtUtc", inputs);
        Require(verifiedAt >= Time(root.GetProperty("build"), "recordedAtUtc", inputs), "signatures.order");
        var expected = root.GetProperty("payload").GetProperty("files").EnumerateArray()
            .Where(file => file.GetProperty("isPe").GetBoolean()).ToDictionary(file => S(file, "path"), file => S(file, "sha256"), StringComparer.Ordinal);
        expected.Add(S(root, "filename"), S(root, "sha256"));
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var signature in signatures.GetProperty("items").EnumerateArray())
        {
            var path = S(signature, "path");
            Require(seen.Add(path) && expected.TryGetValue(path, out var hash) && hash == S(signature, "sha256"), "signatures.inventory");
            var isReleaseSignature = S(signature, "authority") == "release";
            if (isReleaseSignature)
                Require(S(signature, "publisher") == inputs.ExpectedPublisher && S(signature, "certificateThumbprint") == inputs.ExpectedCertificateThumbprint, "signatures.certificate");
            else
                Require(!RequiredPayload.Contains(path, StringComparer.OrdinalIgnoreCase) && !string.Equals(path, S(root, "filename"), StringComparison.OrdinalIgnoreCase), "signatures.owned-publisher");
            var signedAt = Time(signature.GetProperty("timestamp"), "atUtc", inputs);
            var notBefore = ParseUtc(S(signature, "certificateNotBeforeUtc"));
            var notAfter = ParseUtc(S(signature, "certificateNotAfterUtc"));
            Require(notBefore < notAfter && signedAt >= notBefore && signedAt <= notAfter && signedAt <= verifiedAt, "signatures.certificate-time");
            if (isReleaseSignature)
                Require(signedAt >= Time(root.GetProperty("build"), "recordedAtUtc", inputs), "signatures.timestamp-order");
        }
        Require(seen.Count == expected.Count, "signatures.incomplete-pe-inventory");
    }

    private static void ValidateScan(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var scan = root.GetProperty("scan");
        Require(S(scan, "artifactSha256") == S(root, "sha256"), "scan.artifact");
        Require(S(scan, "payloadInventorySha256") == S(root.GetProperty("payload"), "inventorySha256"), "scan.payload");
        var definitions = Time(scan, "signatureUpdatedAtUtc", inputs);
        var kinds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var target in scan.GetProperty("targets").EnumerateArray())
        {
            Require(kinds.Add(S(target, "kind")), "scan.targets");
            var start = Time(target, "startedAtUtc", inputs);
            var end = Time(target, "completedAtUtc", inputs);
            Require(start >= Time(root.GetProperty("signatures"), "verifiedAtUtc", inputs) && end >= start, "scan.order");
            Require(definitions <= start && end - definitions <= TimeSpan.FromHours(24), "scan.definitions-age");
            VerifyFile(target.GetProperty("detailReport"), inputs);
        }
        Require(kinds.SetEquals(["installer", "payload"]), "scan.coverage");
    }

    private static void ValidatePhysical(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var osNames = new HashSet<string>(StringComparer.Ordinal);
        var scanEnd = root.GetProperty("scan").GetProperty("targets").EnumerateArray().Max(target => Time(target, "completedAtUtc", inputs));
        foreach (var run in root.GetProperty("physical").EnumerateArray())
        {
            var os = run.GetProperty("os");
            var name = S(os, "name");
            Require(osNames.Add(name), "physical.duplicate-os");
            ValidateOs(os, name);
            Require(Time(run, "observedAtUtc", inputs) >= scanEnd, "physical.order");
            Require(S(run, "sourceCommit") == inputs.ExpectedSourceCommit && S(run, "appVersion") == S(root, "version"), "physical.source-version");
            Require(S(run, "artifactSha256") == S(root, "sha256") && N(run, "artifactByteLength") == N(root, "byteLength"), "physical.artifact");
            Require(JsonElement.DeepEquals(run.GetProperty("model"), root.GetProperty("model")), "physical.model");
            var numbers = run.GetProperty("cycles").EnumerateArray().Select(cycle => N(cycle, "number")).ToHashSet();
            Require(numbers.SetEquals(Enumerable.Range(1, 10).Select(number => (long)number)), "physical.ten-cycles");
            var languages = new HashSet<string>(StringComparer.Ordinal);
            foreach (var result in run.GetProperty("corpus").EnumerateArray())
            {
                var language = S(result, "language");
                Require(languages.Add(language), "physical.duplicate-language");
                var retention = result.GetProperty("anglicismRetention");
                Require(language == "en"
                    ? retention.ValueKind == JsonValueKind.String && retention.GetString() == "not-applicable"
                    : retention.ValueKind == JsonValueKind.Number && retention.GetDecimal() >= 0.9m && retention.GetDecimal() <= 1m,
                    "physical.anglicism-retention");
                VerifyFile(result.GetProperty("report"), inputs);
            }
            Require(languages.SetEquals(["pt", "en", "es"]), "physical.languages");
        }
        Require(osNames.SetEquals(["windows10", "windows11"]), "physical.os-coverage");
    }

    private static void ValidateHosting(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var hosting = root.GetProperty("hosting");
        var hosted = S(root, "stage") == "hosted-ready";
        Require(hosted == (hosting.ValueKind != JsonValueKind.Null), "hosting.stage");
        if (!hosted) return;
        Require(S(hosting, "url") == ExpectedAssetUrl(S(root, "version")), "hosting.url");
        Require(S(hosting, "releaseTag") == "windows-v" + S(root, "version"), "hosting.tag");
        Require(S(hosting, "downloadedSha256") == S(root, "sha256") && N(hosting, "downloadedByteLength") == N(root, "byteLength"), "hosting.bytes");
        Require(inputs.HostedArtifact is not null, "hosting.missing-downloaded-bytes");
        var downloaded = Measure(inputs.HostedArtifact!);
        Require(downloaded.Hash == S(root, "sha256") && downloaded.Length == N(root, "byteLength"), "hosting.downloaded-bytes");
        Require(S(hosting, "publisherDisplay") == inputs.ExpectedPublisher, "hosting.publisher");
        ValidateOs(hosting.GetProperty("os"), S(hosting.GetProperty("os"), "name"));
        Require(Time(hosting, "downloadedAtUtc", inputs) >= root.GetProperty("physical").EnumerateArray().Max(run => Time(run, "observedAtUtc", inputs)), "hosting.order");
        if (S(hosting, "smartScreen") == "reputation-warning")
            Require(!string.IsNullOrWhiteSpace(S(hosting, "reputationDisclosure")), "hosting.reputation-disclosure");
        VerifyFile(hosting.GetProperty("detailReport"), inputs);
    }

    private static void ValidateReports(JsonElement root, ReleaseEvidenceInputs inputs)
    {
        var groups = new List<(string Kind, JsonElement Group, string[] Dependencies)>
        {
            ("build", root.GetProperty("build"), []),
            ("payload", root.GetProperty("payload"), ["build"]),
            ("signatures", root.GetProperty("signatures"), ["payload"]),
            ("scan", root.GetProperty("scan"), ["signatures"])
        };
        foreach (var run in root.GetProperty("physical").EnumerateArray())
            groups.Add(("physical-" + S(run.GetProperty("os"), "name"), run, ["scan"]));
        if (root.GetProperty("hosting").ValueKind != JsonValueKind.Null)
            groups.Add(("hosting", root.GetProperty("hosting"), ["physical-windows10", "physical-windows11"]));
        groups.Add(("verification", root.GetProperty("verification"), groups.Select(group => group.Kind).ToArray()));
        var references = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
        foreach (var (kind, group, dependencies) in groups)
        {
            var reference = group.GetProperty("report");
            Require(S(reference, "path") == $"reports/{kind}-{S(reference, "sha256")}.json", "report.immutable-path");
            var bytes = VerifyFile(reference, inputs);
            using var document = JsonDocument.Parse(bytes);
            var report = document.RootElement;
            RejectDuplicateKeys(report);
            Require(report.ValueKind == JsonValueKind.Object && report.EnumerateObject().Select(property => property.Name).ToHashSet(StringComparer.Ordinal)
                .SetEquals(["schemaVersion", "kind", "evidenceClass", "sourceCommit", "artifactSha256", "dependsOn", "observations"]), "report.fields");
            Require(N(report, "schemaVersion") == 1 && S(report, "kind") == kind, "report.kind");
            Require(S(report, "evidenceClass") == S(root, "evidenceClass") && S(report, "sourceCommit") == inputs.ExpectedSourceCommit && S(report, "artifactSha256") == S(root, "sha256"), "report.identity");
            var expectedDependencies = JsonSerializer.SerializeToElement(dependencies.Select(dependency => references[dependency]).ToArray());
            Require(JsonElement.DeepEquals(report.GetProperty("dependsOn"), expectedDependencies), "report.dag");
            var observations = JsonSerializer.SerializeToElement(group.EnumerateObject().Where(property => property.Name != "report").ToDictionary(property => property.Name, property => property.Value));
            Require(JsonElement.DeepEquals(report.GetProperty("observations"), observations), "report.projection");
            references.Add(kind, reference);
        }
    }

    private static ReadOnlyMemory<byte> VerifyFile(JsonElement reference, ReleaseEvidenceInputs inputs)
    {
        var path = S(reference, "path");
        SafePath(path);
        Require(inputs.EvidenceFiles.TryGetValue(path, out var bytes), "report.missing:" + path);
        Require(Hash(bytes.Span) == S(reference, "sha256"), "report.hash:" + path);
        return bytes;
    }

    private static void SafePath(string path) => Require(path.Length <= 512 && !path.StartsWith('/') && !path.Contains('\\') && !path.Contains(':') && path.Split('/').All(part => part.Length > 0 && part != "." && part != ".." && !part.EndsWith('.') && !part.EndsWith(' ')), "evidence.path");

    private static void ValidateOs(JsonElement os, string name)
    {
        Require(name is "windows10" or "windows11", "os.name");
        var prefix = name == "windows10" ? "10.0.19045." : "10.0.26200.";
        Require(S(os, "name") == name && S(os, "release") == (name == "windows10" ? "22H2" : "25H2") && S(os, "build").StartsWith(prefix, StringComparison.Ordinal), "os.release-build");
    }

    private static DateTimeOffset ParseUtc(string value) => DateTimeOffset.ParseExact(value, "yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal);
    private static DateTimeOffset Time(JsonElement value, string key, ReleaseEvidenceInputs inputs)
    {
        var result = ParseUtc(S(value, key));
        Require(result <= inputs.EvaluationTimeUtc, "evidence.future-time");
        return result;
    }

    private static (string Hash, long Length, bool IsPe) Measure(Stream stream)
    {
        Require(stream.CanRead && stream.CanSeek, "artifact.seekable-stream-required");
        stream.Position = 0;
        var isPe = stream.ReadByte() == 'M' && stream.ReadByte() == 'Z';
        stream.Position = 0;
        return (Convert.ToHexStringLower(SHA256.HashData(stream)), stream.Length, isPe);
    }

    private static byte[] CanonicalBytes(JsonElement value)
    {
        using var output = new MemoryStream();
        using (var writer = new Utf8JsonWriter(output, new JsonWriterOptions { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping })) WriteCanonical(writer, value);
        return output.ToArray();
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement value)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in value.EnumerateObject().OrderBy(property => property.Name, StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteCanonical(writer, property.Value);
                }
                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in value.EnumerateArray()) WriteCanonical(writer, item);
                writer.WriteEndArray();
                break;
            default: value.WriteTo(writer); break;
        }
    }

    // Deliberately bounded to this pinned schema's keywords; this is not a general JSON Schema implementation.
    private static void ValidateShape(JsonElement value, JsonElement rule, JsonElement schema, string path, List<string> errors)
    {
        if (rule.TryGetProperty("$ref", out var reference))
        {
            ValidateShape(value, schema.GetProperty("$defs").GetProperty(reference.GetString()![8..]), schema, path, errors);
            return;
        }
        if (rule.TryGetProperty("oneOf", out var choices))
        {
            var matches = 0;
            foreach (var choice in choices.EnumerateArray())
            {
                var trial = new List<string>();
                ValidateShape(value, choice, schema, path, trial);
                if (trial.Count == 0) matches++;
            }
            if (matches != 1) errors.Add(path + ":oneOf");
            return;
        }
        if (rule.TryGetProperty("const", out var constant) && !JsonElement.DeepEquals(value, constant)) errors.Add(path + ":const");
        if (rule.TryGetProperty("enum", out var options) && !options.EnumerateArray().Any(option => JsonElement.DeepEquals(option, value))) errors.Add(path + ":enum");
        if (rule.TryGetProperty("type", out var type))
        {
            var matches = type.GetString() switch
            {
                "object" => value.ValueKind == JsonValueKind.Object,
                "array" => value.ValueKind == JsonValueKind.Array,
                "string" => value.ValueKind == JsonValueKind.String,
                "integer" => value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out _),
                "number" => value.ValueKind == JsonValueKind.Number,
                "boolean" => value.ValueKind is JsonValueKind.True or JsonValueKind.False,
                "null" => value.ValueKind == JsonValueKind.Null,
                _ => false
            };
            if (!matches) { errors.Add(path + ":type"); return; }
        }
        if (value.ValueKind == JsonValueKind.Object && rule.TryGetProperty("properties", out var properties))
        {
            foreach (var required in rule.GetProperty("required").EnumerateArray())
                if (!value.TryGetProperty(required.GetString()!, out _)) errors.Add(path + ":missing:" + required.GetString());
            foreach (var property in value.EnumerateObject())
            {
                if (properties.TryGetProperty(property.Name, out var child)) ValidateShape(property.Value, child, schema, path + "." + property.Name, errors);
                else errors.Add(path + ":unknown:" + property.Name);
            }
        }
        if (value.ValueKind == JsonValueKind.Array && rule.TryGetProperty("items", out var itemRule))
        {
            var items = value.EnumerateArray().ToArray();
            if (items.Length < rule.GetProperty("minItems").GetInt32() || items.Length > rule.GetProperty("maxItems").GetInt32()) errors.Add(path + ":length");
            for (var index = 0; index < items.Length; index++)
            {
                ValidateShape(items[index], itemRule, schema, path + "[" + index.ToString(CultureInfo.InvariantCulture) + "]", errors);
                if (items.Take(index).Any(previous => JsonElement.DeepEquals(previous, items[index]))) errors.Add(path + ":duplicate");
            }
        }
        if (value.ValueKind == JsonValueKind.String)
        {
            var text = value.GetString()!;
            if (rule.TryGetProperty("pattern", out var pattern) && !Regex.IsMatch(text, pattern.GetString()!, RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1))) errors.Add(path + ":pattern");
            if (rule.TryGetProperty("minLength", out var min) && text.Length < min.GetInt32()) errors.Add(path + ":minLength");
            if (rule.TryGetProperty("maxLength", out var max) && text.Length > max.GetInt32()) errors.Add(path + ":maxLength");
        }
        if (value.ValueKind == JsonValueKind.Number)
        {
            if (rule.TryGetProperty("minimum", out var min) && value.GetDecimal() < min.GetDecimal()) errors.Add(path + ":minimum");
            if (rule.TryGetProperty("maximum", out var max) && value.GetDecimal() > max.GetDecimal()) errors.Add(path + ":maximum");
        }
    }

    private static void RejectDuplicateKeys(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Object)
        {
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in value.EnumerateObject())
            {
                Require(names.Add(property.Name), "json.duplicate-key");
                RejectDuplicateKeys(property.Value);
            }
        }
        else if (value.ValueKind == JsonValueKind.Array)
            foreach (var item in value.EnumerateArray()) RejectDuplicateKeys(item);
    }

    private static string Hash(ReadOnlySpan<byte> bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));
    private static string S(JsonElement element, string key) => element.GetProperty(key).GetString() ?? throw new EvidenceException("null:" + key);
    private static long N(JsonElement element, string key) => element.GetProperty(key).GetInt64();
    private static void Require(bool condition, string code) { if (!condition) throw new EvidenceException(code); }
    private static ReleaseDecision Blocked(IEnumerable<string> errors) => new(false, false, false, errors.ToImmutableArray());
    private sealed class EvidenceException(string code) : InvalidOperationException(code);
}
