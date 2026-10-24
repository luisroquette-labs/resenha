using System.Runtime.InteropServices;

namespace Resenha.Platform;

// Installed by KeyboardHook on its native message-loop thread. The callback is
// passive: it observes physical button downs and never suppresses mouse input.
internal sealed class MouseActivityMonitor(IUserActivitySink? activity, Func<bool> attemptActive)
{
    private Native.HookProcedure? callback;
    private nint hook;

    internal bool Install(nint instance)
    {
        if (activity is null) { return true; }
        if (hook != 0) { return true; }
        callback ??= OnMouse;
        hook = Native.SetWindowsHookExW(14, callback, instance, 0);
        if (hook != 0) { return true; }
        activity.Observe(UserActivityKind.ObserverLost);
        return false;
    }

    internal bool Remove()
    {
        if (hook == 0) { return true; }
        var current = hook;
        hook = 0;
        if (Native.UnhookWindowsHookEx(current) || Marshal.GetLastPInvokeError() == 1404) { return true; }
        activity?.Observe(UserActivityKind.ObserverLost);
        return false;
    }

    private nint OnMouse(int code, nuint message, nint data)
    {
        if (code >= 0 && attemptActive() && message is 0x0201 or 0x0204 or 0x0207 or 0x020b)
        {
            var input = Marshal.PtrToStructure<Native.MouseHookData>(data);
            if ((input.Flags & 3) == 0) { activity?.Observe(UserActivityKind.Mouse); }
        }
        return Native.CallNextHookEx(hook, code, message, data);
    }

    private static class Native
    {
        [UnmanagedFunctionPointer(CallingConvention.Winapi)] internal delegate nint HookProcedure(int code, nuint message, nint data);
        [StructLayout(LayoutKind.Sequential)] internal struct Point { internal int X, Y; }
        [StructLayout(LayoutKind.Sequential)] internal struct MouseHookData { internal Point Point; internal uint MouseData, Flags, Time; internal nuint ExtraInfo; }
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint SetWindowsHookExW(int id, HookProcedure callback, nint module, uint thread);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnhookWindowsHookEx(nint hook);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint CallNextHookEx(nint hook, int code, nuint message, nint data);
    }
}
