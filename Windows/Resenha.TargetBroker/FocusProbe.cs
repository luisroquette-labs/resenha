using System.Collections.Immutable;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Automation;
using System.Windows.Automation.Text;
using Resenha.Core;

namespace Resenha.TargetBroker;

internal static class FocusProbe
{
    internal static TargetBrokerResponse Capture(Guid attempt, string nonce)
    {
        var foreground = Native.GetForegroundWindow();
        if (foreground == 0) { return Empty(attempt, nonce, "unknown"); }
        Native.GetWindowThreadProcessId(foreground, out var foregroundPid);
        try
        {
            var focused = AutomationElement.FocusedElement;
            if (focused is null) { return Empty(attempt, nonce, "unknown"); }
            var processId = checked((uint)focused.Current.ProcessId);
            if (processId == 0 || processId != foregroundPid) { return Empty(attempt, nonce, "changed"); }
            var child = checked((ulong)(long)focused.Current.NativeWindowHandle);
            var runtime = focused.GetRuntimeId()?.ToImmutableArray() ?? [];
            var controlType = focused.Current.ControlType?.Id ?? 0;
            var isPassword = focused.Current.IsPassword;
            var editable = false;
            var readOnly = true;
            var hasSelection = false;
            var hasCaret = false;
            var caretGeometry = "";
            if (focused.TryGetCurrentPattern(ValuePattern.Pattern, out var valueObject) && valueObject is ValuePattern value)
            {
                readOnly = value.Current.IsReadOnly;
                editable = !readOnly;
            }
            if (focused.TryGetCurrentPattern(TextPattern.Pattern, out var textObject) && textObject is TextPattern text)
            {
                editable = focused.Current.IsEnabled && focused.Current.IsKeyboardFocusable
                    && controlType is 50004 or 50030; // UIA Edit or Document.
                readOnly = !editable;
                var ranges = text.GetSelection();
                hasCaret = ranges.Length > 0;
                hasSelection = ranges.Any(range => range.CompareEndpoints(
                    TextPatternRangeEndpoint.Start, range, TextPatternRangeEndpoint.End) != 0);
                caretGeometry = string.Join(';', ranges.SelectMany(range => range.GetBoundingRectangles())
                    .Select(value => Convert.ToDouble(value, System.Globalization.CultureInfo.InvariantCulture)
                        .ToString("R", System.Globalization.CultureInfo.InvariantCulture)));
            }
            var root = Native.GetAncestor(foreground, 2);
            var identity = SelectionToken(runtime, controlType, child, hasSelection, caretGeometry);
            return new(1, nonce, attempt, checked((uint)Environment.ProcessId), checked((ulong)(long)foreground),
                checked((ulong)(long)root), child, processId, ProcessCreation(processId), Session(processId),
                Desktop(foreground), Integrity(processId), runtime, controlType, isPassword, editable,
                readOnly, identity, hasCaret, hasSelection, "ok");
        }
        catch (Exception error) when (error is ElementNotAvailableException or InvalidOperationException
            or UnauthorizedAccessException or System.ComponentModel.Win32Exception)
        {
            return Empty(attempt, nonce, "unsafe");
        }
    }

    private static TargetBrokerResponse Empty(Guid attempt, string nonce, string status) =>
        new(1, nonce, attempt, checked((uint)Environment.ProcessId), 0, 0, 0, 0, 0, 0, "",
            TargetIntegrity.Unknown, [], 0, false, false, true, null, false, false, status);

    private static string SelectionToken(ImmutableArray<int> runtime, int controlType, ulong window,
        bool selection, string caretGeometry)
    {
        var value = string.Join(',', runtime) + $"|{controlType}|{window}|{selection}|{caretGeometry}";
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    }

    private static long ProcessCreation(uint processId)
    {
        using var process = Process.GetProcessById(checked((int)processId));
        return process.StartTime.ToFileTimeUtc();
    }

    private static uint Session(uint processId) => Native.ProcessIdToSessionId(processId, out var session) ? session : uint.MaxValue;

    private static string Desktop(nint window)
    {
        var thread = Native.GetWindowThreadProcessId(window, out _);
        var desktop = Native.GetThreadDesktop(thread);
        var value = new StringBuilder(256);
        return desktop != 0 && Native.GetUserObjectInformationW(desktop, 2, value, 512, out _) ? value.ToString() : "";
    }

    private static TargetIntegrity Integrity(uint processId)
    {
        using var process = Native.OpenProcess(0x1000, false, processId);
        if (process.IsInvalid || !Native.OpenProcessToken(process, 0x0008, out var token)) { return TargetIntegrity.Unknown; }
        using (token)
        {
            Native.GetTokenInformation(token, 25, 0, 0, out var length);
            if (length == 0) { return TargetIntegrity.Unknown; }
            var buffer = Marshal.AllocHGlobal(checked((int)length));
            try
            {
                if (!Native.GetTokenInformation(token, 25, buffer, length, out _)) { return TargetIntegrity.Unknown; }
                var sid = Marshal.ReadIntPtr(buffer);
                var count = Marshal.ReadByte(Native.GetSidSubAuthorityCount(sid));
                if (count == 0) { return TargetIntegrity.Unknown; }
                var rid = unchecked((uint)Marshal.ReadInt32(Native.GetSidSubAuthority(sid, (uint)(count - 1))));
                return rid < 0x1000 ? TargetIntegrity.Low : rid < 0x3000 ? TargetIntegrity.Medium
                    : rid < 0x4000 ? TargetIntegrity.High : TargetIntegrity.System;
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }
    }

    private static class Native
    {
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetForegroundWindow();
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern uint GetWindowThreadProcessId(nint window, out uint process);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetAncestor(nint window, uint flags);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern nint GetThreadDesktop(uint thread);
        [DllImport("user32.dll", ExactSpelling = true, CharSet = CharSet.Unicode)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetUserObjectInformationW(nint handle, int index, StringBuilder value, uint length, out uint needed);
        [DllImport("kernel32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool ProcessIdToSessionId(uint process, out uint session);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)] internal static extern Microsoft.Win32.SafeHandles.SafeProcessHandle OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint process);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool OpenProcessToken(Microsoft.Win32.SafeHandles.SafeProcessHandle process, uint access, out Microsoft.Win32.SafeHandles.SafeAccessTokenHandle token);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetTokenInformation(Microsoft.Win32.SafeHandles.SafeAccessTokenHandle token, int kind, nint information, uint length, out uint returned);
        [DllImport("advapi32.dll", ExactSpelling = true)] internal static extern nint GetSidSubAuthorityCount(nint sid);
        [DllImport("advapi32.dll", ExactSpelling = true)] internal static extern nint GetSidSubAuthority(nint sid, uint index);
    }
}
