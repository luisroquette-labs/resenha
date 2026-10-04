namespace Resenha.Core;

// The coordinator supplies only an atomic activity flag, never work in the hook.
// Keep this true through transcription/insertion so Escape can cancel them too.
public interface IShortcutAttemptContext
{
    void SetAttemptActive(bool active);
}

public readonly record struct PhysicalKey(ushort ScanCode, bool IsExtended = false);
public readonly record struct KeyboardInput(PhysicalKey Key, bool IsDown, bool IsInjected = false);
public readonly record struct ShortcutDecision(bool Suppress, ShortcutEdge? Edge = null);
public readonly record struct ShortcutKeySnapshot(bool TriggerDown, ShortcutModifiers Modifiers, bool DesktopAvailable = true);

// Single input-thread owner. All state and callback work are fixed-size; native
// calls, dispatch, capture and UI work belong outside this portable policy.
public sealed class ShortcutPolicy
{
    public static Shortcut Default { get; } = new(0x39, false, ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt);
    public static TimeSpan WatchdogInterval { get; } = TimeSpan.FromMilliseconds(100);
    public static TimeSpan MaximumHold { get; } = TimeSpan.FromSeconds(120);
    private const ShortcutModifiers Controls = ShortcutModifiers.LeftControl | ShortcutModifiers.RightControl;
    private const ShortcutModifiers Shifts = ShortcutModifiers.LeftShift | ShortcutModifiers.RightShift;
    private const ShortcutModifiers Allowed = Controls | Shifts | ShortcutModifiers.LeftAlt;
    private readonly bool[] keys = new bool[512];
    private bool armed;
    private bool holding;
    private bool triggerOwned;
    private bool enabled = true;
    private bool stopped;
    private bool escapeReported;
    private MonotonicTimestamp pressedAt;
    private MonotonicTimestamp? lastWatchdog;

    public ShortcutPolicy(Shortcut shortcut)
    {
        if (Validate(shortcut) != ErrorCode.None) { throw new ArgumentException("Invalid physical shortcut.", nameof(shortcut)); }
        Shortcut = shortcut;
    }

    public Shortcut Shortcut { get; }
    public bool IsHolding => holding;
    public bool IsArmed => armed && enabled && !stopped;
    public bool AllChordKeysUp => !keys[TriggerIndex] && (Modifiers & Shortcut.Modifiers) == 0;
    private int TriggerIndex => Index(new(Shortcut.ScanCode, Shortcut.IsExtended));

    public static ErrorCode Validate(Shortcut? shortcut, bool observedOccupied = false)
    {
        if (shortcut is null || shortcut.ScanCode is 0 or > 0x7f || shortcut.Modifiers == ShortcutModifiers.None ||
            (shortcut.Modifiers & ~Allowed) != 0 || ModifierFor(new(shortcut.ScanCode, shortcut.IsExtended)) != ShortcutModifiers.None)
        {
            return ErrorCode.ShortcutInvalid;
        }

        bool control = (shortcut.Modifiers & Controls) != 0;
        bool alt = (shortcut.Modifiers & ShortcutModifiers.LeftAlt) != 0;
        // Escape is cancellation-only; F12 belongs to the debugger. PrintScreen,
        // Pause/Break, menu/Windows and the system task-switch chords are reserved.
        if (shortcut.ScanCode is 0x01 or 0x58 ||
            (shortcut.IsExtended && shortcut.ScanCode is 0x37 or 0x45 or 0x46 or 0x5b or 0x5c or 0x5d or 0x5e or 0x5f or 0x63) ||
            (alt && shortcut.ScanCode is 0x0f or 0x3e) ||
            (alt && !control && shortcut.ScanCode == 0x39) ||
            (control && alt && shortcut.IsExtended && shortcut.ScanCode == 0x53))
        {
            return ErrorCode.ShortcutInvalid;
        }

        return observedOccupied ? ErrorCode.ShortcutOccupied : ErrorCode.None;
    }

    public ShortcutDecision Process(KeyboardInput input, MonotonicTimestamp at, bool attemptActive = false)
    {
        if (stopped || input.IsInjected || input.Key.ScanCode is 0 or > 0xff) { return default; }
        int index = Index(input.Key);
        bool wasDown = keys[index];
        bool trigger = index == TriggerIndex;
        bool suppress = trigger && triggerOwned;

        // A watchdog can observe an up whose callback was lost. A fresh down is
        // a new physical press; it must not inherit suppression from that press.
        if (trigger && input.IsDown && !wasDown) { triggerOwned = false; suppress = false; }
        keys[index] = input.IsDown;
        if (!attemptActive && !holding) { escapeReported = false; }

        if (!input.IsDown)
        {
            if (trigger) { triggerOwned = false; }
            ShortcutEdge? edge = null;
            if (holding && (trigger || (ModifierFor(input.Key) & Shortcut.Modifiers) != 0))
            {
                holding = false;
                edge = new(ShortcutEdgeKind.Released, at);
            }
            RearmIfUp();
            return new(suppress, edge);
        }

        if (wasDown) { return new(suppress); }
        if (input.Key == new PhysicalKey(0x01) && (holding || attemptActive) && !escapeReported)
        {
            escapeReported = true;
            return new(false, Interrupt(at, force: true));
        }

        var modifier = ModifierFor(input.Key);
        if (holding && modifier != ShortcutModifiers.None && (modifier & Shortcut.Modifiers) == 0)
        {
            return new(false, Interrupt(at));
        }

        if (!trigger) { return default; }
        if (!IsArmed || Modifiers != Shortcut.Modifiers)
        {
            armed = false;
            return default;
        }

        triggerOwned = true;
        armed = false;
        holding = true;
        escapeReported = false;
        pressedAt = at;
        return new(true, new(ShortcutEdgeKind.Pressed, at));
    }

    // Called from a 100 ms timer, independently of hook edge delivery. Async
    // native key state is intentionally never sampled inside the LL callback.
    public ShortcutEdge? Watchdog(ShortcutKeySnapshot snapshot, MonotonicTimestamp at)
    {
        if (stopped) { return null; }
        bool gap = lastWatchdog is { } previous &&
            (at.Ticks < previous.Ticks || at.ElapsedSince(previous) > TimeSpan.FromMilliseconds(500));
        lastWatchdog = at;
        bool lostRelease = holding && (!snapshot.TriggerDown || snapshot.Modifiers != Shortcut.Modifiers);
        bool expired = holding && (at.Ticks < pressedAt.Ticks || at.ElapsedSince(pressedAt) >= MaximumHold);
        ShortcutEdge? edge = null;
        if (!snapshot.DesktopAvailable || lostRelease || expired || (holding && gap))
        {
            edge = Interrupt(at);
        }

        if (!snapshot.DesktopAvailable)
        {
            enabled = false;
            return edge;
        }

        keys[TriggerIndex] = snapshot.TriggerDown;
        foreach (var modifier in ModifierKeys)
        {
            keys[Index(modifier.Key)] = (snapshot.Modifiers & modifier.Modifier) != 0;
        }
        RearmIfUp();
        return edge;
    }

    public ShortcutEdge? Suspend(MonotonicTimestamp at, bool attemptActive = false)
    {
        if (stopped) { return null; }
        enabled = false;
        return Interrupt(at, attemptActive);
    }

    // The adapter reinstalls the hook only after a current physical snapshot
    // proves all chord keys and modifiers are up on the original input desktop.
    public bool Resume(ShortcutKeySnapshot snapshot, MonotonicTimestamp at)
    {
        if (stopped || !snapshot.DesktopAvailable || snapshot.TriggerDown || snapshot.Modifiers != ShortcutModifiers.None) { return false; }
        Array.Clear(keys);
        enabled = true;
        armed = true;
        lastWatchdog = at;
        return true;
    }

    public ShortcutEdge? Shutdown(MonotonicTimestamp at, bool attemptActive = false)
    {
        if (stopped) { return null; }
        var edge = Interrupt(at, attemptActive);
        stopped = true;
        enabled = false;
        triggerOwned = false;
        return edge;
    }

    private ShortcutEdge? Interrupt(MonotonicTimestamp at, bool force = false)
    {
        bool emit = holding || force;
        holding = false;
        armed = false;
        return emit ? new(ShortcutEdgeKind.Interrupted, at) : null;
    }

    private void RearmIfUp()
    {
        if (enabled && !holding && AllChordKeysUp && Modifiers == ShortcutModifiers.None) { armed = true; }
    }

    private ShortcutModifiers Modifiers
    {
        get
        {
            var value = ShortcutModifiers.None;
            foreach (var modifier in ModifierKeys)
            {
                if (keys[Index(modifier.Key)]) { value |= modifier.Modifier; }
            }
            return value;
        }
    }

    private static int Index(PhysicalKey key) => key.ScanCode | (key.IsExtended ? 256 : 0);
    public static ShortcutModifiers ModifierFor(PhysicalKey key) => key switch
    {
        { ScanCode: 0x1d, IsExtended: false } => ShortcutModifiers.LeftControl,
        { ScanCode: 0x1d, IsExtended: true } => ShortcutModifiers.RightControl,
        { ScanCode: 0x38, IsExtended: false } => ShortcutModifiers.LeftAlt,
        { ScanCode: 0x38, IsExtended: true } => ShortcutModifiers.RightAlt,
        { ScanCode: 0x2a, IsExtended: false } => ShortcutModifiers.LeftShift,
        { ScanCode: 0x36, IsExtended: false } => ShortcutModifiers.RightShift,
        { ScanCode: 0x5b, IsExtended: true } => ShortcutModifiers.LeftWindows,
        { ScanCode: 0x5c, IsExtended: true } => ShortcutModifiers.RightWindows,
        _ => ShortcutModifiers.None
    };

    private static readonly (PhysicalKey Key, ShortcutModifiers Modifier, int VirtualKey)[] modifierKeys =
    [
        (new(0x1d), ShortcutModifiers.LeftControl, 0xa2), (new(0x1d, true), ShortcutModifiers.RightControl, 0xa3),
        (new(0x38), ShortcutModifiers.LeftAlt, 0xa4), (new(0x38, true), ShortcutModifiers.RightAlt, 0xa5),
        (new(0x2a), ShortcutModifiers.LeftShift, 0xa0), (new(0x36), ShortcutModifiers.RightShift, 0xa1),
        (new(0x5b, true), ShortcutModifiers.LeftWindows, 0x5b), (new(0x5c, true), ShortcutModifiers.RightWindows, 0x5c)
    ];
    public static ReadOnlySpan<(PhysicalKey Key, ShortcutModifiers Modifier, int VirtualKey)> ModifierKeys => modifierKeys;
}
