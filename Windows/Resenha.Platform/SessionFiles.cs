using Resenha.Core;

namespace Resenha.Platform;

public sealed class SessionFiles : IAudioSessionStore
{
    private const string WaveName = "input.wav";
    private readonly string root;

    public SessionFiles(string localApplicationDataRoot)
    {
        root = OwnedPaths.RequireAbsoluteRoot(localApplicationDataRoot, "sessions");
        OwnedPaths.EnsureDirectory(root);
    }

    public static string DefaultRoot => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Resenha");

    public IAudioSession Create(AttemptId attempt)
    {
        attempt.ThrowIfEmpty();
        var directory = Path.Combine(root, attempt.Value.ToString("D"));
        OwnedPaths.RequireDirectChild(root, directory, attempt.Value.ToString("D"));
        if (Directory.Exists(directory))
        {
            throw new IOException("The attempt directory already exists.");
        }

        Directory.CreateDirectory(directory);
        OwnedPaths.RequireSafeDirectory(directory);
        return new Session(root, directory, attempt);
    }

    public void CleanupOrphans()
    {
        OwnedPaths.RequireSafeDirectory(root);
        foreach (var directory in Directory.EnumerateDirectories(root))
        {
            var name = Path.GetFileName(directory);
            if (!Guid.TryParseExact(name, "D", out _))
            {
                continue;
            }

            OwnedPaths.RequireDirectChild(root, directory, name);
            OwnedPaths.DeleteOwnedTree(directory);
        }
    }

    private sealed class Session(string root, string directory, AttemptId attempt) : IAudioSession
    {
        private bool transferred;
        private bool disposed;

        public string OwnedWavePath { get; } = Path.Combine(directory, WaveName);

        public AudioLease Commit(AudioDescriptor descriptor, ReadOnlyMemory<byte> wave)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (transferred || descriptor.Attempt != attempt
                || !string.Equals(Path.GetFullPath(descriptor.OwnedPath), OwnedWavePath, OwnedPaths.PathComparison)
                || wave.IsEmpty)
            {
                throw new InvalidOperationException("The audio cannot be committed to this attempt.");
            }

            OwnedPaths.RequireDirectChild(root, directory, attempt.Value.ToString("D"));
            OwnedPaths.RequireSafeDirectory(directory);
            var temporary = Path.Combine(directory, "input.partial");
            using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                64 * 1024, FileOptions.WriteThrough))
            {
                stream.Write(wave.Span);
                stream.Flush(flushToDisk: true);
            }

            File.Move(temporary, OwnedWavePath);
            transferred = true;
            return new SessionAudioLease(descriptor, root, directory);
        }

        public void Dispose()
        {
            if (disposed) { return; }
            disposed = true;
            if (!transferred)
            {
                OwnedPaths.RequireDirectChild(root, directory, attempt.Value.ToString("D"));
                OwnedPaths.DeleteOwnedTree(directory);
            }
        }
    }

    private sealed class SessionAudioLease(AudioDescriptor descriptor, string root, string directory) : AudioLease(descriptor)
    {
        protected override ValueTask DisposeCoreAsync()
        {
            OwnedPaths.RequireDirectChild(root, directory, Attempt.Value.ToString("D"));
            OwnedPaths.DeleteOwnedTree(directory);
            return ValueTask.CompletedTask;
        }
    }
}

internal static class OwnedPaths
{
    internal static StringComparison PathComparison => OperatingSystem.IsWindows()
        ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

    internal static string RequireAbsoluteRoot(string baseRoot, string child)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(baseRoot);
        if (!Path.IsPathFullyQualified(baseRoot)) { throw new ArgumentException("An absolute owned root is required.", nameof(baseRoot)); }
        var canonicalBase = Path.GetFullPath(baseRoot);
        Directory.CreateDirectory(canonicalBase);
        RequireSafeDirectory(canonicalBase);
        if (OperatingSystem.IsWindows()) { RequireSafeAncestors(canonicalBase); }
        var root = Path.GetFullPath(Path.Combine(canonicalBase, child));
        RequireDirectChild(canonicalBase, root, child);
        return root;
    }

    internal static void EnsureDirectory(string path)
    {
        Directory.CreateDirectory(path);
        RequireSafeDirectory(path);
    }

    internal static void RequireDirectChild(string parent, string candidate, string expectedName)
    {
        var canonicalParent = Path.TrimEndingDirectorySeparator(Path.GetFullPath(parent));
        var canonicalCandidate = Path.TrimEndingDirectorySeparator(Path.GetFullPath(candidate));
        if (!string.Equals(Path.GetDirectoryName(canonicalCandidate), canonicalParent, PathComparison)
            || !string.Equals(Path.GetFileName(canonicalCandidate), expectedName, PathComparison))
        {
            throw new UnauthorizedAccessException("The path is outside the owned directory.");
        }
    }

    internal static void RequireSafeDirectory(string directory)
    {
        var info = new DirectoryInfo(directory);
        if (!info.Exists || info.Attributes.HasFlag(FileAttributes.ReparsePoint) || info.LinkTarget is not null)
        {
            throw new UnauthorizedAccessException("Owned storage cannot use a reparse point.");
        }
    }

    private static void RequireSafeAncestors(string directory)
    {
        for (var current = new DirectoryInfo(directory); current is not null; current = current.Parent)
        {
            if (current.Attributes.HasFlag(FileAttributes.ReparsePoint) || current.LinkTarget is not null)
            {
                throw new UnauthorizedAccessException("Owned storage cannot traverse a reparse point.");
            }
        }
    }

    internal static void DeleteOwnedTree(string directory)
    {
        if (!Directory.Exists(directory)) { return; }
        RequireSafeDirectory(directory);
        foreach (var path in Directory.EnumerateFileSystemEntries(directory))
        {
            var attributes = File.GetAttributes(path);
            if (attributes.HasFlag(FileAttributes.ReparsePoint)
                || (Directory.Exists(path) && new DirectoryInfo(path).LinkTarget is not null))
            {
                throw new UnauthorizedAccessException("Cleanup refused a reparse point.");
            }

            if (Directory.Exists(path)) { DeleteOwnedTree(path); }
            else { File.Delete(path); }
        }
        Directory.Delete(directory, false);
    }
}
