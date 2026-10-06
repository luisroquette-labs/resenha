using System.Collections.Immutable;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class TargetIdentityTests
{
    [TestMethod]
    public async Task SameIdentityPassesOnlyWhileGenerationRemainsUnchanged()
    {
        var attempt = AttemptId.New();
        var tracker = new TargetActivityTracker();
        var broker = new FakeBroker(Response(attempt));
        var client = new TargetBrokerClient(tracker, new ManualClock(), broker);
        var captured = await client.CaptureAsync(attempt, new(0), default);
        Assert.IsTrue(captured.IsSuccess);
        Assert.AreEqual(TargetCheck.SameTarget, (await client.CheckAsync(attempt, captured.Value!, default)).Value);
        var callsBeforeInvalidation = broker.Calls;
        tracker.Observe(UserActivityKind.Mouse);
        Assert.AreEqual(TargetCheck.Changed, (await client.CheckAsync(attempt, captured.Value!, default)).Value);
        Assert.AreEqual(callsBeforeInvalidation, broker.Calls, "A permanently invalid target must not launch another broker.");
    }

    [TestMethod]
    public async Task ReturningToOriginalFieldRemainsChanged()
    {
        var attempt = AttemptId.New();
        var tracker = new TargetActivityTracker();
        var broker = new FakeBroker(Response(attempt));
        var client = new TargetBrokerClient(tracker, new ManualClock(), broker);
        var captured = (await client.CaptureAsync(attempt, new(0), default)).Value!;
        tracker.Observe(UserActivityKind.Keyboard);
        broker.Response = Response(attempt);
        Assert.AreEqual(TargetCheck.Changed, (await client.CheckAsync(attempt, captured, default)).Value);
    }

    [TestMethod]
    public async Task PasswordElevatedUnknownAndReadOnlyTargetsFailClosed()
    {
        foreach (var response in new[]
        {
            Response(AttemptId.New()) with { IsPassword = true },
            Response(AttemptId.New()) with { Integrity = TargetIntegrity.High },
            Response(AttemptId.New()) with { AutomationRuntimeId = [] },
            Response(AttemptId.New()) with { IsReadOnly = true, IsEditable = false }
        })
        {
            var attempt = new AttemptId(response.Attempt);
            var result = await new TargetBrokerClient(new(), new ManualClock(), new FakeBroker(response))
                .CaptureAsync(attempt, new(0), default);
            Assert.IsFalse(result.IsSuccess);
            Assert.IsTrue(result.Failure?.Code is ErrorCode.TargetUnsafe or ErrorCode.TargetUnknown);
        }
    }

    [TestMethod]
    public async Task HwndReuseSelectionAndBrowserRuntimeChangesAreDetected()
    {
        var attempt = AttemptId.New();
        foreach (var changed in new Func<TargetBrokerResponse, TargetBrokerResponse>[]
        {
            value => value with { ProcessCreationFileTime = value.ProcessCreationFileTime + 1 },
            value => value with { SelectionToken = new string('b', 64) },
            value => value with { AutomationRuntimeId = [9, 9, 9] },
            value => value with { FocusedChildWindow = value.FocusedChildWindow + 1 }
        })
        {
            var tracker = new TargetActivityTracker();
            var broker = new FakeBroker(Response(attempt));
            var client = new TargetBrokerClient(tracker, new ManualClock(), broker);
            var captured = (await client.CaptureAsync(attempt, new(0), default)).Value!;
            broker.Response = changed(Response(attempt));
            Assert.AreEqual(TargetCheck.Changed, (await client.CheckAsync(attempt, captured, default)).Value);
        }
    }

    [TestMethod]
    public async Task MalformedOrTimedOutBrokerBecomesUnknown()
    {
        var attempt = AttemptId.New();
        var client = new TargetBrokerClient(new(), new ManualClock(), new FakeBroker(null));
        Assert.AreEqual(ErrorCode.TargetUnknown, (await client.CaptureAsync(attempt, new(0), default)).Failure?.Code);
    }

    [TestMethod]
    public async Task ObserverLossBeforeAttemptPermanentlyFailsClosed()
    {
        var tracker = new TargetActivityTracker();
        tracker.Observe(UserActivityKind.ObserverLost);
        var attempt = AttemptId.New();
        var broker = new FakeBroker(Response(attempt));
        var result = await new TargetBrokerClient(tracker, new ManualClock(), broker)
            .CaptureAsync(attempt, new(0), default);
        Assert.AreEqual(ErrorCode.TargetChanged, result.Failure?.Code);
    }

    [TestMethod]
    public async Task DuplicateCaptureCannotResetAChangedAttempt()
    {
        var tracker = new TargetActivityTracker();
        var attempt = AttemptId.New();
        var client = new TargetBrokerClient(tracker, new ManualClock(), new FakeBroker(Response(attempt)));
        Assert.IsTrue((await client.CaptureAsync(attempt, new(0), default)).IsSuccess);
        tracker.Observe(UserActivityKind.Mouse);
        Assert.AreEqual(ErrorCode.TargetChanged,
            (await client.CaptureAsync(attempt, new(0), default)).Failure?.Code);
    }

    [TestMethod]
    public void HeldShortcutRepeatIsNotTreatedAsTargetTyping()
    {
        var shortcut = ShortcutPolicy.Default;
        Assert.IsTrue(KeyboardHook.IsChordComponent(shortcut, new(0x39)));
        Assert.IsTrue(KeyboardHook.IsChordComponent(shortcut, new(0x1d)));
        Assert.IsTrue(KeyboardHook.IsChordComponent(shortcut, new(0x38)));
        Assert.IsFalse(KeyboardHook.IsChordComponent(shortcut, new(0x20)));
        Assert.IsFalse(KeyboardHook.IsChordComponent(shortcut, new(0x38, true)), "AltGr is never a chord component.");
    }

    [TestMethod]
    public void SuppressedChordRemainsDownForWatchdogUntilHookSeesRelease()
    {
        var shortcut = new Shortcut(0x13, false,
            ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt);
        var policy = new ShortcutPolicy(shortcut);
        policy.Watchdog(new(false, ShortcutModifiers.None), new(0));
        policy.Process(new(new(0x1d), true), new(1));
        policy.Process(new(new(0x38), true), new(2));
        Assert.AreEqual(ShortcutEdgeKind.Pressed,
            policy.Process(new(new(0x13), true), new(3)).Edge?.Kind);

        var snapshot = KeyboardHook.ResolveSnapshot(policy, asynchronousTrigger: false,
            ShortcutModifiers.None, desktopAvailable: true);
        Assert.IsTrue(snapshot.TriggerDown,
            "GetAsyncKeyState can stay false when the low-level hook suppresses the trigger.");
        Assert.AreEqual(ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt, snapshot.Modifiers,
            "The active physical chord must not be released by an asynchronous modifier mismatch.");
        Assert.IsNull(policy.Watchdog(snapshot, new(4)));
        Assert.AreEqual(ShortcutEdgeKind.Released,
            policy.Process(new(new(0x13), false), new(5)).Edge?.Kind);
        Assert.IsFalse(KeyboardHook.ResolveSnapshot(policy, asynchronousTrigger: false,
            ShortcutModifiers.None, desktopAvailable: true).TriggerDown);
    }

    private static TargetBrokerResponse Response(AttemptId attempt) => new(1, new string('a', 64), attempt.Value, 10,
        100, 100, 101, 200, 123456789, 1, "Default", TargetIntegrity.Medium,
        ImmutableArray.Create(1, 2, 3), 50004, false, true, false, new string('c', 64), true, false, "ok");

    private sealed class FakeBroker(TargetBrokerResponse? response) : IFocusBrokerTransport
    {
        internal TargetBrokerResponse? Response { get; set; } = response;
        internal int Calls { get; private set; }
        public ValueTask<TargetBrokerResponse?> ProbeAsync(AttemptId attempt, CancellationToken cancellationToken)
        {
            Calls++;
            return ValueTask.FromResult(Response);
        }
    }
}
