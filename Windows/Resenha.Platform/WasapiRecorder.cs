using System.Runtime.InteropServices;
using Resenha.Core;

namespace Resenha.Platform;

// Implemented by the owned-storage adapter. Commit transfers ownership only on
// success; Dispose cleans an uncommitted attempt and surfaces deletion failures.
public interface IAudioSessionStore { IAudioSession Create(AttemptId attempt); }
public interface IAudioSession : IDisposable
{
    string OwnedWavePath { get; }
    AudioLease Commit(AudioDescriptor descriptor, ReadOnlyMemory<byte> wave);
}

public sealed record MicrophoneEndpoint(string Id, string DisplayName, bool IsDefault);

public interface IAudioCaptureDeviceFactory
{
    IReadOnlyList<MicrophoneEndpoint> Enumerate();
    IAudioCaptureDevice Open(string endpointId);
}

// All calls, including Dispose and each native GetBuffer/ReleaseBuffer pair,
// belong to one dedicated audio worker, never a task-pool continuation.
public interface IAudioCaptureDevice : IDisposable
{
    PcmSourceFormat Format { get; }
    WaitHandle PacketReady { get; }
    void Start();
    AudioPacket? ReadPacket();
    void Stop();
}

public static class AudioRecovery
{
    public static RecoveryAction ActionFor(ErrorCode code) => code switch
    {
        ErrorCode.MicrophoneDenied => RecoveryAction.OpenMicrophoneSettings,
        ErrorCode.MicrophoneUnavailable or ErrorCode.AudioFormatUnsupported => RecoveryAction.ChooseMicrophone,
        ErrorCode.MicrophoneDisconnected => RecoveryAction.ReconnectMicrophone,
        ErrorCode.MediaFoundationUnavailable => RecoveryAction.InstallMediaFeaturePack,
        ErrorCode.AudioShutdownFailed => RecoveryAction.ReopenApplication,
        _ => RecoveryAction.Retry
    };

    public static string? SettingsUriFor(ErrorCode code) => code switch
    {
        ErrorCode.MicrophoneDenied => "ms-settings:privacy-microphone",
        ErrorCode.MediaFoundationUnavailable => "ms-settings:optionalfeatures",
        _ => null
    };

    public static ErrorCode FromException(Exception exception) => exception switch
    {
        AudioCaptureException audio => audio.Code,
        UnauthorizedAccessException => ErrorCode.MicrophoneDenied,
        COMException { HResult: unchecked((int)0x80070005) } => ErrorCode.MicrophoneDenied,
        COMException { HResult: unchecked((int)0x88890004) or unchecked((int)0x88890026) } => ErrorCode.MicrophoneDisconnected,
        COMException { HResult: unchecked((int)0x88890008) } => ErrorCode.AudioFormatUnsupported,
        COMException com when ((uint)com.HResult & 0xffff0000u) == 0xc00d0000u => ErrorCode.AudioFormatUnsupported,
        _ => ErrorCode.MicrophoneUnavailable
    };
}

public sealed class WasapiRecorder(IAudioSessionStore storage, IClock clock,
    IAudioCaptureDeviceFactory? devices = null, PcmConverter? converter = null) : IAudioRecorder
{
    internal const long MaximumBufferedBytes = 128L * 1024 * 1024;
    internal static bool ExceedsBufferLimit(long bufferedBytes, int nextPacketBytes) =>
        bufferedBytes < 0 || nextPacketBytes < 0 || bufferedBytes > MaximumBufferedBytes - nextPacketBytes;
    private readonly IAudioCaptureDeviceFactory devices = devices ?? new WasapiCaptureDeviceFactory();
    private readonly PcmConverter converter = converter ?? new PcmConverter();
    private readonly object gate = new();
    private Capture? current;
    private bool shutdownFailed;

    public ValueTask<Outcome<IReadOnlyList<MicrophoneEndpoint>>> EnumerateAsync(AttemptId operation, CancellationToken cancellationToken)
    {
        operation.ThrowIfEmpty();
        var completion = new TaskCompletionSource<Outcome<IReadOnlyList<MicrophoneEndpoint>>>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try
            {
                if (cancellationToken.IsCancellationRequested)
                {
                    completion.SetResult(Outcome<IReadOnlyList<MicrophoneEndpoint>>.Cancelled(operation));
                    return;
                }

                var microphones = devices.Enumerate();
                completion.SetResult(cancellationToken.IsCancellationRequested
                    ? Outcome<IReadOnlyList<MicrophoneEndpoint>>.Cancelled(operation)
                    : Outcome<IReadOnlyList<MicrophoneEndpoint>>.Success(operation, microphones));
            }
            catch (Exception exception) { completion.SetResult(Outcome<IReadOnlyList<MicrophoneEndpoint>>.Failed(operation, AudioRecovery.FromException(exception))); }
        })
        { IsBackground = true, Name = "Resenha microphone enumeration" };
        thread.Start();
        return new(completion.Task);
    }

    public ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, string deviceId,
        MonotonicTimestamp pressedAt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (string.IsNullOrWhiteSpace(deviceId)) { return ValueTask.FromResult(Outcome<Unit>.Failed(attempt, ErrorCode.MicrophoneUnavailable)); }
        if (cancellationToken.IsCancellationRequested) { return ValueTask.FromResult(Outcome<Unit>.Cancelled(attempt)); }
        lock (gate)
        {
            if (shutdownFailed) { return ValueTask.FromResult(Outcome<Unit>.Failed(attempt, ErrorCode.AudioShutdownFailed)); }
            if (current is { } existing && !existing.Completed.Task.IsCompleted)
            {
                return existing.Attempt == attempt && existing.DeviceId == deviceId && existing.PressedAt == pressedAt
                    ? new(WaitForStartAsync(existing, cancellationToken))
                    : ValueTask.FromResult(Outcome<Unit>.Failed(attempt, ErrorCode.Busy));
            }

            // An old attempt cannot be restarted by a duplicated/late press.
            if (current?.Attempt == attempt) { return ValueTask.FromResult(Outcome<Unit>.Failed(attempt, ErrorCode.NotReady)); }
            var now = clock.GetTimestamp();
            if (pressedAt.Ticks < 0 || pressedAt.Ticks > now.Ticks || now.Ticks - pressedAt.Ticks >= AudioPolicy.MaximumHold.Ticks)
            {
                return ValueTask.FromResult(Outcome<Unit>.Failed(attempt, ErrorCode.AudioTimestampInvalid));
            }

            var capture = new Capture(attempt, deviceId, pressedAt);
            current = capture;
            capture.CancellationRegistration = cancellationToken.Register(() => capture.RequestCancel());
            var worker = new Thread(() => Run(capture)) { IsBackground = true, Name = "Resenha WASAPI capture" };
            // IAudioClient's documented first-use apartment is STA. This is a
            // dedicated worker, not the WPF dispatcher; every packet stays here.
            if (OperatingSystem.IsWindows()) { worker.SetApartmentState(ApartmentState.STA); }
            worker.Start();
            return new(WaitForStartAsync(capture, cancellationToken));
        }
    }

    public ValueTask<Outcome<AudioLease>> StopAsync(AttemptId attempt, MonotonicTimestamp releasedAt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        Capture? capture;
        lock (gate) { capture = current?.Attempt == attempt ? current : null; }
        if (capture is null) { return ValueTask.FromResult(Outcome<AudioLease>.Failed(attempt, ErrorCode.NotReady)); }
        capture.RequestStop(releasedAt);
        return new(WaitForStopAsync(capture, cancellationToken));
    }

    public ValueTask<Outcome<Unit>> CancelAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        Capture? capture;
        lock (gate) { capture = current?.Attempt == attempt ? current : null; }
        // Cleanup deliberately ignores the cancelled attempt token.
        if (capture is null) { return ValueTask.FromResult(Outcome<Unit>.Success(attempt, new())); }
        capture.RequestCancel();
        return new(CancelAndJoinAsync(capture));
    }

    private async Task<Outcome<Unit>> WaitForStartAsync(Capture capture, CancellationToken cancellationToken)
    {
        if (await WithinAsync(capture.Started.Task, capture.Attempt, AudioPolicy.StartDeadline, cancellationToken).ConfigureAwait(false))
        {
            return await capture.Started.Task.ConfigureAwait(false);
        }

        capture.RequestCancel();
        var cleanup = await CancelAndJoinAsync(capture).ConfigureAwait(false);
        if (!cleanup.IsSuccess) { return cleanup; }
        return cancellationToken.IsCancellationRequested ? Outcome<Unit>.Cancelled(capture.Attempt) : Outcome<Unit>.TimedOut(capture.Attempt);
    }

    private async Task<Outcome<AudioLease>> WaitForStopAsync(Capture capture, CancellationToken cancellationToken)
    {
        if (!await WithinAsync(capture.Shutdown.Task, capture.Attempt, AudioPolicy.StopDeadline, CancellationToken.None).ConfigureAwait(false))
        {
            capture.RequestCancel();
            LatchShutdownFailure();
            return Outcome<AudioLease>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed);
        }

        var shutdown = await capture.Shutdown.Task.ConfigureAwait(false);
        if (!shutdown.IsSuccess)
        {
            LatchShutdownFailure();
            return Outcome<AudioLease>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed);
        }

        using var registration = cancellationToken.Register(() => capture.RequestCancel());
        return await capture.Completed.Task.ConfigureAwait(false);
    }

    private async Task<Outcome<Unit>> CancelAndJoinAsync(Capture capture)
    {
        if (!await WithinAsync(capture.Completed.Task, capture.Attempt, AudioPolicy.StopDeadline, CancellationToken.None).ConfigureAwait(false))
        {
            LatchShutdownFailure();
            return Outcome<Unit>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed);
        }

        var shutdown = await capture.Shutdown.Task.ConfigureAwait(false);
        var completion = await capture.Completed.Task.ConfigureAwait(false);
        if (!shutdown.IsSuccess)
        {
            LatchShutdownFailure();
            return Outcome<Unit>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed);
        }

        return completion.Failure?.Code == ErrorCode.CleanupFailed
            ? Outcome<Unit>.Failed(capture.Attempt, ErrorCode.CleanupFailed)
            : Outcome<Unit>.Success(capture.Attempt, new());
    }

    private async Task<bool> WithinAsync(Task work, AttemptId attempt, TimeSpan budget, CancellationToken cancellationToken)
    {
        using var delayCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var deadline = clock.DelayUntilAsync(attempt, clock.GetTimestamp().Add(budget), delayCancellation.Token).AsTask();
        var finished = await Task.WhenAny(work, deadline).ConfigureAwait(false);
        await delayCancellation.CancelAsync().ConfigureAwait(false);
        return finished == work;
    }

    private void LatchShutdownFailure() { lock (gate) { shutdownFailed = true; } }

    private void Run(Capture capture)
    {
        IAudioCaptureDevice? device = null;
        var packets = new List<AudioPacket>();
        Outcome<AudioLease>? completion = null;
        AudioLease? pendingLease = null;
        var nativeShutdownSucceeded = true;
        try
        {
            try
            {
                capture.ThrowIfCancelledOrStoppedBeforeStart();
                device = devices.Open(capture.DeviceId);
                device.Format.Validate();
                capture.ThrowIfCancelledOrStoppedBeforeStart();
                // Native startup is synchronous on this owner. If release races it,
                // the worker immediately stops and discards before returning ready.
                device.Start();
                capture.ThrowIfCancelledOrStoppedBeforeStart();
                capture.Started.TrySetResult(Outcome<Unit>.Success(capture.Attempt, new()));
                var sequence = new AudioPacketSequence(device.Format);
                var handles = new[] { capture.Signal, device.PacketReady };
                while (!capture.HasStopRequest)
                {
                    if (clock.GetTimestamp().Ticks - capture.PressedAt.Ticks >= AudioPolicy.MaximumHold.Ticks)
                    {
                        throw new AudioCaptureException(ErrorCode.HoldInterrupted);
                    }

                    WaitHandle.WaitAny(handles, 100);
                    if (capture.HasStopRequest) { break; }
                    ReadAvailable(device, sequence, packets, capture);
                }

                capture.Cancellation.Token.ThrowIfCancellationRequested();
                // Stop first, then drain queued packets; each is still QPC-trimmed.
                device.Stop();
                ReadAvailable(device, sequence, packets, capture);
            }
            catch (OperationCanceledException) { completion = Outcome<AudioLease>.Cancelled(capture.Attempt); }
            catch (Exception exception) { completion = Outcome<AudioLease>.Failed(capture.Attempt, AudioRecovery.FromException(exception)); }
            finally
            {
                if (device is not null)
                {
                    try { device.Stop(); }
                    catch (AudioCaptureException exception) when (exception.Code == ErrorCode.MicrophoneDisconnected)
                    {
                        completion ??= Outcome<AudioLease>.Failed(capture.Attempt, ErrorCode.MicrophoneDisconnected);
                    }
                    catch { nativeShutdownSucceeded = false; }
                    try { device.Dispose(); }
                    catch { nativeShutdownSucceeded = false; }
                }

                capture.Shutdown.TrySetResult(nativeShutdownSucceeded
                    ? Outcome<Unit>.Success(capture.Attempt, new())
                    : Outcome<Unit>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed));
            }

            if (!nativeShutdownSucceeded)
            {
                LatchShutdownFailure();
                completion = Outcome<AudioLease>.Failed(capture.Attempt, ErrorCode.AudioShutdownFailed);
            }

            if (completion is null && device is not null)
            {
                if (capture.ReleasedAt.Ticks > clock.GetTimestamp().Ticks)
                {
                    throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
                }

                var converted = converter.Convert(device.Format, packets, capture.PressedAt,
                    capture.ReleasedAt, capture.Cancellation.Token);
                try
                {
                    capture.Cancellation.Token.ThrowIfCancellationRequested();
                    using (var session = storage.Create(capture.Attempt))
                    {
                        var descriptor = new AudioDescriptor(capture.Attempt, session.OwnedWavePath,
                            converted.FrameCount, converted.Duration, converted.Energy, capture.PressedAt, capture.ReleasedAt);
                        pendingLease = session.Commit(descriptor, converted.Wave);
                        // The storage adapter must never transfer another attempt's file.
                        if (pendingLease.Audio != descriptor)
                        {
                            throw new AudioCaptureException(ErrorCode.StorageUnsafe);
                        }
                    }

                    completion = Outcome<AudioLease>.Success(capture.Attempt, pendingLease);
                }
                finally { Array.Clear(converted.Wave); }
            }
        }
        catch (OperationCanceledException) { completion = Outcome<AudioLease>.Cancelled(capture.Attempt); }
        catch (Exception exception)
        {
            completion = Outcome<AudioLease>.Failed(capture.Attempt,
                exception is AudioCaptureException audio ? audio.Code : exception is IOException or UnauthorizedAccessException ? ErrorCode.CleanupFailed : AudioRecovery.FromException(exception));
        }
        finally
        {
            foreach (var packet in packets) { Array.Clear(packet.Data); }
            capture.CancellationRegistration.Dispose();
            completion ??= Outcome<AudioLease>.Cancelled(capture.Attempt);
            if (pendingLease is not null && (!completion.IsSuccess || capture.Cancellation.IsCancellationRequested))
            {
                try
                {
                    pendingLease.DisposeAsync().AsTask().GetAwaiter().GetResult();
                    if (completion.IsSuccess) { completion = Outcome<AudioLease>.Cancelled(capture.Attempt); }
                }
                catch { completion = Outcome<AudioLease>.Failed(capture.Attempt, ErrorCode.CleanupFailed); }
            }

            var startResult = completion.Kind == OutcomeKind.Cancelled
                ? Outcome<Unit>.Cancelled(capture.Attempt)
                : Outcome<Unit>.Failed(capture.Attempt, completion.Failure?.Code ?? ErrorCode.NotReady);
            capture.Finish(completion);
            capture.Started.TrySetResult(startResult);
        }
    }

    private void ReadAvailable(IAudioCaptureDevice device, AudioPacketSequence sequence, List<AudioPacket> packets, Capture capture)
    {
        for (var index = 0; index < 2048; index++)
        {
            capture.Cancellation.Token.ThrowIfCancellationRequested();
            var packet = device.ReadPacket();
            if (packet is null) { return; }
            try
            {
                sequence.Validate(packet);
                var now = clock.GetTimestamp();
                if (packet.QpcPosition.Ticks > now.Ticks + TimeSpan.TicksPerSecond / device.Format.SampleRate ||
                    packet.QpcPosition.Ticks - capture.PressedAt.Ticks > AudioPolicy.MaximumHold.Ticks ||
                    capture.BufferedFrames + packet.Frames > (AudioPolicy.MaximumHold.TotalSeconds + 1) * device.Format.SampleRate ||
                    ExceedsBufferLimit(capture.BufferedBytes, packet.Data.Length))
                {
                    throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
                }

                capture.BufferedFrames += packet.Frames;
                capture.BufferedBytes += packet.Data.LongLength;
                packets.Add(packet);
            }
            catch { Array.Clear(packet.Data); throw; }
        }

        throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
    }

    private sealed class Capture(AttemptId attempt, string deviceId, MonotonicTimestamp pressedAt)
    {
        private readonly object gate = new();
        private bool stopRequested;
        private bool disposed;
        private MonotonicTimestamp releasedAt;
        internal AttemptId Attempt { get; } = attempt;
        internal string DeviceId { get; } = deviceId;
        internal MonotonicTimestamp PressedAt { get; } = pressedAt;
        internal CancellationTokenSource Cancellation { get; } = new();
        internal AutoResetEvent Signal { get; } = new(false);
        internal CancellationTokenRegistration CancellationRegistration;
        internal long BufferedFrames;
        internal long BufferedBytes;
        internal TaskCompletionSource<Outcome<Unit>> Started { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal TaskCompletionSource<Outcome<Unit>> Shutdown { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal TaskCompletionSource<Outcome<AudioLease>> Completed { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal bool HasStopRequest { get { lock (gate) { return stopRequested; } } }
        internal MonotonicTimestamp ReleasedAt { get { lock (gate) { return releasedAt; } } }

        internal void RequestStop(MonotonicTimestamp release)
        {
            lock (gate)
            {
                if (disposed || stopRequested || Completed.Task.IsCompleted) { return; }
                releasedAt = release;
                stopRequested = true;
                Signal.Set();
            }
        }

        internal void RequestCancel()
        {
            lock (gate)
            {
                if (disposed || Completed.Task.IsCompleted) { return; }
                Cancellation.Cancel();
                stopRequested = true;
                Signal.Set();
            }
        }

        internal void ThrowIfCancelledOrStoppedBeforeStart()
        {
            lock (gate)
            {
                if (stopRequested) { throw new OperationCanceledException(); }
            }
        }

        internal void Finish(Outcome<AudioLease> completion)
        {
            lock (gate)
            {
                // Cancellation and ownership transfer serialize at this boundary.
                if (completion.IsSuccess && Cancellation.IsCancellationRequested)
                {
                    try
                    {
                        completion.Value!.DisposeAsync().AsTask().GetAwaiter().GetResult();
                        completion = Outcome<AudioLease>.Cancelled(Attempt);
                    }
                    catch { completion = Outcome<AudioLease>.Failed(Attempt, ErrorCode.CleanupFailed); }
                }

                disposed = true;
                Signal.Dispose();
                Cancellation.Dispose();
                Completed.TrySetResult(completion);
            }
        }
    }
}

public sealed class WasapiCaptureDeviceFactory : IAudioCaptureDeviceFactory
{
    public IReadOnlyList<MicrophoneEndpoint> Enumerate()
    {
        RequireWindows();
        AudioCom.Check(AudioCom.CoInitializeEx(0, 0));
        nint enumerator = 0;
        nint collection = 0;
        try
        {
            enumerator = WasapiNative.CreateEnumerator();
            string? defaultId = null;
            var hr = AudioCom.Method<WasapiNative.DefaultEndpoint>(enumerator, 4)(enumerator, 1, 0, out var defaultDevice);
            if (hr >= 0)
            {
                try { defaultId = WasapiNative.Id(defaultDevice); }
                finally { Marshal.Release(defaultDevice); }
            }
            else if (hr != unchecked((int)0x80070490)) { AudioCom.Check(hr); }

            AudioCom.Check(AudioCom.Method<WasapiNative.EnumEndpoints>(enumerator, 3)(enumerator, 1, 1, out collection));
            AudioCom.Check(AudioCom.Method<WasapiNative.UIntResult>(collection, 3)(collection, out var count));
            var endpoints = new List<MicrophoneEndpoint>();
            for (uint index = 0; index < count; index++)
            {
                AudioCom.Check(AudioCom.Method<WasapiNative.IndexedPointer>(collection, 4)(collection, index, out var device));
                try
                {
                    var id = WasapiNative.Id(device);
                    endpoints.Add(new(id, WasapiNative.FriendlyName(device), id == defaultId));
                }
                finally { Marshal.Release(device); }
            }

            return endpoints;
        }
        finally
        {
            if (collection != 0) { Marshal.Release(collection); }
            if (enumerator != 0) { Marshal.Release(enumerator); }
            AudioCom.CoUninitialize();
        }
    }

    public IAudioCaptureDevice Open(string endpointId)
    {
        RequireWindows();
        return new WasapiCaptureDevice(endpointId);
    }

    private static void RequireWindows()
    {
        if (!OperatingSystem.IsWindows()) { throw new AudioCaptureException(ErrorCode.UnsupportedPlatform); }
    }
}

internal sealed class WasapiCaptureDevice : IAudioCaptureDevice
{
    private readonly int owner = Environment.CurrentManagedThreadId;
    private readonly AutoResetEvent ready = new(false);
    private nint client;
    private nint capture;
    private bool comInitialized;
    private bool started;
    private bool disposed;
    public PcmSourceFormat Format { get; private set; } = null!;
    public WaitHandle PacketReady => ready;

    internal WasapiCaptureDevice(string endpointId)
    {
        nint enumerator = 0;
        nint endpoint = 0;
        try
        {
            AudioCom.Check(AudioCom.CoInitializeEx(0, 2));
            comInitialized = true;
            enumerator = WasapiNative.CreateEnumerator();
            AudioCom.Check(AudioCom.Method<WasapiNative.GetDevice>(enumerator, 5)(enumerator, endpointId, out endpoint));
            var endpointIid = new Guid("1be09788-6894-4089-8586-9a2a6c265ac5");
            AudioCom.Check(Marshal.QueryInterface(endpoint, in endpointIid, out var endpointInfo));
            try
            {
                AudioCom.Check(AudioCom.Method<WasapiNative.UIntResult>(endpointInfo, 3)(endpointInfo, out var flow));
                if (flow != 1) { throw new AudioCaptureException(ErrorCode.MicrophoneUnavailable); }
            }
            finally { Marshal.Release(endpointInfo); }

            AudioCom.Check(AudioCom.Method<WasapiNative.UIntResult>(endpoint, 6)(endpoint, out var state));
            if (state != 1) { throw new AudioCaptureException(ErrorCode.MicrophoneUnavailable); }
            var clientIid = new Guid("1cb9ad4c-dbfa-4c32-b178-c2f568a703b2");
            AudioCom.Check(AudioCom.Method<WasapiNative.Activate>(endpoint, 3)(endpoint, in clientIid, 1, 0, out client));
            AudioCom.Check(AudioCom.Method<WasapiNative.PointerResult>(client, 8)(client, out var waveFormat));
            try
            {
                var extra = (ushort)Marshal.ReadInt16(waveFormat, 16);
                if (extra > 256) { throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported); }
                var bytes = new byte[18 + extra];
                Marshal.Copy(waveFormat, bytes, 0, bytes.Length);
                Format = PcmSourceFormat.FromWaveFormat(bytes);
                // Shared capture, event-driven, no loopback and no automatic device switch.
                AudioCom.Check(AudioCom.Method<WasapiNative.Initialize>(client, 3)(client, 0, 0x00040000 | 0x00080000,
                    TimeSpan.TicksPerMillisecond * 100, 0, waveFormat, 0));
            }
            finally { Marshal.FreeCoTaskMem(waveFormat); }

            AudioCom.Check(AudioCom.Method<AudioCom.PointerArgument>(client, 13)(client, ready.SafeWaitHandle.DangerousGetHandle()));
            var captureIid = new Guid("c8adbd64-e71e-48a0-a4de-185c395cd317");
            AudioCom.Check(AudioCom.Method<WasapiNative.GetService>(client, 14)(client, in captureIid, out capture));
        }
        catch
        {
            if (endpoint != 0) { Marshal.Release(endpoint); endpoint = 0; }
            if (enumerator != 0) { Marshal.Release(enumerator); enumerator = 0; }
            Dispose();
            throw;
        }
        finally
        {
            if (endpoint != 0) { Marshal.Release(endpoint); }
            if (enumerator != 0) { Marshal.Release(enumerator); }
        }
    }

    public void Start()
    {
        RequireOwner();
        AudioCom.Check(AudioCom.Method<AudioCom.NoArgument>(client, 10)(client));
        started = true;
    }

    public AudioPacket? ReadPacket()
    {
        RequireOwner();
        AudioCom.Check(AudioCom.Method<WasapiNative.UIntResult>(capture, 5)(capture, out var available));
        if (available == 0) { return null; }
        var hr = AudioCom.Method<WasapiNative.GetBuffer>(capture, 3)(capture, out var data, out var frames, out var flags, out var position, out var qpc);
        AudioCom.Check(hr);
        if (hr == 0x08890001) { return null; } // AUDCLNT_S_BUFFER_EMPTY: no buffer acquired.
        try
        {
            if (frames == 0 || frames > Format.SampleRate || qpc > long.MaxValue)
            {
                throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
            }

            var bytes = new byte[checked((int)frames * Format.BlockAlignment)];
            if ((flags & (uint)AudioPacketFlags.Silent) == 0)
            {
                if (data == 0) { throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid); }
                Marshal.Copy(data, bytes, 0, bytes.Length);
            }

            return new(bytes, (int)frames, position, new((long)qpc), (AudioPacketFlags)flags);
        }
        finally
        {
            // Same thread and packet count even when validation/copy throws.
            AudioCom.Check(AudioCom.Method<WasapiNative.ReleaseBuffer>(capture, 4)(capture, frames));
        }
    }

    public void Stop()
    {
        RequireOwner();
        if (!started) { return; }
        var hr = AudioCom.Method<AudioCom.NoArgument>(client, 11)(client);
        if (hr is unchecked((int)0x88890004) or unchecked((int)0x88890026))
        {
            // An invalidated endpoint cannot keep recording; releasing its COM
            // references acknowledges shutdown and permits an explicit reconnect.
            started = false;
            throw new AudioCaptureException(ErrorCode.MicrophoneDisconnected);
        }

        AudioCom.Check(hr);
        started = false;
    }

    public void Dispose()
    {
        RequireOwner();
        if (disposed) { return; }
        try { Stop(); }
        finally
        {
            if (capture != 0) { Marshal.Release(capture); capture = 0; }
            if (client != 0) { Marshal.Release(client); client = 0; }
            ready.Dispose();
            if (comInitialized) { AudioCom.CoUninitialize(); comInitialized = false; }
            disposed = true;
        }
    }

    private void RequireOwner()
    {
        if (Environment.CurrentManagedThreadId != owner) { throw new InvalidOperationException("WASAPI ownership changed threads."); }
    }
}

internal static class WasapiNative
{
    internal static nint CreateEnumerator()
    {
        var clsid = new Guid("bcde0395-e52f-467c-8e3d-c4579291692e");
        var iid = new Guid("a95664d2-9614-4f35-a746-de8db63617e6");
        AudioCom.Check(AudioCom.CoCreateInstance(in clsid, 0, 1, in iid, out var value));
        return value;
    }

    internal static string Id(nint device)
    {
        AudioCom.Check(AudioCom.Method<PointerResult>(device, 5)(device, out var text));
        try { return Marshal.PtrToStringUni(text) ?? throw new AudioCaptureException(ErrorCode.MicrophoneUnavailable); }
        finally { Marshal.FreeCoTaskMem(text); }
    }

    internal static string FriendlyName(nint device)
    {
        AudioCom.Check(AudioCom.Method<IndexedPointer>(device, 4)(device, 0, out var store));
        try
        {
            var key = new PropertyKey { Format = new("a45c254e-df1c-4efd-8020-67d146a850e0"), Id = 14 };
            AudioCom.Check(AudioCom.Method<PropertyValue>(store, 5)(store, in key, out var value));
            try { return value.Type == 31 ? Marshal.PtrToStringUni(value.Pointer) ?? "Microphone" : "Microphone"; }
            finally { AudioCom.Check(PropVariantClear(ref value)); }
        }
        finally { Marshal.Release(store); }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)] internal struct PropertyKey { internal Guid Format; internal uint Id; }
    [StructLayout(LayoutKind.Explicit, Size = 24)] internal struct PropertyVariant { [FieldOffset(0)] internal ushort Type; [FieldOffset(8)] internal nint Pointer; }
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int PointerResult(nint self, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int UIntResult(nint self, out uint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int IndexedPointer(nint self, uint index, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int EnumEndpoints(nint self, int flow, uint states, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int DefaultEndpoint(nint self, int flow, int role, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int GetDevice(nint self, [MarshalAs(UnmanagedType.LPWStr)] string id, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int Activate(nint self, in Guid iid, uint context, nint parameters, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int Initialize(nint self, int shareMode, uint flags, long duration, long periodicity, nint format, nint session);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int GetService(nint self, in Guid iid, out nint result);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int GetBuffer(nint self, out nint data, out uint frames, out uint flags, out ulong position, out ulong qpc);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int ReleaseBuffer(nint self, uint frames);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int PropertyValue(nint self, in PropertyKey key, out PropertyVariant value);
    [DllImport("ole32.dll", ExactSpelling = true)] internal static extern int PropVariantClear(ref PropertyVariant value);
}
