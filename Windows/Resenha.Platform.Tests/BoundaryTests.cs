using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

[assembly: Parallelize(Scope = ExecutionScope.MethodLevel)]

namespace Resenha.Platform.Tests;

[TestClass]
public sealed class BoundaryTests
{
    // This is a test-double boundary check, never Windows API/hardware evidence.
    [TestMethod]
    public async Task UnconfiguredDoublesCannotReportReadyOrDispatch()
    {
        var attempt = AttemptId.New();
        Assert.AreEqual(ErrorCode.NotReady, (await new FakeAudioRecorder().StartAsync(attempt, "device", new(0), CancellationToken.None)).Failure?.Code);
        Assert.AreEqual(ErrorCode.ModelMissing, (await new FakeModelStore().AcquireVerifiedAsync(attempt, CancellationToken.None)).Failure?.Code);
        Assert.AreEqual(ErrorCode.TargetUnknown, (await new FakeTargetProbe().CaptureAsync(attempt, new(0), CancellationToken.None)).Failure?.Code);
        Assert.AreEqual(ErrorCode.ClipboardBusy, (await new FakeClipboard().CommitAsync(attempt, "test text", CancellationToken.None)).Failure?.Code);
    }
}
