using System.Runtime.InteropServices;
using System.Runtime.Intrinsics.X86;
using Resenha.Core;

namespace Resenha.Platform;

public sealed record ReadinessReport(bool IsReady, IReadOnlyList<ErrorCode> Failures);

public static class PlatformReadiness
{
    public const long MinimumMemoryBytes = 8L * 1024 * 1024 * 1024;
    public const long MinimumFreeStorageBytes = 1024L * 1024 * 1024;

    public static ReadinessReport Evaluate(string localApplicationDataRoot)
    {
        var failures = new List<ErrorCode>();
        if (!OperatingSystem.IsWindows() || RuntimeInformation.OSArchitecture != Architecture.X64
            || Environment.Is64BitProcess == false)
        { failures.Add(ErrorCode.UnsupportedPlatform); }
        if (OperatingSystem.IsWindows() && !OperatingSystem.IsWindowsVersionAtLeast(10, 0, 19045))
        { failures.Add(ErrorCode.UnsupportedPlatform); }
        if (!(Avx.IsSupported && Avx2.IsSupported && Fma.IsSupported && HasF16C() && Sse42.IsSupported))
        { failures.Add(ErrorCode.UnsupportedCpu); }
        if (GC.GetGCMemoryInfo().TotalAvailableMemoryBytes < MinimumMemoryBytes)
        { failures.Add(ErrorCode.NotReady); }
        try
        {
            var root = Path.GetPathRoot(Path.GetFullPath(localApplicationDataRoot));
            if (root is null || new DriveInfo(root).AvailableFreeSpace < MinimumFreeStorageBytes)
            { failures.Add(ErrorCode.StorageUnsafe); }
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException)
        { failures.Add(ErrorCode.StorageUnsafe); }
        if (OperatingSystem.IsWindows())
        {
            if (!NativeLibrary.TryLoad("mfplat.dll", out var mediaFoundation))
            { failures.Add(ErrorCode.MediaFoundationUnavailable); }
            else { NativeLibrary.Free(mediaFoundation); }
        }
        return new(failures.Count == 0, failures.Distinct().ToArray());
    }

    private static bool HasF16C() => X86Base.IsSupported
        && (X86Base.CpuId(1, 0).Ecx & (1 << 29)) != 0;
}

public sealed class MonotonicClock : IClock
{
    private static readonly double TickScale = TimeSpan.TicksPerSecond / (double)System.Diagnostics.Stopwatch.Frequency;
    public MonotonicTimestamp GetTimestamp() => new(checked((long)(System.Diagnostics.Stopwatch.GetTimestamp() * TickScale)));

    public async ValueTask<Outcome<Unit>> DelayUntilAsync(AttemptId attempt, MonotonicTimestamp deadline,
        CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        var remaining = deadline.ElapsedSince(GetTimestamp());
        if (remaining <= TimeSpan.Zero) { return Outcome<Unit>.Success(attempt, default); }
        try
        {
            await Task.Delay(remaining, cancellationToken).ConfigureAwait(false);
            return Outcome<Unit>.Success(attempt, default);
        }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(attempt); }
    }
}
