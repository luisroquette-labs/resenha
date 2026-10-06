using System.Buffers;
using System.Net;
using System.Security.Cryptography;
using Resenha.Core;

namespace Resenha.Platform;

public interface IModelTransferClient
{
    ValueTask DownloadAsync(Uri source, Stream destination, long maximumBytes,
        TimeSpan noProgressTimeout, CancellationToken cancellationToken);
}

public sealed class ModelStore : IModelStore
{
    public const string ModelFileName = "ggml-small-q5_1.bin";
    public const long ModelByteLength = 190085487;
    public const string ModelSha256 = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb";
    public static readonly Uri ModelSource = new(
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin");
    public static readonly TimeSpan NoProgressTimeout = TimeSpan.FromSeconds(30);
    public static readonly TimeSpan TotalDownloadTimeout = TimeSpan.FromMinutes(15);

    private readonly ModelDescriptor descriptor;
    private readonly Uri source;
    private readonly string root;
    private readonly string modelPath;
    private readonly IModelTransferClient transfer;
    private readonly SemaphoreSlim mutation = new(1, 1);

    public ModelStore(string localApplicationDataRoot, IModelTransferClient? transfer = null)
        : this(localApplicationDataRoot,
            new ModelDescriptor(ModelFileName, ModelByteLength, ModelSha256), ModelSource, transfer)
    {
    }

    internal ModelStore(string localApplicationDataRoot, ModelDescriptor descriptor,
        Uri source, IModelTransferClient? transfer = null)
    {
        ArgumentNullException.ThrowIfNull(descriptor);
        ArgumentNullException.ThrowIfNull(source);
        if (descriptor.ByteLength <= 0 || descriptor.Sha256.Length != 64
            || !descriptor.Sha256.All(Uri.IsHexDigit) || source.Scheme != Uri.UriSchemeHttps)
        {
            throw new ArgumentException("The model descriptor is invalid.", nameof(descriptor));
        }
        root = OwnedPaths.RequireAbsoluteRoot(localApplicationDataRoot, "models");
        OwnedPaths.EnsureDirectory(root);
        OwnedPaths.RequireDirectChild(root, Path.Combine(root, descriptor.FileName), descriptor.FileName);
        modelPath = Path.Combine(root, descriptor.FileName);
        this.descriptor = descriptor with { Sha256 = descriptor.Sha256.ToLowerInvariant() };
        this.source = source;
        this.transfer = transfer ?? new HttpModelTransferClient();
    }

    public async ValueTask<Outcome<VerifiedModelLease>> AcquireVerifiedAsync(
        AttemptId attempt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (cancellationToken.IsCancellationRequested) { return Outcome<VerifiedModelLease>.Cancelled(attempt); }
        try
        {
            OwnedPaths.RequireSafeDirectory(root);
            if (!File.Exists(modelPath)) { return Outcome<VerifiedModelLease>.Failed(attempt, ErrorCode.ModelMissing); }
            var stream = OpenVerifiedRead(modelPath);
            try
            {
                if (!await MatchesDescriptorAsync(stream, cancellationToken).ConfigureAwait(false))
                {
                    stream.Dispose();
                    return Outcome<VerifiedModelLease>.Failed(attempt, ErrorCode.ModelCorrupt);
                }
                stream.Position = 0;
                return Outcome<VerifiedModelLease>.Success(attempt, new ModelFileLease(attempt, descriptor, modelPath, stream));
            }
            catch { stream.Dispose(); throw; }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return Outcome<VerifiedModelLease>.Cancelled(attempt);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or CryptographicException)
        {
            return Outcome<VerifiedModelLease>.Failed(attempt, ErrorCode.ModelCorrupt);
        }
    }

    public async ValueTask<Outcome<Unit>> ImportAsync(AttemptId operation, string sourcePath,
        CancellationToken cancellationToken)
    {
        operation.ThrowIfEmpty();
        if (string.IsNullOrWhiteSpace(sourcePath) || !Path.IsPathFullyQualified(sourcePath))
        {
            return Outcome<Unit>.Failed(operation, ErrorCode.CorruptInput);
        }
        return await InstallAsync(operation, async (destination, token) =>
        {
            await using var source = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read,
                128 * 1024, FileOptions.Asynchronous | FileOptions.SequentialScan);
            if (source.Length != descriptor.ByteLength) { throw new InvalidDataException(); }
            await source.CopyToAsync(destination, 128 * 1024, token).ConfigureAwait(false);
        }, cancellationToken).ConfigureAwait(false);
    }

    public ValueTask<Outcome<Unit>> DownloadAsync(AttemptId operation, CancellationToken cancellationToken) =>
        InstallAsync(operation, (destination, token) => transfer.DownloadAsync(
            source, destination, descriptor.ByteLength, NoProgressTimeout, token), cancellationToken);

    private async ValueTask<Outcome<Unit>> InstallAsync(AttemptId operation,
        Func<Stream, CancellationToken, ValueTask> populate, CancellationToken cancellationToken)
    {
        operation.ThrowIfEmpty();
        if (cancellationToken.IsCancellationRequested) { return Outcome<Unit>.Cancelled(operation); }
        try { await mutation.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        var partial = Path.Combine(root, $"{descriptor.FileName}.{Guid.NewGuid():N}.partial");
        Outcome<Unit>? result = null;
        try
        {
            OwnedPaths.RequireSafeDirectory(root);
            using var total = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            total.CancelAfter(TotalDownloadTimeout);
            await using (var destination = new FileStream(partial, FileMode.CreateNew, FileAccess.ReadWrite,
                FileShare.None, 128 * 1024, FileOptions.Asynchronous | FileOptions.SequentialScan | FileOptions.WriteThrough))
            {
                await populate(destination, total.Token).ConfigureAwait(false);
                await destination.FlushAsync(total.Token).ConfigureAwait(false);
                destination.Flush(flushToDisk: true);
                if (!await MatchesDescriptorAsync(destination, total.Token).ConfigureAwait(false))
                {
                    result = Outcome<Unit>.Failed(operation, ErrorCode.ModelCorrupt);
                }
            }

            if (result is null)
            {
                Promote(partial);
                result = Outcome<Unit>.Success(operation, default);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            result = Outcome<Unit>.Cancelled(operation);
        }
        catch (OperationCanceledException)
        {
            result = Outcome<Unit>.TimedOut(operation);
        }
        catch (OwnedCleanupException)
        {
            result = Outcome<Unit>.Failed(operation, ErrorCode.CleanupFailed);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException
            or HttpRequestException or CryptographicException or InvalidDataException)
        {
            result = Outcome<Unit>.Failed(operation, ErrorCode.ModelDownloadFailed);
        }
        finally
        {
            try { if (File.Exists(partial)) { File.Delete(partial); } }
            catch { result = Outcome<Unit>.Failed(operation, ErrorCode.CleanupFailed); }
            mutation.Release();
        }
        return result ?? Outcome<Unit>.Failed(operation, ErrorCode.ModelDownloadFailed);
    }

    private void Promote(string partial)
    {
        if (!File.Exists(modelPath))
        {
            File.Move(partial, modelPath);
            return;
        }

        var backup = Path.Combine(root, $"{descriptor.FileName}.{Guid.NewGuid():N}.backup");
        File.Replace(partial, modelPath, backup, ignoreMetadataErrors: true);
        try { File.Delete(backup); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            throw new OwnedCleanupException(error);
        }
    }

    private static FileStream OpenVerifiedRead(string path)
    {
        var info = new FileInfo(path);
        if (info.Attributes.HasFlag(FileAttributes.ReparsePoint) || info.LinkTarget is not null)
        {
            throw new UnauthorizedAccessException("The model cannot be a reparse point.");
        }
        return new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read,
            128 * 1024, FileOptions.Asynchronous | FileOptions.SequentialScan);
    }

    private async ValueTask<bool> MatchesDescriptorAsync(Stream stream, CancellationToken cancellationToken)
    {
        if (!stream.CanSeek || stream.Length != descriptor.ByteLength) { return false; }
        stream.Position = 0;
        var digest = await SHA256.HashDataAsync(stream, cancellationToken).ConfigureAwait(false);
        return Convert.ToHexStringLower(digest) == descriptor.Sha256;
    }

    private sealed class ModelFileLease(AttemptId attempt, ModelDescriptor descriptor,
        string path, FileStream stream) : VerifiedModelLease(attempt, descriptor, path)
    {
        protected override ValueTask DisposeCoreAsync()
        {
            stream.Dispose();
            return ValueTask.CompletedTask;
        }
    }

    private sealed class OwnedCleanupException(Exception inner) : Exception("Owned model cleanup failed.", inner);
}

public sealed class HttpModelTransferClient : IModelTransferClient
{
    private readonly HttpClient client;
    public HttpModelTransferClient(HttpClient? client = null)
    {
        this.client = client ?? new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
    }

    public async ValueTask DownloadAsync(Uri source, Stream destination, long maximumBytes,
        TimeSpan noProgressTimeout, CancellationToken cancellationToken)
    {
        if (source.Scheme != Uri.UriSchemeHttps) { throw new InvalidDataException("HTTPS is required."); }
        using var response = await client.GetAsync(source, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
        if (response.RequestMessage?.RequestUri?.Scheme != Uri.UriSchemeHttps) { throw new InvalidDataException("HTTPS redirect required."); }
        if (response.StatusCode != HttpStatusCode.OK) { throw new HttpRequestException("Model download failed."); }
        if (response.Content.Headers.ContentLength is long length && length != maximumBytes) { throw new InvalidDataException(); }
        await using var input = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        var buffer = ArrayPool<byte>.Shared.Rent(128 * 1024);
        long total = 0;
        try
        {
            while (true)
            {
                var readTask = input.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken).AsTask();
                var completed = await Task.WhenAny(readTask, Task.Delay(noProgressTimeout, cancellationToken)).ConfigureAwait(false);
                if (completed != readTask) { throw new OperationCanceledException("Model download made no progress."); }
                var read = await readTask.ConfigureAwait(false);
                if (read == 0) { break; }
                total = checked(total + read);
                if (total > maximumBytes) { throw new InvalidDataException(); }
                await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
            }
            if (total != maximumBytes) { throw new InvalidDataException(); }
        }
        finally { ArrayPool<byte>.Shared.Return(buffer, clearArray: true); }
    }
}
