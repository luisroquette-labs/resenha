using System.Runtime.InteropServices;

namespace Resenha.Platform;

// Shared interop is coordinator-owned. Adapter steps must request additions;
// this initial surface has no hooks, COM activation, clipboard writes or input.
internal static class NativeMethods
{
    [DllImport("user32.dll", ExactSpelling = true)]
    internal static extern nint GetForegroundWindow();

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern uint GetWindowThreadProcessId(nint window, out uint processId);

    [DllImport("user32.dll", ExactSpelling = true)]
    internal static extern uint GetClipboardSequenceNumber();

    [DllImport("kernel32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool QueryPerformanceCounter(out long performanceCount);

    [DllImport("kernel32.dll", ExactSpelling = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool QueryPerformanceFrequency(out long frequency);
}
