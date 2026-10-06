using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Channels;
using Resenha.Core;

namespace Resenha.Platform;

// One dedicated native input thread, one bounded edge queue, one asynchronous
// dispatcher. Edge subscribers must enqueue coordinator work, never await it.
public sealed class KeyboardHook : IShortcutSource, IShortcutAttemptContext, IAsyncDisposable
{
    private const uint CommandMessage = 0x8001;
    private const uint WatchdogMessage = 0x8002;
    private const uint QuitMessage = 0x0012;
    private readonly SemaphoreSlim lifecycle = new(1, 1);
    private readonly IClock clock;
    private readonly IUserActivitySink? activity;
    private Shortcut configured = ShortcutPolicy.Default;
    private InputLoop? loop;
    private int attemptActive;
    private bool disposed;

    public KeyboardHook(IClock clock, IUserActivitySink? activity = null)
    {
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        this.activity = activity;
    }

    public event Action<ShortcutEdge>? Edge;
    public void SetAttemptActive(bool active) => Volatile.Write(ref attemptActive, active ? 1 : 0);

    public async ValueTask<Outcome<Unit>> ConfigureAsync(AttemptId attempt, Shortcut shortcut, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (cancellationToken.IsCancellationRequested) { return Outcome<Unit>.Cancelled(attempt); }
        var validation = ShortcutPolicy.Validate(shortcut);
        if (validation != ErrorCode.None) { return Outcome<Unit>.Failed(attempt, validation); }
        if (!OperatingSystem.IsWindows()) { return Outcome<Unit>.Failed(attempt, ErrorCode.UnsupportedPlatform); }
        try { await lifecycle.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(attempt); }
        try
        {
            if (disposed) { return Outcome<Unit>.Failed(attempt, ErrorCode.NotReady); }
            var error = loop is { } current
                ? await current.ConfigureAsync(shortcut).ConfigureAwait(false)
                : await Task.Run(() => Probe(shortcut), cancellationToken).ConfigureAwait(false);
            if (error != ErrorCode.None) { return Outcome<Unit>.Failed(attempt, error); }
            configured = shortcut;
            return Outcome<Unit>.Success(attempt, default);
        }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(attempt); }
        finally { lifecycle.Release(); }
    }

    public async ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (cancellationToken.IsCancellationRequested) { return Outcome<Unit>.Cancelled(attempt); }
        if (!OperatingSystem.IsWindows()) { return Outcome<Unit>.Failed(attempt, ErrorCode.UnsupportedPlatform); }
        try { await lifecycle.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(attempt); }
        try
        {
            if (disposed) { return Outcome<Unit>.Failed(attempt, ErrorCode.NotReady); }
            if (loop is { } existing)
            {
                return existing.IsRunning ? Outcome<Unit>.Success(attempt, default) : Outcome<Unit>.Failed(attempt, ErrorCode.HookUnavailable);
            }
            var started = new InputLoop(this, configured);
            loop = started;
            var error = await started.StartAsync().ConfigureAwait(false);
            if (error != ErrorCode.None || cancellationToken.IsCancellationRequested)
            {
                await started.StopAsync().ConfigureAwait(false);
                loop = null;
                return cancellationToken.IsCancellationRequested ? Outcome<Unit>.Cancelled(attempt) : Outcome<Unit>.Failed(attempt, error);
            }
            return Outcome<Unit>.Success(attempt, default);
        }
        finally { lifecycle.Release(); }
    }

    public async ValueTask<Outcome<Unit>> StopAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        // Teardown cannot be skipped by an already cancelled dictation token.
        await lifecycle.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (loop is { } current)
            {
                var error = await current.StopAsync().ConfigureAwait(false);
                loop = null;
                if (error != ErrorCode.None) { return Outcome<Unit>.Failed(attempt, error); }
            }
            return Outcome<Unit>.Success(attempt, default);
        }
        finally { lifecycle.Release(); }
    }

    public async ValueTask DisposeAsync()
    {
        await lifecycle.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (disposed) { return; }
            disposed = true;
            if (loop is { } current)
            {
                var error = await current.StopAsync().ConfigureAwait(false);
                loop = null;
                if (error != ErrorCode.None) { throw new InvalidOperationException("Input shutdown requires reopening the application."); }
            }
        }
        finally { lifecycle.Release(); }
    }

    private bool AttemptActive => Volatile.Read(ref attemptActive) != 0;

    internal static bool IsChordComponent(Shortcut shortcut, PhysicalKey key) =>
        key == new PhysicalKey(shortcut.ScanCode, shortcut.IsExtended)
        || (ShortcutPolicy.ModifierFor(key) & shortcut.Modifiers) != 0;

    internal static ShortcutKeySnapshot ResolveSnapshot(ShortcutPolicy policy, bool asynchronousTrigger,
        ShortcutModifiers asynchronousModifiers, bool desktopAvailable) => policy.IsHolding
        ? new(policy.TriggerDown, policy.TrackedModifiers, desktopAvailable)
        : new(asynchronousTrigger, asynchronousModifiers, desktopAvailable);

    private static uint TriggerVirtualKey(Shortcut shortcut)
    {
        uint thread = Native.GetWindowThreadProcessId(Native.GetForegroundWindow(), out _);
        return Native.MapVirtualKeyExW((uint)shortcut.ScanCode | (shortcut.IsExtended ? 0xe000u : 0), 3, Native.GetKeyboardLayout(thread));
    }

    private static ErrorCode Probe(Shortcut shortcut)
    {
        uint virtualKey = TriggerVirtualKey(shortcut);
        if (virtualKey is 0 or 0x7b or 0x5b or 0x5c) { return ErrorCode.ShortcutInvalid; }
        uint modifiers = 0x4000;
        if ((shortcut.Modifiers & (ShortcutModifiers.LeftControl | ShortcutModifiers.RightControl)) != 0) { modifiers |= 2; }
        if ((shortcut.Modifiers & ShortcutModifiers.LeftAlt) != 0) { modifiers |= 1; }
        if ((shortcut.Modifiers & (ShortcutModifiers.LeftShift | ShortcutModifiers.RightShift)) != 0) { modifiers |= 4; }
        // Registration exists only for this synchronous conflict probe. No
        // WM_HOTKEY message is consumed as an input edge, even if queued here.
        if (!Native.RegisterHotKey(0, 0x5245, modifiers, virtualKey))
        {
            return Marshal.GetLastPInvokeError() == 1409 ? ErrorCode.ShortcutOccupied : ErrorCode.HookUnavailable;
        }
        return Native.UnregisterHotKey(0, 0x5245) ? ErrorCode.None : ErrorCode.HookUnavailable;
    }

    private sealed class InputLoop
    {
        private readonly KeyboardHook owner;
        private readonly Channel<ShortcutEdge> edges = Channel.CreateBounded<ShortcutEdge>(new BoundedChannelOptions(64)
        {
            SingleReader = true,
            SingleWriter = true,
            FullMode = BoundedChannelFullMode.Wait,
            AllowSynchronousContinuations = false
        });
        private readonly TaskCompletionSource<ErrorCode> ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource stopped = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly Native.HookProcedure hookProcedure;
        private readonly Native.WindowProcedure windowProcedure;
        private readonly MouseActivityMonitor mouse;
        private readonly string className = "ResenhaInput_" + Guid.NewGuid().ToString("N");
        private ShortcutPolicy policy;
        private Task dispatch = Task.CompletedTask;
        private Action? command;
        private uint threadId;
        private nint hook;
        private nint window;
        private nint instance;
        private nint powerNotification;
        private ushort windowClass;
        private bool sessionNotifications;
        private bool suspended;
        private bool recovering;
        private bool faulted;
        private int running;
        private int overflow;
        private int watchdogPending;
        private string? desktopName;

        public InputLoop(KeyboardHook owner, Shortcut shortcut)
        {
            this.owner = owner;
            policy = new(shortcut);
            hookProcedure = OnKeyboard;
            windowProcedure = OnWindow;
            mouse = new(owner.activity, () => owner.AttemptActive);
        }

        public bool IsRunning => Volatile.Read(ref running) != 0 && Volatile.Read(ref overflow) == 0;

        public Task<ErrorCode> StartAsync()
        {
            dispatch = Task.Run(DispatchAsync);
            var thread = new Thread(Run) { IsBackground = true, Name = "Resenha keyboard input" };
            thread.Start();
            return ready.Task;
        }

        public async Task<ErrorCode> StopAsync()
        {
            if (!stopped.Task.IsCompleted && threadId != 0)
            {
                if (!Native.PostThreadMessageW(threadId, QuitMessage, 0, 0)) { throw new InvalidOperationException("Input shutdown message failed."); }
            }
            await stopped.Task.ConfigureAwait(false);
            await dispatch.ConfigureAwait(false);
            return faulted ? ErrorCode.HookUnavailable : ErrorCode.None;
        }

        public async Task<ErrorCode> ConfigureAsync(Shortcut shortcut)
        {
            if (!IsRunning) { return ErrorCode.HookUnavailable; }
            var completed = new TaskCompletionSource<ErrorCode>(TaskCreationOptions.RunContinuationsAsynchronously);
            command = () =>
            {
                if (!policy.AllChordKeysUp || owner.AttemptActive) { completed.TrySetResult(ErrorCode.Busy); return; }
                var error = Probe(shortcut);
                if (error == ErrorCode.None)
                {
                    policy = new(shortcut);
                    policy.Watchdog(Snapshot(), owner.clock.GetTimestamp());
                }
                completed.TrySetResult(error);
            };
            if (!Native.PostThreadMessageW(threadId, CommandMessage, 0, 0)) { command = null; return ErrorCode.HookUnavailable; }
            var winner = await Task.WhenAny(completed.Task, stopped.Task).ConfigureAwait(false);
            return winner == completed.Task ? await completed.Task.ConfigureAwait(false) : ErrorCode.HookUnavailable;
        }

        private void Run()
        {
            Timer? timer = null;
            try
            {
                Native.PeekMessageW(out _, 0, 0, 0, 0);
                threadId = Native.GetCurrentThreadId();
                instance = Native.GetModuleHandleW(null);
                desktopName = DesktopName(Native.GetThreadDesktop(threadId));
                var error = Probe(policy.Shortcut);
                if (error != ErrorCode.None) { ready.TrySetResult(error); return; }
                var definition = new Native.WindowClass { Procedure = windowProcedure, Instance = instance, ClassName = className };
                windowClass = Native.RegisterClassW(ref definition);
                if (windowClass == 0) { ready.TrySetResult(ErrorCode.HookUnavailable); return; }
                // Hidden top-level window receives suspend/session notifications;
                // message-only windows do not receive all broadcast messages.
                window = Native.CreateWindowExW(0x08000000, className, "", 0, 0, 0, 0, 0, 0, 0, instance, 0);
                if (window == 0) { ready.TrySetResult(ErrorCode.HookUnavailable); return; }
                sessionNotifications = Native.WTSRegisterSessionNotification(window, 0);
                powerNotification = Native.RegisterSuspendResumeNotification(window, 0);
                if (!sessionNotifications || powerNotification == 0 || desktopName is null)
                { ready.TrySetResult(ErrorCode.HookUnavailable); return; }
                var snapshot = Snapshot();
                policy.Watchdog(snapshot, owner.clock.GetTimestamp());
                if (!snapshot.DesktopAvailable || !InstallHook()) { ready.TrySetResult(ErrorCode.HookUnavailable); return; }
                timer = new Timer(_ =>
                {
                    if (Interlocked.Exchange(ref watchdogPending, 1) == 0)
                    {
                        Native.PostThreadMessageW(threadId, WatchdogMessage, 0, 0);
                    }
                }, null, ShortcutPolicy.WatchdogInterval, ShortcutPolicy.WatchdogInterval);
                Volatile.Write(ref running, 1);
                ready.TrySetResult(ErrorCode.None);
                int result;
                while ((result = Native.GetMessageW(out var message, 0, 0, 0)) > 0)
                {
                    if (message.Message == WatchdogMessage) { Interlocked.Exchange(ref watchdogPending, 0); Watchdog(); }
                    else if (message.Message == CommandMessage) { Interlocked.Exchange(ref command, null)?.Invoke(); }
                    else { Native.TranslateMessage(in message); Native.DispatchMessageW(in message); }
                }
                if (result < 0) { faulted = true; }
            }
            catch (Exception)
            {
                // No exception is allowed to leave this owned native thread.
                faulted = true;
                ready.TrySetResult(ErrorCode.HookUnavailable);
            }
            finally
            {
                Volatile.Write(ref running, 0);
                timer?.Dispose();
                // A press/release may still be queued while the coordinator has
                // not marked the attempt active. Terminate that pending work too.
                Emit(policy.Shutdown(owner.clock.GetTimestamp(), attemptActive: true));
                RemoveHook();
                if (powerNotification != 0) { Native.UnregisterSuspendResumeNotification(powerNotification); }
                if (sessionNotifications) { Native.WTSUnRegisterSessionNotification(window); }
                if (window != 0) { Native.DestroyWindow(window); }
                if (windowClass != 0) { Native.UnregisterClassW(className, instance); }
                edges.Writer.TryComplete();
                ready.TrySetResult(ErrorCode.HookUnavailable);
                stopped.TrySetResult();
                GC.KeepAlive(hookProcedure);
                GC.KeepAlive(windowProcedure);
            }
        }

        private nint OnKeyboard(int code, nuint message, nint data)
        {
            if (code < 0) { return Native.CallNextHookEx(hook, code, message, data); }
            if (message is not (0x0100 or 0x0101 or 0x0104 or 0x0105)) { return Native.CallNextHookEx(hook, code, message, data); }
            var key = Marshal.PtrToStructure<Native.KeyboardHookData>(data);
            // LLKHF_INJECTED and LLKHF_LOWER_IL_INJECTED must never mutate state.
            if ((key.Flags & 0x12) != 0) { return Native.CallNextHookEx(hook, code, message, data); }
            var physical = new PhysicalKey((ushort)key.ScanCode, (key.Flags & 1) != 0);
            var decision = policy.Process(new(physical, message is 0x0100 or 0x0104), owner.clock.GetTimestamp(), owner.AttemptActive);
            if (owner.AttemptActive && message is 0x0100 or 0x0104 && decision.Edge is null
                && !IsChordComponent(policy.Shortcut, physical))
            {
                owner.activity?.Observe(UserActivityKind.Keyboard);
            }
            Emit(decision.Edge);
            return decision.Suppress ? 1 : Native.CallNextHookEx(hook, code, message, data);
        }

        private nint OnWindow(nint handle, uint message, nuint wParam, nint lParam)
        {
            if ((message == 0x02b1 && wParam is 6 or 7) || (message == 0x0218 && wParam == 4))
            {
                suspended = true;
                Interrupt();
            }
            else if ((message == 0x02b1 && wParam is 5 or 8) || (message == 0x0218 && wParam is 7 or 18))
            {
                suspended = false;
                recovering = true;
            }
            return Native.DefWindowProcW(handle, message, wParam, lParam);
        }

        private void Watchdog()
        {
            if (faulted || Volatile.Read(ref overflow) != 0) { Volatile.Write(ref running, 0); Interrupt(); return; }
            var snapshot = Snapshot();
            var now = owner.clock.GetTimestamp();
            if (!snapshot.DesktopAvailable) { Interrupt(); return; }
            if (suspended) { return; }
            if (recovering)
            {
                if (policy.Resume(snapshot, now))
                {
                    if (!InstallHook()) { faulted = true; Volatile.Write(ref running, 0); Emit(new(ShortcutEdgeKind.Interrupted, now)); }
                    else { recovering = false; }
                }
                return;
            }
            Emit(policy.Watchdog(snapshot, now));
        }

        private void Interrupt()
        {
            // Always enqueue this boundary, even if a queued press has not yet
            // reached the coordinator's activity flag.
            if (!recovering) { Emit(policy.Suspend(owner.clock.GetTimestamp(), attemptActive: true)); }
            recovering = true;
            RemoveHook();
        }

        private bool InstallHook()
        {
            hook = Native.SetWindowsHookExW(13, hookProcedure, instance, 0);
            if (hook == 0) { return false; }
            if (mouse.Install(instance)) { return true; }
            Native.UnhookWindowsHookEx(hook);
            hook = 0;
            return false;
        }

        private void RemoveHook()
        {
            if (!mouse.Remove()) { faulted = true; }
            if (hook == 0) { return; }
            if (!Native.UnhookWindowsHookEx(hook) && Marshal.GetLastPInvokeError() != 1404)
            {
                faulted = true;
                return;
            }
            hook = 0;
        }

        private ShortcutKeySnapshot Snapshot()
        {
            nint desktop = Native.OpenInputDesktop(0, false, 1);
            bool available = false;
            if (desktop != 0)
            {
                try { available = desktopName is not null && DesktopName(desktop) == desktopName; }
                finally { Native.CloseDesktop(desktop); }
            }
            var modifiers = ShortcutModifiers.None;
            foreach (var entry in ShortcutPolicy.ModifierKeys)
            {
                if (Native.GetAsyncKeyState(entry.VirtualKey) < 0) { modifiers |= entry.Modifier; }
            }
            uint virtualKey = TriggerVirtualKey(policy.Shortcut);
            bool asynchronousTrigger = virtualKey != 0 && Native.GetAsyncKeyState((int)virtualKey) < 0;
            return ResolveSnapshot(policy, asynchronousTrigger, modifiers, available && virtualKey != 0);
        }

        private static string? DesktopName(nint desktop)
        {
            var name = new StringBuilder(256);
            return desktop != 0 && Native.GetUserObjectInformationW(desktop, 2, name, 512, out _) ? name.ToString() : null;
        }

        private void Emit(ShortcutEdge? edge)
        {
            if (edge is null) { return; }
            if (!edges.Writer.TryWrite(edge))
            {
                // Never drop a release and continue recording. The dispatcher
                // replaces pending edges with cancellation and input fails closed.
                Volatile.Write(ref overflow, 1);
                policy.Suspend(edge.At);
            }
        }

        private async Task DispatchAsync()
        {
            bool overflowReported = false;
            await foreach (var edge in edges.Reader.ReadAllAsync().ConfigureAwait(false))
            {
                if (Volatile.Read(ref overflow) != 0)
                {
                    while (edges.Reader.TryRead(out _)) { }
                    if (!overflowReported)
                    {
                        overflowReported = true;
                        owner.Edge?.Invoke(new(ShortcutEdgeKind.Interrupted, owner.clock.GetTimestamp()));
                    }
                }
                else { owner.Edge?.Invoke(edge); }
            }
        }
    }

    // Step-owned declarations were approved by the phase integration owner.
    // No shared NativeMethods edits are necessary for the keyboard subsystem.
    private static class Native
    {
        [UnmanagedFunctionPointer(CallingConvention.Winapi)] internal delegate nint HookProcedure(int code, nuint message, nint data);
        [UnmanagedFunctionPointer(CallingConvention.Winapi)] internal delegate nint WindowProcedure(nint window, uint message, nuint wParam, nint lParam);
        [StructLayout(LayoutKind.Sequential)] internal struct KeyboardHookData { internal uint VirtualKey, ScanCode, Flags, Time; internal nuint ExtraInfo; }
        [StructLayout(LayoutKind.Sequential)] internal struct NativeMessage { internal nint Window; internal uint Message; internal nuint WParam; internal nint LParam; internal uint Time; internal int X, Y; internal uint Private; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct WindowClass
        {
            internal uint Style; internal WindowProcedure Procedure; internal int ClassExtra, WindowExtra;
            internal nint Instance, Icon, Cursor, Background;
            [MarshalAs(UnmanagedType.LPWStr)] internal string? MenuName;
            [MarshalAs(UnmanagedType.LPWStr)] internal string ClassName;
        }
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint SetWindowsHookExW(int id, HookProcedure callback, nint module, uint thread);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnhookWindowsHookEx(nint hook);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint CallNextHookEx(nint hook, int code, nuint message, nint data);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetForegroundWindow();
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern uint GetWindowThreadProcessId(nint window, out uint process);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetKeyboardLayout(uint thread);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern uint MapVirtualKeyExW(uint code, uint map, nint layout);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool RegisterHotKey(nint window, int id, uint modifiers, uint key);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnregisterHotKey(nint window, int id);
        [DllImport("kernel32.dll", ExactSpelling = true, CharSet = CharSet.Unicode)] internal static extern nint GetModuleHandleW(string? name);
        [DllImport("kernel32.dll", ExactSpelling = true)] internal static extern uint GetCurrentThreadId();
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PostThreadMessageW(uint thread, uint message, nuint wParam, nint lParam);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)] internal static extern int GetMessageW(out NativeMessage message, nint window, uint min, uint max);
        [DllImport("user32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PeekMessageW(out NativeMessage message, nint window, uint min, uint max, uint remove);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint DispatchMessageW(in NativeMessage message);
        [DllImport("user32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool TranslateMessage(in NativeMessage message);
        [DllImport("user32.dll", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true)] internal static extern ushort RegisterClassW(ref WindowClass definition);
        [DllImport("user32.dll", ExactSpelling = true, CharSet = CharSet.Unicode)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnregisterClassW(string name, nint instance);
        [DllImport("user32.dll", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true)] internal static extern nint CreateWindowExW(uint extendedStyle, string className, string name, uint style, int x, int y, int width, int height, nint parent, nint menu, nint instance, nint parameter);
        [DllImport("user32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool DestroyWindow(nint window);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint DefWindowProcW(nint window, uint message, nuint wParam, nint lParam);
        [DllImport("wtsapi32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool WTSRegisterSessionNotification(nint window, uint flags);
        [DllImport("wtsapi32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool WTSUnRegisterSessionNotification(nint window);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint RegisterSuspendResumeNotification(nint recipient, uint flags);
        [DllImport("user32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnregisterSuspendResumeNotification(nint handle);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint OpenInputDesktop(uint flags, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint access);
        [DllImport("user32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool CloseDesktop(nint desktop);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetThreadDesktop(uint thread);
        [DllImport("user32.dll", ExactSpelling = true, CharSet = CharSet.Unicode)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetUserObjectInformationW(nint handle, int index, StringBuilder value, uint length, out uint needed);
    }
}
