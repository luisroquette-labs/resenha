using System.Collections.Immutable;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Resenha.Platform;

public sealed record ChildProcessSpec(string ExecutablePath, string WorkingDirectory, ImmutableArray<string> Arguments);
public enum ChildProcessExit { Exited, Cancelled, TimedOut }
// A returned result always certifies that the process AND its job are empty.
public sealed record ChildProcessResult(ChildProcessExit Outcome, int ExitCode);
public interface IChildProcessJob
{
    IChildProcessHandle Start(ChildProcessSpec specification);
}
public interface IChildProcessHandle : IAsyncDisposable
{
    uint ProcessId { get; }
    ValueTask<ChildProcessResult> WaitForExitAsync(TimeSpan timeout, CancellationToken cancellationToken);
    ValueTask TerminateAsync();
}

// Never convert this into an ordinary retryable inference error: the caller
// must retain all leases and stop the application if termination is unconfirmed.
public sealed class ChildProcessTerminationException() : Exception("Child process termination was not confirmed; retain owned files and reopen the application.");

public sealed class ChildProcessJob : IChildProcessJob
{
    public static readonly TimeSpan TerminationTimeout = TimeSpan.FromSeconds(2);

    public IChildProcessHandle Start(ChildProcessSpec specification)
    {
        ArgumentNullException.ThrowIfNull(specification);
        if (!OperatingSystem.IsWindows()) { throw new PlatformNotSupportedException(); }
        if (!Path.IsPathFullyQualified(specification.ExecutablePath) || !Path.IsPathFullyQualified(specification.WorkingDirectory)
            || !File.Exists(specification.ExecutablePath) || !Directory.Exists(specification.WorkingDirectory))
        {
            throw new ArgumentException("A child requires an existing absolute executable and working directory.", nameof(specification));
        }
        var commandLine = new StringBuilder(BuildCommandLine(specification));
        var job = Native.CreateJobObjectW(0, null);
        if (job.IsInvalid) { job.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error()); }
        SafeKernelHandle? process = null;
        SafeKernelHandle? thread = null;
        try
        {
            var limits = new Native.ExtendedLimits { Basic = new() { LimitFlags = 0x2000 } }; // KILL_ON_JOB_CLOSE
            if (!Native.SetInformationJobObject(job, 9, ref limits, (uint)Marshal.SizeOf<Native.ExtendedLimits>())) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            using var nullIo = Native.OpenNull();
            using var attributes = new Native.HandleAttributes(nullIo);
            var startup = new Native.StartupInfoEx
            {
                StartupInfo = new()
                {
                    Size = Marshal.SizeOf<Native.StartupInfoEx>(),
                    Flags = 0x100,
                    StandardInput = nullIo.DangerousGetHandle(),
                    StandardOutput = nullIo.DangerousGetHandle(),
                    StandardError = nullIo.DangerousGetHandle()
                },
                AttributeList = attributes.Pointer
            };
            // CREATE_SUSPENDED prevents any code/descendant from escaping before
            // job assignment; EXTENDED_STARTUPINFO limits inheritance to NUL.
            if (!Native.CreateProcessW(specification.ExecutablePath, commandLine, 0, 0, true,
                0x4 | 0x80000 | 0x08000000, 0, specification.WorkingDirectory, ref startup, out var info))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            process = new(info.Process);
            thread = new(info.Thread);
            if (!Native.AssignProcessToJobObject(job, process)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            if (Native.ResumeThread(thread) == uint.MaxValue) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
            return new RunningChild(job, process, info.ProcessId);
        }
        catch
        {
            var confirmed = true;
            if (process is not null)
            {
                Native.TerminateJobObject(job, 1);
                Native.TerminateProcess(process, 1);
                confirmed = Native.WaitForSingleObject(process, 2000) == 0;
            }
            process?.Dispose();
            job.Dispose();
            if (!confirmed) { throw new ChildProcessTerminationException(); }
            throw;
        }
        finally { thread?.Dispose(); }
    }

    // Win32 has a command-line string API, so serialize the argument list with
    // the MSVC argv quoting rules. No shell or PATH lookup is involved.
    public static string BuildCommandLine(ChildProcessSpec specification)
    {
        if (specification.Arguments.IsDefault) { throw new ArgumentException("An argument list is required.", nameof(specification)); }
        var value = string.Join(" ", specification.Arguments.Prepend(specification.ExecutablePath).Select(QuoteArgument));
        if (value.Length >= 32767) { throw new ArgumentException("The Windows command line is too long.", nameof(specification)); }
        return value;
    }

    private static string QuoteArgument(string value)
    {
        if (value is null || value.Contains('\0')) { throw new ArgumentException("Invalid process argument.", nameof(value)); }
        var result = new StringBuilder("\"");
        var slashes = 0;
        foreach (var character in value)
        {
            if (character == '\\') { slashes++; continue; }
            result.Append('\\', character == '"' ? slashes * 2 + 1 : slashes);
            result.Append(character);
            slashes = 0;
        }
        return result.Append('\\', slashes * 2).Append('"').ToString();
    }

    private sealed class RunningChild(SafeKernelHandle job, SafeKernelHandle process, uint processId) : IChildProcessHandle
    {
        public uint ProcessId { get; } = processId;
        private readonly object sync = new();
        private readonly CancellationTokenSource stop = new();
        private Task<ChildProcessResult>? completion;
        private Task? disposal;

        public ValueTask<ChildProcessResult> WaitForExitAsync(TimeSpan timeout, CancellationToken cancellationToken)
        {
            if (timeout < TimeSpan.Zero) { throw new ArgumentOutOfRangeException(nameof(timeout)); }
            lock (sync)
            {
                ObjectDisposedException.ThrowIf(disposal is not null, this);
                completion ??= RunWaitAsync(timeout, cancellationToken);
                return new(completion);
            }
        }

        public async ValueTask TerminateAsync()
        {
            Task<ChildProcessResult> pending;
            lock (sync)
            {
                if (disposal is not null) { pending = completion!; }
                else { stop.Cancel(); pending = completion ??= RunWaitAsync(TimeSpan.Zero, CancellationToken.None); }
            }
            await pending.ConfigureAwait(false);
        }

        private async Task<ChildProcessResult> RunWaitAsync(TimeSpan timeout, CancellationToken cancellationToken)
        {
            using var cancelled = CancellationTokenSource.CreateLinkedTokenSource(stop.Token, cancellationToken);
            var timer = Stopwatch.StartNew();
            var outcome = ChildProcessExit.Exited;
            while (Native.WaitForSingleObject(process, 0) != 0)
            {
                if (cancelled.IsCancellationRequested) { outcome = ChildProcessExit.Cancelled; break; }
                if (timer.Elapsed >= timeout) { outcome = ChildProcessExit.TimedOut; break; }
                await Task.Delay(10, CancellationToken.None).ConfigureAwait(false);
            }
            // Even a normal parent exit must reap any descendants before callers
            // read output or release leases. No cancellation interrupts cleanup.
            if (!Native.TerminateJobObject(job, 1)) { throw new ChildProcessTerminationException(); }
            timer.Restart();
            while (true)
            {
                if (!Native.QueryInformationJobObject(job, 1, out var accounting, (uint)Marshal.SizeOf<Native.Accounting>(), 0)) { throw new ChildProcessTerminationException(); }
                if (accounting.ActiveProcesses == 0 && Native.WaitForSingleObject(process, 0) == 0) { break; }
                if (timer.Elapsed >= TerminationTimeout) { throw new ChildProcessTerminationException(); }
                await Task.Delay(10, CancellationToken.None).ConfigureAwait(false);
            }
            if (!Native.GetExitCodeProcess(process, out var exitCode)) { throw new ChildProcessTerminationException(); }
            return new(outcome, unchecked((int)exitCode));
        }

        public ValueTask DisposeAsync()
        {
            lock (sync) { return new(disposal ??= DisposeOnceAsync()); }
        }

        private async Task DisposeOnceAsync()
        {
            stop.Cancel();
            completion ??= RunWaitAsync(TimeSpan.Zero, CancellationToken.None);
            try { await completion.ConfigureAwait(false); }
            finally { job.Dispose(); process.Dispose(); stop.Dispose(); }
        }
    }

    private sealed class SafeKernelHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeKernelHandle() : base(true) { }
        public SafeKernelHandle(nint value) : base(true) => SetHandle(value);
        protected override bool ReleaseHandle() => Native.CloseHandle(handle);
    }

    private static class Native
    {
        [StructLayout(LayoutKind.Sequential)] internal struct BasicLimits { public long PerProcessTime, PerJobTime; public uint LimitFlags; public nuint MinimumWorkingSet, MaximumWorkingSet; public uint ActiveProcessLimit; public nuint Affinity; public uint PriorityClass, SchedulingClass; }
        [StructLayout(LayoutKind.Sequential)] internal struct IoCounters { public ulong ReadOperations, WriteOperations, OtherOperations, ReadBytes, WriteBytes, OtherBytes; }
        [StructLayout(LayoutKind.Sequential)] internal struct ExtendedLimits { public BasicLimits Basic; public IoCounters Io; public nuint ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory; }
        [StructLayout(LayoutKind.Sequential)] internal struct Accounting { public long UserTime, KernelTime, PeriodUserTime, PeriodKernelTime; public uint PageFaults, TotalProcesses, ActiveProcesses, TerminatedProcesses; }
        [StructLayout(LayoutKind.Sequential)] internal struct StartupInfo { public int Size; public nint Reserved, Desktop, Title; public uint X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags; public ushort ShowWindow, ReservedBytes; public nint ReservedPointer, StandardInput, StandardOutput, StandardError; }
        [StructLayout(LayoutKind.Sequential)] internal struct StartupInfoEx { public StartupInfo StartupInfo; public nint AttributeList; }
        [StructLayout(LayoutKind.Sequential)] internal struct ProcessInformation { public nint Process, Thread; public uint ProcessId, ThreadId; }
        [StructLayout(LayoutKind.Sequential)] internal struct SecurityAttributes { public int Length; public nint Descriptor; [MarshalAs(UnmanagedType.Bool)] public bool Inherit; }

        // The sink consumes stdout/stderr immediately with zero retained bytes.
        internal static SafeKernelHandle OpenNull()
        {
            var security = new SecurityAttributes { Length = Marshal.SizeOf<SecurityAttributes>(), Inherit = true };
            var handle = CreateFileW("NUL", 0xC0000000, 3, ref security, 3, 0, 0);
            if (handle.IsInvalid) { handle.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error()); }
            return handle;
        }

        internal sealed class HandleAttributes : IDisposable
        {
            public nint Pointer { get; private set; }
            private nint handles;
            private bool initialized;
            public HandleAttributes(SafeKernelHandle inherited)
            {
                nuint size = 0;
                InitializeProcThreadAttributeList(0, 1, 0, ref size);
                Pointer = Marshal.AllocHGlobal(checked((int)size));
                try
                {
                    if (!InitializeProcThreadAttributeList(Pointer, 1, 0, ref size)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
                    initialized = true;
                    handles = Marshal.AllocHGlobal(nint.Size);
                    Marshal.WriteIntPtr(handles, inherited.DangerousGetHandle());
                    if (!UpdateProcThreadAttribute(Pointer, 0, 0x20002, handles, (nuint)nint.Size, 0, 0)) { throw new Win32Exception(Marshal.GetLastWin32Error()); }
                }
                catch { Dispose(); throw; }
            }
            public void Dispose()
            {
                if (initialized) { DeleteProcThreadAttributeList(Pointer); initialized = false; }
                if (Pointer != 0) { Marshal.FreeHGlobal(Pointer); Pointer = 0; }
                if (handles != 0) { Marshal.FreeHGlobal(handles); handles = 0; }
            }
        }

        [DllImport("kernel32.dll", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true)] internal static extern SafeKernelHandle CreateJobObjectW(nint attributes, string? name);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool SetInformationJobObject(SafeKernelHandle job, int kind, ref ExtendedLimits limits, uint length);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool QueryInformationJobObject(SafeKernelHandle job, int kind, out Accounting information, uint length, nint returnLength);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool AssignProcessToJobObject(SafeKernelHandle job, SafeKernelHandle process);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool TerminateJobObject(SafeKernelHandle job, uint code);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool TerminateProcess(SafeKernelHandle process, uint code);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)] internal static extern uint WaitForSingleObject(SafeKernelHandle handle, uint milliseconds);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)] internal static extern uint ResumeThread(SafeKernelHandle thread);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetExitCodeProcess(SafeKernelHandle process, out uint code);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool CloseHandle(nint handle);
        [DllImport("kernel32.dll", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool CreateProcessW(string executable, StringBuilder commandLine, nint processAttributes, nint threadAttributes, [MarshalAs(UnmanagedType.Bool)] bool inheritHandles, uint flags, nint environment, string workingDirectory, ref StartupInfoEx startup, out ProcessInformation information);
        [DllImport("kernel32.dll", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true)] internal static extern SafeKernelHandle CreateFileW(string path, uint access, uint share, ref SecurityAttributes security, uint creation, uint flags, nint template);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool InitializeProcThreadAttributeList(nint list, int count, int flags, ref nuint size);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UpdateProcThreadAttribute(nint list, uint flags, nuint attribute, nint value, nuint size, nint previous, nint returnSize);
        [DllImport("kernel32.dll", ExactSpelling = true)] internal static extern void DeleteProcThreadAttributeList(nint list);
    }
}
