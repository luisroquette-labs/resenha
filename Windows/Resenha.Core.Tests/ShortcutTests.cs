using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class ShortcutTests
{
    private static readonly PhysicalKey Control = new(0x1d);
    private static readonly PhysicalKey Alt = new(0x38);
    private static readonly PhysicalKey Space = new(0x39);
    private static readonly PhysicalKey Escape = new(0x01);
    private const ShortcutModifiers DefaultModifiers = ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt;

    [TestMethod]
    public void DefaultUsesPhysicalSpaceAndExactLeftModifiers()
    {
        Assert.AreEqual(new Shortcut(0x39, false, DefaultModifiers), ShortcutPolicy.Default);
        Assert.AreEqual(ErrorCode.None, ShortcutPolicy.Validate(ShortcutPolicy.Default));
        Assert.AreEqual(ErrorCode.ShortcutOccupied, ShortcutPolicy.Validate(ShortcutPolicy.Default, observedOccupied: true));
        Assert.AreEqual(TimeSpan.FromMilliseconds(100), ShortcutPolicy.WatchdogInterval);
    }

    [TestMethod]
    public void InvalidAndReservedChordsAreRejectedBeforeConflictProbe()
    {
        Shortcut[] invalid =
        [
            new(0, false, DefaultModifiers), new(0x100, false, DefaultModifiers), new(0x39, false, ShortcutModifiers.None),
            new(0x1d, false, DefaultModifiers), new(0x38, true, DefaultModifiers), new(0x2a, false, DefaultModifiers),
            new(0x39, false, ShortcutModifiers.RightAlt), new(0x39, false, ShortcutModifiers.LeftWindows),
            new(0x39, false, ShortcutModifiers.RightWindows), new(0x39, false, (ShortcutModifiers)256),
            new(0x58, false, DefaultModifiers), new(0x01, false, DefaultModifiers), new(0x53, true, DefaultModifiers),
            new(0x0f, false, ShortcutModifiers.LeftAlt), new(0x3e, false, ShortcutModifiers.LeftAlt),
            new(0x39, false, ShortcutModifiers.LeftAlt), new(0x37, true, DefaultModifiers), new(0x45, true, DefaultModifiers)
        ];
        Assert.AreEqual(ErrorCode.ShortcutInvalid, ShortcutPolicy.Validate(null));
        foreach (var shortcut in invalid)
        {
            Assert.AreEqual(ErrorCode.ShortcutInvalid, ShortcutPolicy.Validate(shortcut, observedOccupied: true), shortcut.ToString());
            Assert.Throws<ArgumentException>(() => new ShortcutPolicy(shortcut));
        }
    }

    [TestMethod]
    public void PhysicalAbnt2KeyAndRightControlCanBeConfigured()
    {
        var shortcut = new Shortcut(0x73, false, ShortcutModifiers.RightControl);
        var policy = Ready(shortcut);
        policy.Process(new(new(0x1d, true), true), new(0));
        var accepted = policy.Process(new(new(0x73), true), new(1));
        Assert.AreEqual(ShortcutEdgeKind.Pressed, accepted.Edge?.Kind);
        Assert.IsTrue(accepted.Suppress);
        Assert.AreEqual(ErrorCode.None, ShortcutPolicy.Validate(new(0x7e, false, ShortcutModifiers.LeftControl)));
    }

    [TestMethod]
    public void AutoRepeatProducesOnePressAndOneReleaseWithLatchedSuppression()
    {
        var policy = Ready();
        Assert.AreEqual(ShortcutEdgeKind.Pressed, Press(policy).Edge?.Kind);
        for (int i = 0; i < 20; i++)
        {
            var repeat = policy.Process(new(Space, true), new(i + 1));
            Assert.IsTrue(repeat.Suppress);
            Assert.IsNull(repeat.Edge);
        }
        var release = policy.Process(new(Space, false), new(30));
        Assert.IsTrue(release.Suppress);
        Assert.AreEqual(ShortcutEdgeKind.Released, release.Edge?.Kind);
        Assert.IsFalse(policy.Process(new(Space, false), new(31)).Suppress);
        Assert.IsNull(policy.Process(new(Alt, false), new(32)).Edge);
        Assert.IsNull(policy.Process(new(Control, false), new(33)).Edge);
        Assert.IsTrue(policy.IsArmed);
    }

    [TestMethod]
    public void ReleasingAnyRequiredKeyStopsOnceButStillOwnsTriggerUp()
    {
        foreach (var firstReleased in new[] { Control, Alt, Space })
        {
            var policy = Ready();
            Press(policy);
            var release = policy.Process(new(firstReleased, false), new(1));
            Assert.AreEqual(ShortcutEdgeKind.Released, release.Edge?.Kind);
            Assert.IsFalse(policy.IsHolding);
            foreach (var key in new[] { Control, Alt, Space }.Where(key => key != firstReleased))
            {
                var later = policy.Process(new(key, false), new(2));
                Assert.IsNull(later.Edge);
                Assert.AreEqual(key == Space, later.Suppress);
            }
            Assert.IsTrue(policy.IsArmed);
        }
    }

    [TestMethod]
    public void UnrelatedKeyUpAndKeyDownPassWithoutStoppingOrRearming()
    {
        var policy = Ready();
        Press(policy);
        foreach (var down in new[] { false, true, false })
        {
            var unrelated = policy.Process(new(new(0x1e), down), new(1));
            Assert.IsNull(unrelated.Edge);
            Assert.IsFalse(unrelated.Suppress);
            Assert.IsTrue(policy.IsHolding);
            Assert.IsFalse(policy.IsArmed);
        }
    }

    [TestMethod]
    public void InjectedEdgesNeitherStartNorReleaseNorMutatePhysicalKeys()
    {
        var policy = Ready();
        foreach (var key in new[] { Control, Alt, Space })
        {
            Assert.AreEqual(default, policy.Process(new(key, true, IsInjected: true), new(0)));
        }
        Assert.IsFalse(policy.IsHolding);
        Press(policy);
        Assert.AreEqual(default, policy.Process(new(Space, false, IsInjected: true), new(1)));
        Assert.IsTrue(policy.IsHolding);
        Assert.AreEqual(ShortcutEdgeKind.Released, policy.Process(new(Space, false), new(2)).Edge?.Kind);
    }

    [TestMethod]
    public void BusyPressIsStillSuppressedAndNotQueuedForLater()
    {
        var policy = Ready();
        policy.Process(new(Control, true), new(0), attemptActive: true);
        policy.Process(new(Alt, true), new(0), attemptActive: true);
        var busy = policy.Process(new(Space, true), new(0), attemptActive: true);
        // Busy is the coordinator's decision. The raw press is emitted once;
        // ownership cannot be lost just because the coordinator rejects it.
        Assert.IsTrue(busy.Suppress);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, busy.Edge?.Kind);
        Assert.IsNull(policy.Process(new(Space, true), new(1), attemptActive: false).Edge);
        Assert.IsTrue(policy.Process(new(Space, false), new(2)).Suppress);
        Assert.IsNull(policy.Watchdog(new(false, DefaultModifiers), new(3)));
        Assert.IsFalse(policy.IsArmed);
        ReleaseAll(policy);
        Assert.IsTrue(policy.IsArmed);
    }

    [TestMethod]
    public void AllRequiredKeysMustBeUpBeforeAnyNewPress()
    {
        var policy = Ready();
        Press(policy);
        policy.Process(new(Space, false), new(1));
        var premature = policy.Process(new(Space, true), new(2));
        Assert.IsNull(premature.Edge);
        Assert.IsFalse(premature.Suppress);
        policy.Process(new(Control, false), new(3));
        policy.Process(new(Alt, false), new(3));
        Assert.IsFalse(policy.IsArmed);
        policy.Process(new(Space, false), new(4));
        Assert.IsTrue(policy.IsArmed);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, Press(policy).Edge?.Kind);
    }

    [TestMethod]
    public void TriggerPressedBeforeModifiersCannotStartOnLaterModifierOrRepeat()
    {
        var policy = Ready();
        Assert.IsNull(policy.Process(new(Space, true), new(0)).Edge);
        policy.Process(new(Control, true), new(1));
        policy.Process(new(Alt, true), new(2));
        Assert.IsNull(policy.Process(new(Space, true), new(3)).Edge);
        Assert.IsFalse(policy.IsHolding);
        ReleaseAll(policy);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, Press(policy).Edge?.Kind);
    }

    [TestMethod]
    public void AltGrCannotMasqueradeAsLeftControlLeftAlt()
    {
        var policy = Ready();
        policy.Process(new(Control, true), new(0)); // Windows AltGr's companion Ctrl.
        policy.Process(new(new(0x38, true), true), new(0));
        policy.Process(new(Alt, true), new(0));
        var altGr = policy.Process(new(Space, true), new(1));
        Assert.IsFalse(altGr.Suppress);
        Assert.IsNull(altGr.Edge);
        Assert.IsFalse(policy.IsHolding);
    }

    [TestMethod]
    public void RightSideModifierIsNotInterchangeableWithConfiguredLeftSide()
    {
        var policy = Ready();
        policy.Process(new(new(0x1d, true), true), new(0));
        policy.Process(new(Alt, true), new(0));
        Assert.IsNull(policy.Process(new(Space, true), new(1)).Edge);
    }

    [TestMethod]
    public void ExtraModifierCancelsAndPassesThroughWhileTriggerUpRemainsOwned()
    {
        foreach (var key in new[] { new PhysicalKey(0x2a), new PhysicalKey(0x1d, true), new PhysicalKey(0x38, true), new PhysicalKey(0x5b, true) })
        {
            var policy = Ready();
            Press(policy);
            var extra = policy.Process(new(key, true), new(1));
            Assert.IsFalse(extra.Suppress);
            Assert.AreEqual(ShortcutEdgeKind.Interrupted, extra.Edge?.Kind);
            Assert.IsNull(policy.Process(new(key, true), new(2)).Edge);
            Assert.IsTrue(policy.Process(new(Space, false), new(3)).Suppress);
            Assert.IsFalse(policy.IsHolding);
        }
    }

    [TestMethod]
    public void EscapeOnlyCancelsActiveWorkAndIsNeverGloballySuppressed()
    {
        var idle = Ready();
        Assert.AreEqual(default, idle.Process(new(Escape, true), new(0)));
        var active = Ready();
        var cancel = active.Process(new(Escape, true), new(1), attemptActive: true);
        Assert.IsFalse(cancel.Suppress);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, cancel.Edge?.Kind);
        Assert.IsNull(active.Process(new(Escape, true), new(2), attemptActive: true).Edge);
        active.Process(new(Escape, false), new(3), attemptActive: true);
        Assert.IsNull(active.Process(new(Escape, true), new(4), attemptActive: true).Edge);
    }

    [TestMethod]
    public void EscapeDuringHoldCancelsWithoutAReleaseCompletion()
    {
        var policy = Ready();
        Press(policy);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, policy.Process(new(Escape, true), new(1)).Edge?.Kind);
        var later = policy.Process(new(Space, false), new(2));
        Assert.IsTrue(later.Suppress);
        Assert.IsNull(later.Edge);
    }

    [TestMethod]
    public void WatchdogLostReleaseCancelsInsteadOfTranscribingAndLateUpIsSuppressed()
    {
        var clock = new ManualClock();
        var policy = Ready();
        Press(policy);
        clock.Advance(ShortcutPolicy.WatchdogInterval);
        var cancelled = policy.Watchdog(new(false, DefaultModifiers), clock.Now);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, cancelled?.Kind);
        Assert.AreEqual(clock.Now, cancelled?.At);
        Assert.IsFalse(policy.IsHolding);
        clock.Advance(ShortcutPolicy.WatchdogInterval);
        Assert.IsNull(policy.Watchdog(new(false, ShortcutModifiers.None), clock.Now));
        Assert.IsTrue(policy.IsArmed);
        var late = policy.Process(new(Space, false), clock.Now);
        Assert.IsTrue(late.Suppress);
        Assert.IsNull(late.Edge);
    }

    [TestMethod]
    public void MissingUpDoesNotStealAnUnrelatedFreshTriggerPress()
    {
        var policy = Ready();
        Press(policy);
        policy.Watchdog(new(false, ShortcutModifiers.None), new(1));
        var plainSpace = policy.Process(new(Space, true), new(2));
        Assert.IsFalse(plainSpace.Suppress);
        Assert.IsNull(plainSpace.Edge);
        Assert.IsFalse(policy.Process(new(Space, false), new(3)).Suppress);
    }

    [TestMethod]
    public void WatchdogDetectsMissingModifierAndNewExtraModifier()
    {
        foreach (var modifiers in new[] { ShortcutModifiers.LeftAlt, DefaultModifiers | ShortcutModifiers.RightAlt })
        {
            var policy = Ready();
            Press(policy);
            Assert.AreEqual(ShortcutEdgeKind.Interrupted, policy.Watchdog(new(true, modifiers), new(1))?.Kind);
            Assert.IsFalse(policy.IsHolding);
            Assert.IsFalse(policy.IsArmed);
        }
    }

    [TestMethod]
    public void SuspendOrLockCancelsAndRequiresAllKeysUpOnOriginalDesktop()
    {
        var policy = Ready();
        Press(policy);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, policy.Suspend(new(1))?.Kind);
        Assert.IsFalse(policy.Resume(new(true, DefaultModifiers), new(2)));
        Assert.IsFalse(policy.Resume(new(false, ShortcutModifiers.None, DesktopAvailable: false), new(3)));
        Assert.IsFalse(policy.Resume(new(false, ShortcutModifiers.RightAlt), new(4)));
        Assert.IsFalse(policy.IsArmed);
        Assert.IsTrue(policy.Resume(new(false, ShortcutModifiers.None), new(5)));
        Assert.IsTrue(policy.IsArmed);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, Press(policy).Edge?.Kind);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, policy.Watchdog(new(false, ShortcutModifiers.None, DesktopAvailable: false), new(6))?.Kind);
        Assert.IsFalse(policy.IsArmed);
    }

    [TestMethod]
    public void StartupWithHeldKeysCannotStartUntilAllHaveBeenReleased()
    {
        var policy = new ShortcutPolicy(ShortcutPolicy.Default);
        policy.Watchdog(new(true, DefaultModifiers), new(0));
        Assert.IsFalse(policy.IsArmed);
        Assert.IsNull(policy.Process(new(Space, true), new(1)).Edge);
        ReleaseAll(policy);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, Press(policy).Edge?.Kind);
    }

    [TestMethod]
    public void DelayedWatchdogAndMaximumHoldCancelWithFakeClock()
    {
        var clock = new ManualClock();
        var stalled = Ready();
        Press(stalled);
        clock.Advance(TimeSpan.FromMilliseconds(501));
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, stalled.Watchdog(new(true, DefaultModifiers), clock.Now)?.Kind);

        var limit = Ready();
        Press(limit);
        for (int i = 1; i < 1200; i++)
        {
            Assert.IsNull(limit.Watchdog(new(true, DefaultModifiers), new(i * TimeSpan.TicksPerMillisecond * 100)));
        }
        var interrupted = limit.Watchdog(new(true, DefaultModifiers), new(ShortcutPolicy.MaximumHold.Ticks));
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, interrupted?.Kind);
        Assert.IsFalse(limit.IsHolding);
    }

    [TestMethod]
    public void ShutdownIsIdempotentCancelsActiveAttemptAndNeverRearms()
    {
        var policy = Ready();
        Press(policy);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, policy.Shutdown(new(1))?.Kind);
        Assert.IsNull(policy.Shutdown(new(2), attemptActive: true));
        Assert.IsNull(policy.Watchdog(new(false, ShortcutModifiers.None), new(3)));
        Assert.IsFalse(policy.Resume(new(false, ShortcutModifiers.None), new(4)));
        Assert.IsNull(Press(policy).Edge);
        Assert.IsFalse(policy.IsArmed);
        Assert.AreEqual(ShortcutEdgeKind.Interrupted, Ready().Shutdown(new(1), attemptActive: true)?.Kind);
    }

    [TestMethod]
    public void CallbackOrderingRetainsPressThenFirstReleaseTimestamps()
    {
        var clock = new ManualClock();
        var policy = Ready();
        clock.Advance(TimeSpan.FromMilliseconds(20));
        policy.Process(new(Control, true), clock.Now);
        policy.Process(new(Alt, true), clock.Now);
        var press = policy.Process(new(Space, true), clock.Now).Edge;
        clock.Advance(TimeSpan.FromMilliseconds(10));
        var release = policy.Process(new(Alt, false), clock.Now).Edge;
        Assert.IsNotNull(press);
        Assert.IsNotNull(release);
        Assert.AreEqual(ShortcutEdgeKind.Pressed, press.Kind);
        Assert.AreEqual(ShortcutEdgeKind.Released, release.Kind);
        Assert.AreEqual(TimeSpan.FromMilliseconds(10), release.At.ElapsedSince(press.At));
        Assert.IsNull(policy.Process(new(Space, false), clock.Now).Edge);
    }

    [TestMethod]
    public void ShutdownAndSuspendBoundariesCancelAPressReleaseAwaitingDispatch()
    {
        foreach (bool shutdown in new[] { false, true })
        {
            var policy = Ready();
            List<ShortcutEdge> pending = [Press(policy).Edge!, policy.Process(new(Space, false), new(1)).Edge!];
            // The input producer queues the boundary regardless of whether the
            // coordinator has dispatched the preceding press yet.
            pending.Add((shutdown ? policy.Shutdown(new(2), attemptActive: true) : policy.Suspend(new(2), attemptActive: true))!);
            CollectionAssert.AreEqual(new[] { ShortcutEdgeKind.Pressed, ShortcutEdgeKind.Released, ShortcutEdgeKind.Interrupted }, pending.Select(edge => edge.Kind).ToArray());
            Assert.IsFalse(policy.IsArmed);
        }
    }

    private static ShortcutPolicy Ready(Shortcut? shortcut = null)
    {
        var policy = new ShortcutPolicy(shortcut ?? ShortcutPolicy.Default);
        policy.Watchdog(new(false, ShortcutModifiers.None), new(0));
        Assert.IsTrue(policy.IsArmed);
        return policy;
    }

    private static ShortcutDecision Press(ShortcutPolicy policy)
    {
        policy.Process(new(Control, true), new(0));
        policy.Process(new(Alt, true), new(0));
        return policy.Process(new(Space, true), new(0));
    }

    private static void ReleaseAll(ShortcutPolicy policy)
    {
        policy.Process(new(Control, false), new(1));
        policy.Process(new(Alt, false), new(1));
        policy.Process(new(Space, false), new(1));
    }
}
