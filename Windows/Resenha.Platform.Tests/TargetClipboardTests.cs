using System.Collections.Immutable;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class TargetClipboardTests
{
    [TestMethod]
    public async Task ClipboardRetriesBoundedlyAndRequiresExactReadback()
    {
        var native = new FakeClipboardNative { Failures = 2 };
        var attempt = AttemptId.New();
        var result = await new ClipboardService(native).CommitAsync(attempt, "Éric — whisper.cpp", default);
        Assert.IsTrue(result.IsSuccess);
        Assert.AreEqual(3, native.Writes);
        Assert.AreEqual(attempt, result.Value!.Attempt);
        Assert.AreEqual(native.SequenceNumber, result.Value.SequenceNumber);

        native.ReadbackOverride = "changed";
        var failed = await new ClipboardService(native).CommitAsync(attempt, "original", default);
        Assert.AreEqual(ErrorCode.ClipboardBusy, failed.Failure?.Code);
        Assert.AreEqual(ClipboardService.MaximumAttempts + 3, native.Writes);
    }

    [TestMethod]
    public async Task CurrentClipboardRequiresSequenceAndDigest()
    {
        var native = new FakeClipboardNative();
        var service = new ClipboardService(native);
        var attempt = AttemptId.New();
        var token = (await service.CommitAsync(attempt, "texto", default)).Value!;
        Assert.AreEqual(true, (await service.IsCurrentAsync(attempt, token, default)).Value);
        native.SequenceNumber++;
        Assert.AreEqual(false, (await service.IsCurrentAsync(attempt, token, default)).Value);
        native.SequenceNumber--;
        native.ChangeSequenceOnRead = true;
        Assert.AreEqual(false, (await service.IsCurrentAsync(attempt, token, default)).Value);
    }

    [TestMethod]
    public async Task InsertionChecksTargetThenClipboardAndDispatchesOneBatch()
    {
        var attempt = AttemptId.New();
        var order = new List<string>();
        var target = new FakeTargetProbe
        {
            OnCheck = (id, _, _) => { order.Add("target"); return ValueTask.FromResult(Outcome<TargetCheck>.Success(id, TargetCheck.SameTarget)); }
        };
        var clipboard = new FakeClipboard
        {
            OnIsCurrent = (id, _, _) => { order.Add("clipboard"); return ValueTask.FromResult(Outcome<bool>.Success(id, true)); }
        };
        var input = new FakeInput(order) { Accepted = 4 };
        var result = await new TextInjector(target, clipboard, new ManualClock(), input)
            .TryInsertAsync(attempt, Target(attempt), Token(attempt), default);
        Assert.AreEqual(InjectionDisposition.Dispatched, result.Value!.Disposition);
        CollectionAssert.AreEqual(new[] { "target", "clipboard", "send" }, order);
        Assert.AreEqual(1, input.Batches);
    }

    [TestMethod]
    public async Task ChangedTargetOrClipboardNeverDispatches()
    {
        var attempt = AttemptId.New();
        foreach (var changedTarget in new[] { TargetCheck.Changed, TargetCheck.Unsafe, TargetCheck.Unknown })
        {
            var input = new FakeInput([]);
            var target = new FakeTargetProbe
            {
                OnCheck = (id, _, _) => ValueTask.FromResult(Outcome<TargetCheck>.Success(id, changedTarget))
            };
            var result = await new TextInjector(target, CurrentClipboard(), new ManualClock(), input)
                .TryInsertAsync(attempt, Target(attempt), Token(attempt), default);
            Assert.AreEqual(InjectionDisposition.ManualPaste, result.Value!.Disposition);
            Assert.AreEqual(0, input.Batches);
        }

        var replaced = new FakeClipboard
        {
            OnIsCurrent = (id, _, _) => ValueTask.FromResult(Outcome<bool>.Success(id, false))
        };
        var replacementInput = new FakeInput([]);
        var replacedResult = await new TextInjector(SameTarget(), replaced, new ManualClock(), replacementInput)
            .TryInsertAsync(attempt, Target(attempt), Token(attempt), default);
        Assert.AreEqual(InjectionDisposition.CopyRequired, replacedResult.Value!.Disposition);
        Assert.AreEqual(0, replacementInput.Batches);
    }

    [TestMethod]
    public async Task PartialDispatchReleasesSyntheticKeysWithoutRetry()
    {
        var attempt = AttemptId.New();
        for (uint accepted = 0; accepted < 4; accepted++)
        {
            var input = new FakeInput([]) { Accepted = accepted };
            var result = await new TextInjector(SameTarget(), CurrentClipboard(), new ManualClock(), input)
                .TryInsertAsync(attempt, Target(attempt), Token(attempt), default);
            Assert.AreEqual(InjectionDisposition.ManualPaste, result.Value!.Disposition);
            Assert.AreEqual(1, input.Batches);
            Assert.AreEqual(accepted == 0 ? 0 : 1, input.Cleanups);
        }

        var failedCleanup = new FakeInput([]) { Accepted = 2, CleanupSucceeds = false };
        var failed = await new TextInjector(SameTarget(), CurrentClipboard(), new ManualClock(), failedCleanup)
            .TryInsertAsync(attempt, Target(attempt), Token(attempt), default);
        Assert.AreEqual(ErrorCode.CleanupFailed, failed.Failure?.Code);
    }

    [TestMethod]
    public async Task HeldModifierWaitIsCancellableAndNeverReleasesUserKeys()
    {
        var attempt = AttemptId.New();
        var input = new FakeInput([]) { ModifierDown = true };
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var result = await new TextInjector(SameTarget(), CurrentClipboard(), new ManualClock(), input)
            .TryInsertAsync(attempt, Target(attempt), Token(attempt), cancellation.Token);
        Assert.AreEqual(OutcomeKind.Cancelled, result.Kind);
        Assert.AreEqual(0, input.Cleanups);
        Assert.AreEqual(0, input.Batches);
    }

    private static FakeTargetProbe SameTarget() => new()
    {
        OnCheck = (id, _, _) => ValueTask.FromResult(Outcome<TargetCheck>.Success(id, TargetCheck.SameTarget))
    };
    private static FakeClipboard CurrentClipboard() => new()
    {
        OnIsCurrent = (id, _, _) => ValueTask.FromResult(Outcome<bool>.Success(id, true))
    };
    private static ClipboardToken Token(AttemptId attempt) => new(attempt, 1, new string('a', 64));
    private static TargetSnapshot Target(AttemptId attempt) => new(attempt, 1, 1, 1, 1, 1, 1, "desktop",
        TargetIntegrity.Medium, ImmutableArray.Create(1), 50004, false, true, false, 0,
        new("selection", true, false), new(0));

    private sealed class FakeClipboardNative : IClipboardNative
    {
        private string? text;
        internal int Failures { get; set; }
        internal int Writes { get; private set; }
        internal string? ReadbackOverride { get; set; }
        internal bool ChangeSequenceOnRead { get; set; }
        public uint SequenceNumber { get; set; } = 10;
        public bool TryCommit(string value, out uint sequence, out string? readback)
        {
            Writes++;
            if (Writes <= Failures) { sequence = 0; readback = null; return false; }
            text = value;
            SequenceNumber++;
            sequence = SequenceNumber;
            readback = ReadbackOverride ?? text;
            return true;
        }
        public string? ReadText()
        {
            if (ChangeSequenceOnRead) { SequenceNumber++; }
            return ReadbackOverride ?? text;
        }
    }

    private sealed class FakeInput(List<string> order) : IInputDispatcher
    {
        internal bool ModifierDown { get; set; }
        internal uint Accepted { get; set; }
        internal int Batches { get; private set; }
        internal int Cleanups { get; private set; }
        internal bool CleanupSucceeds { get; set; } = true;
        public bool AnyModifierDown => ModifierDown;
        public uint SendPasteBatch() { order.Add("send"); Batches++; return Accepted; }
        public bool ReleaseSyntheticKeys(uint acceptedEvents) { Cleanups++; return CleanupSucceeds; }
    }
}
