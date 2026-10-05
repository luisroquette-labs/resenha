using System.Text.Json;
using Resenha.Core;

namespace Resenha.Platform;

public sealed class PreferencesStore
{
    internal const int MaximumBytes = 64 * 1024;
    private readonly string root;
    private readonly string path;
    private readonly SemaphoreSlim mutation = new(1, 1);

    public PreferencesStore(string localApplicationDataRoot)
    {
        root = OwnedPaths.RequireAbsoluteRoot(localApplicationDataRoot, "Resenha");
        OwnedPaths.EnsureDirectory(root);
        path = Path.Combine(root, "settings.json");
        OwnedPaths.RequireDirectChild(root, path, "settings.json");
    }

    public async ValueTask<Outcome<ProductPreferences>> LoadAsync(AttemptId operation,
        CancellationToken cancellationToken)
    {
        operation.ThrowIfEmpty();
        if (!File.Exists(path)) { return Outcome<ProductPreferences>.Failed(operation, ErrorCode.NotReady); }
        try
        {
            OwnedPaths.RequireSafeDirectory(root);
            var info = new FileInfo(path);
            if (info.Attributes.HasFlag(FileAttributes.ReparsePoint) || info.LinkTarget is not null
                || info.Length is <= 0 or > MaximumBytes)
            {
                return Outcome<ProductPreferences>.Failed(operation, ErrorCode.CorruptInput);
            }
            await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read,
                4096, FileOptions.Asynchronous | FileOptions.SequentialScan);
            var value = await JsonSerializer.DeserializeAsync<ProductPreferences>(stream,
                PreferencesJson.Options, cancellationToken).ConfigureAwait(false);
            return IsValid(value)
                ? Outcome<ProductPreferences>.Success(operation, value!)
                : Outcome<ProductPreferences>.Failed(operation, ErrorCode.CorruptInput);
        }
        catch (OperationCanceledException) { return Outcome<ProductPreferences>.Cancelled(operation); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        { return Outcome<ProductPreferences>.Failed(operation, ErrorCode.CorruptInput); }
    }

    public async ValueTask<Outcome<Unit>> SaveAsync(AttemptId operation, ProductPreferences preferences,
        CancellationToken cancellationToken)
    {
        operation.ThrowIfEmpty();
        if (!IsValid(preferences)) { return Outcome<Unit>.Failed(operation, ErrorCode.CorruptInput); }
        try { await mutation.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        var temporary = Path.Combine(root, $"settings.{Guid.NewGuid():N}.partial");
        try
        {
            OwnedPaths.RequireSafeDirectory(root);
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write,
                FileShare.None, 4096, FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                await JsonSerializer.SerializeAsync(stream, preferences, PreferencesJson.Options,
                    cancellationToken).ConfigureAwait(false);
                await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
                stream.Flush(flushToDisk: true);
                if (stream.Length > MaximumBytes) { throw new InvalidDataException(); }
            }
            if (File.Exists(path)) { File.Replace(temporary, path, null, ignoreMetadataErrors: true); }
            else { File.Move(temporary, path); }
            return Outcome<Unit>.Success(operation, default);
        }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException
            or JsonException or InvalidDataException)
        { return Outcome<Unit>.Failed(operation, ErrorCode.StorageUnsafe); }
        finally
        {
            try { if (File.Exists(temporary)) { File.Delete(temporary); } }
            finally { mutation.Release(); }
        }
    }

    public static bool IsValid(ProductPreferences? value) => value is not null
        && value.SchemaVersion == 1
        && (value.MicrophoneEndpointId.Length == 0 || !string.IsNullOrWhiteSpace(value.MicrophoneEndpointId))
        && value.MicrophoneEndpointId.Length <= 2048
        && Enum.IsDefined(value.Language)
        && ShortcutPolicy.Validate(value.Shortcut) == ErrorCode.None;

    private static class PreferencesJson
    {
        internal static JsonSerializerOptions Options { get; } = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            UnmappedMemberHandling = System.Text.Json.Serialization.JsonUnmappedMemberHandling.Disallow
        };
    }
}
