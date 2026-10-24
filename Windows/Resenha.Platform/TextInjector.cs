using System.Runtime.InteropServices;
using Resenha.Core;

namespace Resenha.Platform;

internal interface IInputDispatcher
{
    bool AnyModifierDown { get; }
    uint SendPasteBatch();
    bool ReleaseSyntheticKeys(uint acceptedEvents);
}

public sealed class TextInjector : ITextInjector
{
    internal static readonly TimeSpan ModifierDeadline = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(20);
    private readonly ITargetProbe targets;
    private readonly IClipboard clipboard;
    private readonly IClock clock;
    private readonly IInputDispatcher input;

    public TextInjector(ITargetProbe targets, IClipboard clipboard, IClock clock)
        : this(targets, clipboard, clock, new Win32InputDispatcher()) { }

    internal TextInjector(ITargetProbe targets, IClipboard clipboard, IClock clock, IInputDispatcher input)
    {
        this.targets = targets;
        this.clipboard = clipboard;
        this.clock = clock;
        this.input = input;
    }

    public async ValueTask<Outcome<InjectionResult>> TryInsertAsync(AttemptId attempt, TargetSnapshot target,
        ClipboardToken clipboardToken, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (target.Attempt != attempt || clipboardToken.Attempt != attempt)
        {
            return Manual(attempt, ErrorCode.TargetChanged);
        }
        if (!OperatingSystem.IsWindows() && input is Win32InputDispatcher)
        {
            return Outcome<InjectionResult>.Failed(attempt, ErrorCode.UnsupportedPlatform);
        }
        var deadline = clock.GetTimestamp().Add(ModifierDeadline);
        while (input.AnyModifierDown)
        {
            if (cancellationToken.IsCancellationRequested) { return Outcome<InjectionResult>.Cancelled(attempt); }
            var now = clock.GetTimestamp();
            if (now.Ticks >= deadline.Ticks) { return Manual(attempt, ErrorCode.ManualPaste); }
            var wait = await clock.DelayUntilAsync(attempt,
                new(Math.Min(deadline.Ticks, now.Add(PollInterval).Ticks)), cancellationToken).ConfigureAwait(false);
            if (!wait.IsSuccess)
            {
                return wait.Kind == OutcomeKind.Cancelled
                    ? Outcome<InjectionResult>.Cancelled(attempt)
                    : Manual(attempt, ErrorCode.ManualPaste);
            }
        }
        var targetCheck = await targets.CheckAsync(attempt, target, cancellationToken).ConfigureAwait(false);
        if (targetCheck.Kind == OutcomeKind.Cancelled) { return Outcome<InjectionResult>.Cancelled(attempt); }
        if (!targetCheck.IsSuccess || targetCheck.Value != TargetCheck.SameTarget)
        {
            return Manual(attempt, targetCheck.Value switch
            {
                TargetCheck.Unsafe => ErrorCode.TargetUnsafe,
                TargetCheck.Changed => ErrorCode.TargetChanged,
                _ => targetCheck.Failure?.Code ?? ErrorCode.TargetUnknown
            });
        }
        var current = await clipboard.IsCurrentAsync(attempt, clipboardToken, cancellationToken).ConfigureAwait(false);
        if (current.Kind == OutcomeKind.Cancelled) { return Outcome<InjectionResult>.Cancelled(attempt); }
        if (!current.IsSuccess || current.Value != true)
        {
            return Manual(attempt, current.Failure?.Code ?? ErrorCode.ClipboardChanged,
                InjectionDisposition.CopyRequired);
        }
        if (cancellationToken.IsCancellationRequested) { return Outcome<InjectionResult>.Cancelled(attempt); }
        var accepted = input.SendPasteBatch();
        if (accepted == 4)
        {
            return Outcome<InjectionResult>.Success(attempt,
                new(InjectionDisposition.Dispatched, ErrorCode.None));
        }
        if (accepted > 0 && !input.ReleaseSyntheticKeys(accepted))
        { return Outcome<InjectionResult>.Failed(attempt, ErrorCode.CleanupFailed); }
        return Manual(attempt, ErrorCode.ManualPaste);
    }

    private static Outcome<InjectionResult> Manual(AttemptId attempt, ErrorCode reason,
        InjectionDisposition disposition = InjectionDisposition.ManualPaste) =>
        Outcome<InjectionResult>.Success(attempt, new(disposition, reason));
}

internal sealed class Win32InputDispatcher : IInputDispatcher
{
    private const uint Keyboard = 1;
    private const uint KeyUp = 0x0002;
    private const ushort Control = 0x11;
    private const ushort V = 0x56;
    private static readonly int[] Modifiers = [0x10, 0x11, 0x12, 0x5b, 0x5c];

    public bool AnyModifierDown => Modifiers.Any(key => Native.GetAsyncKeyState(key) < 0);

    public uint SendPasteBatch()
    {
        Input[] events = [Key(Control, 0), Key(V, 0), Key(V, KeyUp), Key(Control, KeyUp)];
        return Native.SendInput((uint)events.Length, events, Marshal.SizeOf<Input>());
    }

    public bool ReleaseSyntheticKeys(uint acceptedEvents)
    {
        if (acceptedEvents == 0) { return true; }
        var releases = acceptedEvents switch
        {
            1 => new[] { Key(Control, KeyUp) },
            2 => new[] { Key(V, KeyUp), Key(Control, KeyUp) },
            _ => new[] { Key(Control, KeyUp) }
        };
        return Native.SendInput((uint)releases.Length, releases, Marshal.SizeOf<Input>()) == releases.Length;
    }

    private static Input Key(ushort key, uint flags) => new()
    {
        Type = Keyboard,
        Union = new() { Keyboard = new() { VirtualKey = key, Flags = flags } }
    };

    [StructLayout(LayoutKind.Sequential)]
    private struct Input { internal uint Type; internal InputUnion Union; }
    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion { [FieldOffset(0)] internal KeyboardInput Keyboard; }
    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        internal ushort VirtualKey;
        internal ushort ScanCode;
        internal uint Flags;
        internal uint Time;
        internal nuint ExtraInfo;
    }
    private static class Native
    {
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern uint SendInput(uint count, Input[] inputs, int size);
    }
}
