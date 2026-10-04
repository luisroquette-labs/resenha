using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Resenha.Core;

namespace Resenha.Platform;

internal interface IClipboardNative
{
    bool TryCommit(string text, out uint sequenceNumber, out string? readback);
    uint SequenceNumber { get; }
    string? ReadText();
}

public sealed class ClipboardService : IClipboard
{
    internal const int MaximumAttempts = 5;
    internal static readonly TimeSpan TotalBudget = TimeSpan.FromMilliseconds(500);
    private readonly IClipboardNative native;

    public ClipboardService() : this(new Win32Clipboard()) { }
    internal ClipboardService(IClipboardNative native) => this.native = native;

    public async ValueTask<Outcome<ClipboardToken>> CommitAsync(AttemptId attempt, string text,
        CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (OutputPolicy.Normalize(text) != text) { return Outcome<ClipboardToken>.Failed(attempt, ErrorCode.OutputInvalid); }
        if (!OperatingSystem.IsWindows() && native is Win32Clipboard)
        {
            return Outcome<ClipboardToken>.Failed(attempt, ErrorCode.UnsupportedPlatform);
        }

        var completion = new TaskCompletionSource<Outcome<ClipboardToken>>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() => CommitOnSta(attempt, text, cancellationToken, completion))
        {
            IsBackground = true,
            Name = "Resenha clipboard"
        };
        if (OperatingSystem.IsWindows()) { thread.SetApartmentState(ApartmentState.STA); }
        thread.Start();
        return await completion.Task.ConfigureAwait(false);
    }

    public ValueTask<Outcome<bool>> IsCurrentAsync(AttemptId attempt, ClipboardToken token,
        CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (cancellationToken.IsCancellationRequested) { return ValueTask.FromResult(Outcome<bool>.Cancelled(attempt)); }
        if (token.Attempt != attempt) { return ValueTask.FromResult(Outcome<bool>.Failed(attempt, ErrorCode.ClipboardChanged)); }
        try
        {
            var sequence = native.SequenceNumber;
            var current = sequence != 0 && sequence == token.SequenceNumber ? native.ReadText() : null;
            var same = current is not null && native.SequenceNumber == sequence
                && Digest(current) == token.TextSha256;
            return ValueTask.FromResult(Outcome<bool>.Success(attempt, same));
        }
        catch (Exception error) when (error is ExternalException or InvalidOperationException or PlatformNotSupportedException)
        {
            return ValueTask.FromResult(Outcome<bool>.Failed(attempt, ErrorCode.ClipboardBusy));
        }
    }

    private void CommitOnSta(AttemptId attempt, string text, CancellationToken cancellationToken,
        TaskCompletionSource<Outcome<ClipboardToken>> completion)
    {
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        for (var index = 0; index < MaximumAttempts; index++)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                completion.TrySetResult(Outcome<ClipboardToken>.Cancelled(attempt));
                return;
            }
            try
            {
                if (native.TryCommit(text, out var sequence, out var readback)
                    && sequence != 0 && string.Equals(text, readback, StringComparison.Ordinal))
                {
                    completion.TrySetResult(Outcome<ClipboardToken>.Success(attempt,
                        new(attempt, sequence, Digest(text))));
                    return;
                }
            }
            catch (Exception error) when (error is ExternalException or InvalidOperationException or PlatformNotSupportedException)
            {
                // Bounded contention retry below.
            }
            if (index + 1 >= MaximumAttempts || stopwatch.Elapsed >= TotalBudget) { break; }
            Thread.Sleep(Math.Min(25 * (index + 1),
                Math.Max(0, (int)(TotalBudget - stopwatch.Elapsed).TotalMilliseconds)));
        }
        completion.TrySetResult(Outcome<ClipboardToken>.Failed(attempt, ErrorCode.ClipboardBusy));
    }

    private static string Digest(string text) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text)));
}

internal sealed class Win32Clipboard : IClipboardNative
{
    private const uint UnicodeText = 13;
    private const uint Movable = 0x0002;
    public uint SequenceNumber => Native.GetClipboardSequenceNumber();

    public bool TryCommit(string text, out uint sequenceNumber, out string? readback)
    {
        sequenceNumber = 0;
        readback = null;
        var bytes = Encoding.Unicode.GetBytes(text + '\0');
        var allocation = Native.GlobalAlloc(Movable, (nuint)bytes.Length);
        if (allocation == 0) { return false; }
        var ownershipTransferred = false;
        var memory = Native.GlobalLock(allocation);
        if (memory == 0) { Native.GlobalFree(allocation); return false; }
        try { Marshal.Copy(bytes, 0, memory, bytes.Length); }
        finally { Native.GlobalUnlock(allocation); }
        if (!Native.OpenClipboard(0)) { Native.GlobalFree(allocation); return false; }
        try
        {
            if (!Native.EmptyClipboard()) { return false; }
            if (Native.SetClipboardData(UnicodeText, allocation) == 0) { return false; }
            ownershipTransferred = true;
            sequenceNumber = Native.GetClipboardSequenceNumber();
            readback = ReadTextWhileOpen();
            return sequenceNumber != 0 && readback is not null;
        }
        finally
        {
            Native.CloseClipboard();
            if (!ownershipTransferred && allocation != 0) { Native.GlobalFree(allocation); }
        }
    }

    public string? ReadText()
    {
        if (!Native.OpenClipboard(0)) { return null; }
        try { return ReadTextWhileOpen(); }
        finally { Native.CloseClipboard(); }
    }

    private static string? ReadTextWhileOpen()
    {
        var handle = Native.GetClipboardData(UnicodeText);
        if (handle == 0) { return null; }
        var memory = Native.GlobalLock(handle);
        if (memory == 0) { return null; }
        try { return Marshal.PtrToStringUni(memory); }
        finally { Native.GlobalUnlock(handle); }
    }

    private static class Native
    {
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool OpenClipboard(nint owner);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseClipboard();
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool EmptyClipboard();
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint SetClipboardData(uint format, nint memory);
        [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint GetClipboardData(uint format);
        [DllImport("user32.dll", ExactSpelling = true)] internal static extern uint GetClipboardSequenceNumber();
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint GlobalAlloc(uint flags, nuint bytes);
        [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true)] internal static extern nint GlobalLock(nint memory);
        [DllImport("kernel32.dll", ExactSpelling = true)][return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GlobalUnlock(nint memory);
        [DllImport("kernel32.dll", ExactSpelling = true)] internal static extern nint GlobalFree(nint memory);
    }
}
