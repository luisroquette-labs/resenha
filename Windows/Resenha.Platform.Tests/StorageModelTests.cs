using System.Security.Cryptography;
using System.Net;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class StorageModelTests
{
    [TestMethod]
    public async Task SessionCommitIsAttemptScopedAndLeaseDeletesOnlyOwnedDirectory()
    {
        using var fixture = new StorageFixture();
        var attempt = AttemptId.New();
        var unrelated = Path.Combine(fixture.Root, "keep.txt");
        File.WriteAllText(unrelated, "keep");
        using var session = fixture.Sessions.Create(attempt);
        var descriptor = new AudioDescriptor(attempt, session.OwnedWavePath, 1, TimeSpan.FromTicks(625),
            new(-20, 1, TimeSpan.FromTicks(625)), new(0), new(625));
        await using var lease = session.Commit(descriptor, new byte[] { 1, 2, 3 });
        Assert.IsTrue(File.Exists(session.OwnedWavePath));
        await lease.DisposeAsync();
        Assert.IsFalse(Directory.Exists(Path.GetDirectoryName(session.OwnedWavePath)));
        Assert.AreEqual("keep", File.ReadAllText(unrelated));
    }

    [TestMethod]
    public void UncommittedSessionAndCrashRemnantsAreCleanedIdempotently()
    {
        using var fixture = new StorageFixture();
        var first = AttemptId.New();
        var session = fixture.Sessions.Create(first);
        var directory = Path.GetDirectoryName(session.OwnedWavePath)!;
        File.WriteAllText(Path.Combine(directory, "input.partial"), "partial");
        session.Dispose();
        session.Dispose();
        Assert.IsFalse(Directory.Exists(directory));

        var orphan = Path.Combine(fixture.Root, "sessions", Guid.NewGuid().ToString("D"));
        Directory.CreateDirectory(orphan);
        File.WriteAllText(Path.Combine(orphan, "input.wav"), "orphan");
        var unrelated = Path.Combine(fixture.Root, "sessions", "not-an-attempt");
        Directory.CreateDirectory(unrelated);
        fixture.Sessions.CleanupOrphans();
        Assert.IsFalse(Directory.Exists(orphan));
        Assert.IsTrue(Directory.Exists(unrelated));
    }

    [TestMethod]
    public void TraversalAndDuplicateAttemptsAreRejected()
    {
        using var fixture = new StorageFixture();
        Assert.Throws<ArgumentException>(() => new SessionFiles("relative"));
        var attempt = AttemptId.New();
        using var session = fixture.Sessions.Create(attempt);
        Assert.Throws<IOException>(() => fixture.Sessions.Create(attempt));
    }

    [TestMethod]
    public async Task MissingAndCorruptModelsFailClosed()
    {
        using var fixture = new StorageFixture();
        var attempt = AttemptId.New();
        Assert.AreEqual(ErrorCode.ModelMissing, (await fixture.Models.AcquireVerifiedAsync(attempt, default)).Failure?.Code);
        var path = Path.Combine(fixture.Root, "models", ModelStore.ModelFileName);
        File.WriteAllText(path, "corrupt");
        Assert.AreEqual(ErrorCode.ModelCorrupt, (await fixture.Models.AcquireVerifiedAsync(attempt, default)).Failure?.Code);
    }

    [TestMethod]
    public async Task FailedImportKeepsExistingBytesAndDeletesPartial()
    {
        using var fixture = new StorageFixture();
        var model = Path.Combine(fixture.Root, "models", ModelStore.ModelFileName);
        File.WriteAllText(model, "existing");
        var source = Path.Combine(fixture.Root, "bad-model.bin");
        File.WriteAllText(source, "bad");
        var result = await fixture.Models.ImportAsync(AttemptId.New(), source, default);
        Assert.AreEqual(ErrorCode.ModelDownloadFailed, result.Failure?.Code);
        Assert.AreEqual("existing", File.ReadAllText(model));
        Assert.AreEqual(0, Directory.GetFiles(Path.GetDirectoryName(model)!, "*.partial").Length);
    }

    [TestMethod]
    public async Task ValidImportIsReverifiedOnEveryLeaseAndPreservesSource()
    {
        using var fixture = new StorageFixture(validTestDescriptor: true);
        var source = Path.Combine(fixture.Root, "import.bin");
        await File.WriteAllBytesAsync(source, StorageFixture.ValidBytes);
        Assert.IsTrue((await fixture.Models.ImportAsync(AttemptId.New(), source, default)).IsSuccess);
        CollectionAssert.AreEqual(StorageFixture.ValidBytes, await File.ReadAllBytesAsync(source));

        var firstAttempt = AttemptId.New();
        await using var lease = (await fixture.Models.AcquireVerifiedAsync(firstAttempt, default)).Value!;
        Assert.AreEqual(firstAttempt, lease.Attempt);
        Assert.AreEqual(StorageFixture.ValidHash, lease.Model.Sha256);
        await lease.DisposeAsync();

        var installed = Path.Combine(fixture.Root, "models", "test-model.bin");
        await File.WriteAllBytesAsync(installed, new byte[StorageFixture.ValidBytes.Length]);
        Assert.AreEqual(ErrorCode.ModelCorrupt,
            (await fixture.Models.AcquireVerifiedAsync(AttemptId.New(), default)).Failure?.Code);
    }

    [TestMethod]
    public async Task FailedReplacementRetainsPreviouslyVerifiedModel()
    {
        using var fixture = new StorageFixture(validTestDescriptor: true);
        var source = Path.Combine(fixture.Root, "valid.bin");
        await File.WriteAllBytesAsync(source, StorageFixture.ValidBytes);
        Assert.IsTrue((await fixture.Models.ImportAsync(AttemptId.New(), source, default)).IsSuccess);
        var installed = Path.Combine(fixture.Root, "models", "test-model.bin");
        var before = await File.ReadAllBytesAsync(installed);
        var bad = Path.Combine(fixture.Root, "bad.bin");
        await File.WriteAllBytesAsync(bad, new byte[] { 1, 2 });
        Assert.IsFalse((await fixture.Models.ImportAsync(AttemptId.New(), bad, default)).IsSuccess);
        CollectionAssert.AreEqual(before, await File.ReadAllBytesAsync(installed));
    }

    [TestMethod]
    public async Task DownloadRequiresExactLengthAndCleansFailedStage()
    {
        using var fixture = new StorageFixture(new ShortTransfer());
        var result = await fixture.Models.DownloadAsync(AttemptId.New(), default);
        Assert.AreEqual(ErrorCode.ModelCorrupt, result.Failure?.Code);
        Assert.AreEqual(0, Directory.GetFiles(Path.Combine(fixture.Root, "models"), "*.partial").Length);
    }

    [TestMethod]
    public void ManifestPinsTrustedDescriptorAndExplicitDownload()
    {
        var repository = ModelProcessTests.FindRepository();
        var text = File.ReadAllText(Path.Combine(repository, "Windows/model-manifest.json"));
        StringAssert.Contains(text, ModelStore.ModelFileName);
        StringAssert.Contains(text, ModelStore.ModelByteLength.ToString());
        StringAssert.Contains(text, ModelStore.ModelSha256);
        StringAssert.Contains(text, "https://huggingface.co/ggerganov/whisper.cpp/");
        StringAssert.Contains(text, "explicit-user-action-only");
    }

    [TestMethod]
    public async Task DownloaderRejectsAnHttpsToHttpRedirectResult()
    {
        using var http = new HttpClient(new ResponseHandler(new HttpResponseMessage(HttpStatusCode.OK)
        {
            RequestMessage = new HttpRequestMessage(HttpMethod.Get, "http://example.invalid/model.bin"),
            Content = new ByteArrayContent(new byte[] { 1 })
        }));
        var transfer = new HttpModelTransferClient(http);
        await using var destination = new MemoryStream();
        await Assert.ThrowsAsync<InvalidDataException>(() => transfer.DownloadAsync(
            new Uri("https://example.invalid/model.bin"), destination, 1, TimeSpan.FromSeconds(1), default).AsTask());
    }

    private sealed class ShortTransfer : IModelTransferClient
    {
        public async ValueTask DownloadAsync(Uri source, Stream destination, long maximumBytes,
            TimeSpan noProgressTimeout, CancellationToken cancellationToken)
        {
            await destination.WriteAsync(new byte[32], cancellationToken);
        }
    }

    private sealed class ResponseHandler(HttpResponseMessage response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken) => Task.FromResult(response);
    }

    private sealed class StorageFixture : IDisposable
    {
        internal static readonly byte[] ValidBytes = "resenha-test-model"u8.ToArray();
        internal static readonly string ValidHash = Convert.ToHexStringLower(SHA256.HashData(ValidBytes));
        internal string Root { get; } = Path.Combine(Path.GetTempPath(), "resenha-storage-" + Guid.NewGuid().ToString("N"));
        internal SessionFiles Sessions { get; }
        internal ModelStore Models { get; }
        internal StorageFixture(IModelTransferClient? transfer = null, bool validTestDescriptor = false)
        {
            Directory.CreateDirectory(Root);
            Sessions = new SessionFiles(Root);
            Models = validTestDescriptor
                ? new ModelStore(Root, new("test-model.bin", ValidBytes.Length, ValidHash),
                    new Uri("https://example.invalid/test-model.bin"), transfer)
                : new ModelStore(Root, transfer);
        }
        public void Dispose() { if (Directory.Exists(Root)) { Directory.Delete(Root, true); } }
    }
}
