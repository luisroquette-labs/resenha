using System.Collections.Immutable;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class CoordinatorTests
{
    private static readonly ProductPreferences Preferences = new(1,
        new(0x39, false, ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt),
        "microphone", DictationLanguage.Pt);

    [TestMethod]
    public async Task HappyPathCopiesBeforeExactlyOneInsertionAndCleansLeases()
    {
        var events = new List<string>();
        var fixture = new Fixture(events);
        await using var coordinator = fixture.Create();

        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(10)), Preferences);
        await fixture.Started.Task.WaitAsync(TimeSpan.FromSeconds(1));
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Released, new(20)), Preferences);
        await coordinator.WaitForQuiescenceAsync();

        CollectionAssert.AreEqual(new[] { "start", "stop", "model", "transcribe", "copy", "insert" }, events);
        Assert.AreEqual(DictationState.Idle, coordinator.Status.State);
        Assert.AreEqual("Éric rodou o whisper.cpp.", coordinator.LastResult);
        Assert.AreEqual(1, fixture.AudioLease.DisposalCount);
        Assert.AreEqual(1, fixture.ModelLease.DisposalCount);
        Assert.AreEqual(1, fixture.Insertions);
    }

    [TestMethod]
    public async Task SilenceTouchesNeitherClipboardNorTarget()
    {
        var fixture = new Fixture { Transcript = TranscriptOutcome.Silence };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(0, fixture.Copies);
        Assert.AreEqual(0, fixture.Insertions);
        Assert.IsNull(coordinator.LastResult);
        Assert.AreEqual(DictationState.Idle, coordinator.Status.State);
    }

    [TestMethod]
    public async Task ReleaseDuringPendingStartCancelsLateCaptureWithoutInference()
    {
        var start = new TaskCompletionSource<Outcome<Unit>>(TaskCreationOptions.RunContinuationsAsynchronously);
        var fixture = new Fixture { StartOverride = (_, _, _, _) => new(start.Task) };
        await using var coordinator = fixture.Create();
        var press = await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(10)), Preferences);
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Released, new(11)), Preferences);
        start.SetResult(Outcome<Unit>.Success(press.Attempt, default));
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(1, fixture.Cancellations);
        Assert.AreEqual(0, fixture.Transcriptions);
        Assert.AreEqual(DictationState.Idle, coordinator.Status.State);
    }

    [TestMethod]
    public async Task DuplicateReleaseAndBusyPressNeverDuplicatePipeline()
    {
        var fixture = new Fixture();
        await using var coordinator = fixture.Create();
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(10)), Preferences);
        await fixture.Started.Task.WaitAsync(TimeSpan.FromSeconds(1));
        var busy = await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(11)), Preferences);
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Released, new(20)), Preferences);
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Released, new(20)), Preferences);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(ErrorCode.Busy, busy.Failure?.Code);
        Assert.AreEqual(1, fixture.Transcriptions);
        Assert.AreEqual(1, fixture.Insertions);
    }

    [TestMethod]
    public async Task CancelDuringClipboardSuppressesInsertionAndAllowsNextAttempt()
    {
        var copy = new TaskCompletionSource<Outcome<ClipboardToken>>(TaskCreationOptions.RunContinuationsAsynchronously);
        var fixture = new Fixture
        {
            ClipboardOverride = (attempt, _, _) => new(copy.Task)
        };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await fixture.CopyEntered.Task.WaitAsync(TimeSpan.FromSeconds(1));
        await coordinator.CancelAsync();
        copy.SetResult(Outcome<ClipboardToken>.Success(fixture.Attempt,
            new(fixture.Attempt, 1, new string('a', 64))));
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(0, fixture.Insertions);
        Assert.AreEqual(DictationState.Idle, coordinator.Status.State);
    }

    [TestMethod]
    public async Task FailedTargetRetainsClipboardTextForManualPaste()
    {
        var fixture = new Fixture { TargetError = ErrorCode.TargetChanged };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(1, fixture.Copies);
        Assert.AreEqual(0, fixture.Insertions);
        Assert.AreEqual(DictationState.Failed, coordinator.Status.State);
        Assert.AreEqual(RecoveryAction.PasteManually, coordinator.Status.Recovery?.Action);
        Assert.AreEqual(fixture.Text, coordinator.LastResult);
    }

    [TestMethod]
    public async Task CopyLastCopiesOnlyAndNeverInserts()
    {
        var fixture = new Fixture();
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        var before = fixture.Copies;
        var copied = await coordinator.CopyLastAsync();
        Assert.IsTrue(copied.IsSuccess);
        Assert.AreEqual(before + 1, fixture.Copies);
        Assert.AreEqual(1, fixture.Insertions);
    }

    [TestMethod]
    public async Task ClearLastRemovesRecoveryCopyFromRam()
    {
        var fixture = new Fixture { TargetError = ErrorCode.TargetChanged };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(fixture.Text, coordinator.Status.Recovery?.CompletedText);
        Assert.IsTrue((await coordinator.ClearLastResultAsync()).IsSuccess);
        Assert.IsNull(coordinator.LastResult);
        Assert.IsNull(coordinator.Status.Recovery?.CompletedText);
        Assert.IsFalse(coordinator.Status.HasLastResult);
    }

    [TestMethod]
    public async Task AudioCleanupFailureIsFatalAndBlocksAnotherPress()
    {
        var fixture = new Fixture { AudioCleanupFailure = true };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.IsTrue(coordinator.Status.IsFatal);
        Assert.AreEqual(RecoveryAction.ReopenApplication, coordinator.Status.Recovery?.Action);
        var retry = await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(30)), Preferences);
        Assert.AreEqual(ErrorCode.Busy, retry.Failure?.Code);
    }

    [TestMethod]
    public async Task TargetLifetimeCleanupFailureIsFatal()
    {
        var fixture = new Fixture { TargetEndFailure = true };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.IsTrue(coordinator.Status.IsFatal);
        Assert.AreEqual(ErrorCode.CleanupFailed, coordinator.Status.Recovery?.Code);
    }

    [TestMethod]
    public async Task MissingModelHasSpecificRecoveryAndRequiresAcknowledgment()
    {
        var fixture = new Fixture { ModelError = ErrorCode.ModelMissing };
        await using var coordinator = fixture.Create();
        await RecordAndReleaseAsync(coordinator, fixture);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(RecoveryAction.DownloadOrImportModel, coordinator.Status.Recovery?.Action);
        var blocked = await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(30)), Preferences);
        Assert.AreEqual(ErrorCode.Busy, blocked.Failure?.Code);
        await coordinator.AcknowledgeFailureAsync();
        Assert.AreEqual(DictationState.Idle, coordinator.Status.State);
    }

    [TestMethod]
    public async Task UnexpectedStartExceptionFailsClosedAndObserverCannotCorruptState()
    {
        var fixture = new Fixture
        {
            StartOverride = (_, _, _, _) => throw new IOException("fixture")
        };
        await using var coordinator = fixture.Create();
        coordinator.StatusChanged += _ => throw new InvalidOperationException("observer fixture");
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(10)), Preferences);
        await coordinator.WaitForQuiescenceAsync();
        Assert.AreEqual(DictationState.Failed, coordinator.Status.State);
        Assert.IsTrue(coordinator.Status.IsFatal);
        Assert.AreEqual(ErrorCode.CleanupFailed, coordinator.Status.Recovery?.Code);
    }

    [TestMethod]
    public async Task PreCancelledPublicOperationsReturnTypedCancellation()
    {
        var fixture = new Fixture();
        await using var coordinator = fixture.Create();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        Assert.AreEqual(OutcomeKind.Cancelled,
            (await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(1)), Preferences, cancellation.Token)).Kind);
        Assert.AreEqual(OutcomeKind.Cancelled, (await coordinator.CancelAsync(cancellation.Token)).Kind);
        Assert.AreEqual(OutcomeKind.Cancelled, (await coordinator.CopyLastAsync(cancellation.Token)).Kind);
        Assert.AreEqual(OutcomeKind.Cancelled, (await coordinator.ClearLastResultAsync(cancellation.Token)).Kind);
    }

    private static async Task RecordAndReleaseAsync(DictationCoordinator coordinator, Fixture fixture)
    {
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Pressed, new(10)), Preferences);
        await fixture.Started.Task.WaitAsync(TimeSpan.FromSeconds(1));
        await coordinator.HandleShortcutAsync(new(ShortcutEdgeKind.Released, new(20)), Preferences);
    }

    private sealed class Fixture
    {
        private readonly List<string>? events;
        internal Fixture(List<string>? events = null) { this.events = events; }
        internal string Text { get; set; } = "Éric rodou o whisper.cpp.";
        internal TranscriptOutcome Transcript { get; set; } = TranscriptOutcome.Text;
        internal ErrorCode? ModelError { get; set; }
        internal ErrorCode? TargetError { get; set; }
        internal bool AudioCleanupFailure { get; set; }
        internal bool TargetEndFailure { get; set; }
        internal Func<AttemptId, string, MonotonicTimestamp, CancellationToken, ValueTask<Outcome<Unit>>>? StartOverride { get; set; }
        internal Func<AttemptId, string, CancellationToken, ValueTask<Outcome<ClipboardToken>>>? ClipboardOverride { get; set; }
        internal TaskCompletionSource Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal TaskCompletionSource CopyEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal AttemptId Attempt { get; private set; }
        internal int Copies { get; private set; }
        internal int Insertions { get; private set; }
        internal int Cancellations { get; private set; }
        internal int Transcriptions { get; private set; }
        internal TestAudioLease AudioLease { get; private set; } = null!;
        internal TestModelLease ModelLease { get; private set; } = null!;

        internal DictationCoordinator Create()
        {
            var clock = new ManualClock();
            var audio = new FakeAudioRecorder
            {
                OnStart = async (attempt, device, at, token) =>
                {
                    Attempt = attempt;
                    events?.Add("start");
                    Started.TrySetResult();
                    return StartOverride is null
                        ? Outcome<Unit>.Success(attempt, default)
                        : await StartOverride(attempt, device, at, token);
                },
                OnStop = (attempt, at, token) =>
                {
                    events?.Add("stop");
                    AudioLease = new(new(attempt, "owned/input.wav", 16_000, TimeSpan.FromSeconds(1),
                        new(-20, 16_000, TimeSpan.FromSeconds(1)), new(10), at));
                    if (AudioCleanupFailure)
                    {
                        AudioLease.Cleanup = () => ValueTask.FromException(new IOException("fixture"));
                    }
                    return ValueTask.FromResult(Outcome<AudioLease>.Success(attempt, AudioLease));
                },
                OnCancel = (attempt, _) =>
                {
                    Cancellations++;
                    return ValueTask.FromResult(Outcome<Unit>.Success(attempt, default));
                }
            };
            var model = new FakeModelStore
            {
                OnAcquire = (attempt, _) =>
                {
                    events?.Add("model");
                    if (ModelError is { } error) { return ValueTask.FromResult(Outcome<VerifiedModelLease>.Failed(attempt, error)); }
                    ModelLease = new(attempt, new("model.bin", 1, new string('a', 64)), "owned/model.bin");
                    return ValueTask.FromResult(Outcome<VerifiedModelLease>.Success(attempt, ModelLease));
                }
            };
            var transcriber = new FakeTranscriber
            {
                OnTranscribe = (attempt, _, _, _, _, _) =>
                {
                    events?.Add("transcribe");
                    Transcriptions++;
                    return ValueTask.FromResult(Transcript == TranscriptOutcome.Text
                        ? TranscriptResult.Completed(attempt, Text)
                        : TranscriptResult.WithoutText(attempt, Transcript));
                }
            };
            ITargetProbe target = TargetEndFailure
                ? new TargetLifetimeProbe()
                : new FakeTargetProbe
                {
                    OnCapture = (attempt, at, _) => ValueTask.FromResult(TargetError is { } error
                        ? Outcome<TargetSnapshot>.Failed(attempt, error)
                        : Outcome<TargetSnapshot>.Success(attempt, Target(attempt, at)))
                };
            var clipboard = new FakeClipboard
            {
                OnCommit = async (attempt, text, token) =>
                {
                    events?.Add("copy");
                    Copies++;
                    CopyEntered.TrySetResult();
                    return ClipboardOverride is null
                        ? Outcome<ClipboardToken>.Success(attempt, new(attempt, (uint)Copies, new string('a', 64)))
                        : await ClipboardOverride(attempt, text, token);
                }
            };
            var injector = new FakeTextInjector
            {
                OnInsert = (attempt, _, _, _) =>
                {
                    events?.Add("insert");
                    Insertions++;
                    return ValueTask.FromResult(Outcome<InjectionResult>.Success(attempt,
                        new(InjectionDisposition.Dispatched, ErrorCode.None)));
                }
            };
            return new(clock, audio, model, transcriber, target, clipboard, injector);
        }

        private static TargetSnapshot Target(AttemptId attempt, MonotonicTimestamp at) =>
            new(attempt, 1, 1, 1, 42, 100, 1, "desktop", TargetIntegrity.Medium,
                ImmutableArray.Create(1, 2), 50004, false, true, false, 1,
                new("selection", true, false), at);

        private sealed class TargetLifetimeProbe : ITargetProbe, ITargetAttemptLifetime
        {
            public ValueTask<Outcome<TargetSnapshot>> CaptureAsync(AttemptId attempt, MonotonicTimestamp pressedAt,
                CancellationToken cancellationToken) => ValueTask.FromResult(
                    Outcome<TargetSnapshot>.Success(attempt, Target(attempt, pressedAt)));
            public ValueTask<Outcome<TargetCheck>> CheckAsync(AttemptId attempt, TargetSnapshot target,
                CancellationToken cancellationToken) => ValueTask.FromResult(
                    Outcome<TargetCheck>.Success(attempt, TargetCheck.SameTarget));
            public void End(AttemptId attempt) => throw new IOException("fixture");
        }
    }
}
