using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("PortableAudio")]
public sealed class AudioTests
{
    [TestMethod]
    [DataRow(134217727L, 1, false)]
    [DataRow(134217727L, 2, true)]
    [DataRow(-1L, 1, true)]
    public void CaptureBufferHasAnExplicitMemoryCeiling(long buffered, int packet, bool expected)
    {
        Assert.AreEqual(expected, WasapiRecorder.ExceedsBufferLimit(buffered, packet));
    }

    private static readonly PcmSourceFormat Mono = new(16000, 1, 16, 16, 4, PcmEncoding.Integer);
    private static readonly MonotonicTimestamp Press = new(TimeSpan.TicksPerSecond);

    [TestMethod]
    [DataRow(16000, 1, 16, PcmEncoding.Integer, 4u)]
    [DataRow(44100, 2, 24, PcmEncoding.Integer, 3u)]
    [DataRow(48000, 6, 32, PcmEncoding.Integer, 63u)]
    [DataRow(48000, 2, 32, PcmEncoding.Float, 3u)]
    public void MixFormatPreservesActualRateBitsAndChannelMask(int rate, int channels, int bits, PcmEncoding encoding, uint mask)
    {
        var format = new PcmSourceFormat(rate, channels, bits, bits, mask, encoding);
        Assert.AreEqual(format, PcmSourceFormat.FromWaveFormat(format.ToWaveFormat()));
    }

    [TestMethod]
    public void Pcm24In32PreservesValidBits()
    {
        var format = new PcmSourceFormat(48000, 2, 32, 24, 3, PcmEncoding.Integer);
        Assert.AreEqual(format, PcmSourceFormat.FromWaveFormat(format.ToWaveFormat()));
    }

    [TestMethod]
    public void UnsupportedAndInconsistentFormatsFailClosed()
    {
        AssertCode(ErrorCode.AudioFormatUnsupported, () => (Mono with { BitsPerSample = 8 }).Validate());
        AssertCode(ErrorCode.AudioFormatUnsupported, () => (Mono with { ChannelMask = 3 }).Validate());
        AssertCode(ErrorCode.AudioFormatUnsupported, () => (Mono with { Encoding = PcmEncoding.Float }).Validate());
        var malformed = Mono.ToWaveFormat();
        malformed[12] = 4;
        AssertCode(ErrorCode.AudioFormatUnsupported, () => PcmSourceFormat.FromWaveFormat(malformed));
        AssertCode(ErrorCode.AudioFormatUnsupported, () => PcmSourceFormat.FromWaveFormat(new byte[17]));
    }

    [TestMethod]
    public void TrimmingExcludesAnySourceFrameCrossingPressOrRelease()
    {
        var packet = Packet(1000);
        Assert.AreEqual((1, 998), PcmConverter.Trim(packet, 16000, Press.Add(TimeSpan.FromTicks(1)), Press.Add(TimeSpan.FromTicks(624999))));
        Assert.AreEqual((0, 0), PcmConverter.Trim(packet, 16000, Press.Add(TimeSpan.FromSeconds(-2)), Press.Add(TimeSpan.FromSeconds(-1))));
        Assert.AreEqual((1000, 0), PcmConverter.Trim(packet, 16000, Press.Add(TimeSpan.FromSeconds(1)), Press.Add(TimeSpan.FromSeconds(2))));
        var largeQpc = packet with { QpcPosition = new(long.MaxValue - 10_000_000) };
        Assert.AreEqual((0, 1000), PcmConverter.Trim(largeQpc, 16000, largeQpc.QpcPosition, new(long.MaxValue)));
    }

    [TestMethod]
    public void Fractional44100RateNeverIncludesBoundaryOverlap()
    {
        var packet = Packet(44100);
        var pressed = Press.Add(TimeSpan.FromTicks(227));
        var released = Press.Add(TimeSpan.FromTicks(9999773));
        var range = PcmConverter.Trim(packet, 44100, pressed, released);
        Assert.AreEqual((2, 44096), range);
        Assert.IsTrue((decimal)range.FirstFrame * TimeSpan.TicksPerSecond / 44100 >= 227);
        Assert.IsTrue((decimal)(range.FirstFrame + range.FrameCount) * TimeSpan.TicksPerSecond / 44100 <= 9999773);
    }

    [TestMethod]
    [DataRow(AudioPacketFlags.Discontinuity)]
    [DataRow(AudioPacketFlags.TimestampError)]
    [DataRow((AudioPacketFlags)8)]
    public void UncertainPacketsCannotBecomeCompletedAudio(AudioPacketFlags flags)
    {
        AssertCode(ErrorCode.AudioTimestampInvalid, () => new AudioPacketSequence(Mono).Validate(Packet(320) with { Flags = flags }));
    }

    [TestMethod]
    public void PositionGapsTimestampDriftAndMalformedFramesFail()
    {
        var sequence = new AudioPacketSequence(Mono);
        sequence.Validate(Packet(320));
        AssertCode(ErrorCode.AudioTimestampInvalid, () => sequence.Validate(Packet(320) with { DevicePosition = 321, QpcPosition = Press.Add(TimeSpan.FromMilliseconds(20)) }));
        AssertCode(ErrorCode.AudioTimestampInvalid, () => sequence.Validate(Packet(320) with { DevicePosition = 320, QpcPosition = Press.Add(TimeSpan.FromMilliseconds(30)) }));
        AssertCode(ErrorCode.AudioTimestampInvalid, () => new AudioPacketSequence(Mono).Validate(Packet(320) with { Data = [] }));
        AssertCode(ErrorCode.AudioTimestampInvalid, () => new AudioPacketSequence(Mono).Validate(Packet(320) with { QpcPosition = new(0) }));
    }

    [TestMethod]
    public void ExactlyTenEnergetic20MsFramesQualifyButPartialFrameDoesNot()
    {
        var pcm = Samples(4800, 0);
        Samples(3200).CopyTo(pcm, 0);
        var energy = AudioPolicy.AnalyzePcm16(pcm);
        Assert.AreEqual(10L, energy.FramesAboveThreshold);
        Assert.AreEqual(TimeSpan.FromMilliseconds(200), energy.ActiveDuration);
        Assert.IsNull(AudioPolicy.Check(Press, Press.Add(TimeSpan.FromMilliseconds(300)), 4800, energy));
        Array.Clear(pcm, 9 * 320 * 2, 320 * 2);
        Array.Resize(ref pcm, (4800 + 319) * 2);
        Samples(319).CopyTo(pcm, 4800 * 2);
        energy = AudioPolicy.AnalyzePcm16(pcm);
        Assert.AreEqual(9L, energy.FramesAboveThreshold);
        Assert.AreEqual(ErrorCode.AudioTooShort, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromMilliseconds(300)), 4800, energy));
    }

    [TestMethod]
    public void EmptyShortSilentAndOverMaximumCannotReachInference()
    {
        var loud = AudioPolicy.AnalyzePcm16(Samples(4800));
        Assert.AreEqual(ErrorCode.AudioTooShort, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromMilliseconds(299)), 4784, loud));
        Assert.AreEqual(ErrorCode.AudioTooShort, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromSeconds(1)), 0, AudioPolicy.AnalyzePcm16([])));
        Assert.AreEqual(ErrorCode.AudioTooShort, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromSeconds(1)), 16000, AudioPolicy.AnalyzePcm16(Samples(16000, 0))));
        Assert.AreEqual(ErrorCode.HoldInterrupted, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromSeconds(120.001)), 4800, loud));
        Assert.AreEqual(ErrorCode.HoldInterrupted, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromSeconds(120)), 4800, loud));
        Assert.AreEqual(ErrorCode.AudioTimestampInvalid, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromTicks(-1)), 4800, loud));
        Assert.AreEqual(ErrorCode.CorruptInput, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromMilliseconds(300)), 4801, loud));
    }

    [TestMethod]
    public void QuietSamplesAreBelowMinus50DbfsAndNotSpeech()
    {
        var energy = AudioPolicy.AnalyzePcm16(Samples(4800, 100));
        Assert.IsTrue(energy.RootMeanSquareDbfs < -50);
        Assert.AreEqual(0L, energy.FramesAboveThreshold);
        Assert.AreEqual(ErrorCode.AudioTooShort, AudioPolicy.Check(Press, Press.Add(TimeSpan.FromMilliseconds(300)), 4800, energy));
        Assert.ThrowsExactly<ArgumentException>(() => AudioPolicy.AnalyzePcm16(new byte[3]));
    }

    [TestMethod]
    public void ConverterTrimsBeforeFilteringRequestsQuality60AndVerifiesWave()
    {
        var factory = new TestResamplerFactory();
        var packet = Packet(16000);
        Samples(1600, 30000).CopyTo(packet.Data, 0);
        Samples(1600, -30000).CopyTo(packet.Data, 14400 * 2);
        var converted = new PcmConverter(factory).Convert(Mono, [packet],
            Press.Add(TimeSpan.FromMilliseconds(100)), Press.Add(TimeSpan.FromMilliseconds(900)), CancellationToken.None);
        Assert.AreEqual(60, factory.Quality);
        Assert.AreEqual(Mono, factory.Format);
        Assert.AreEqual(12800L, converted.FrameCount);
        Assert.AreEqual(25600, factory.ReceivedBytes);
        Assert.AreEqual(1, factory.Drains);
        Assert.AreEqual(25644, converted.Wave.Length);
        CollectionAssert.AreEqual("RIFF"u8.ToArray(), converted.Wave[..4]);
        Assert.AreEqual(converted.Wave.Length - 8, BinaryPrimitives.ReadInt32LittleEndian(converted.Wave.AsSpan(4)));
        Assert.AreEqual(16000, BinaryPrimitives.ReadInt32LittleEndian(converted.Wave.AsSpan(24)));
        Assert.AreEqual(1, BinaryPrimitives.ReadInt16LittleEndian(converted.Wave.AsSpan(22)));
        Assert.AreEqual(16, BinaryPrimitives.ReadInt16LittleEndian(converted.Wave.AsSpan(34)));
        Assert.AreEqual(converted.FrameCount * 2, BinaryPrimitives.ReadInt32LittleEndian(converted.Wave.AsSpan(40)));
        CollectionAssert.AreEqual(Samples(12800), converted.Wave[44..]);
    }

    [TestMethod]
    public void SilentFlagDoesNotLeakUndefinedPacketContents()
    {
        var factory = new TestResamplerFactory();
        AssertCode(ErrorCode.AudioTooShort, () => new PcmConverter(factory).Convert(Mono,
            [Packet(16000) with { Flags = AudioPacketFlags.Silent }], Press, Press.Add(TimeSpan.FromSeconds(1)), CancellationToken.None));
        Assert.IsTrue(factory.InputWasAllZero);
    }

    [TestMethod]
    public void BadDrainCountAndNonFiniteFloatAreRejected()
    {
        var factory = new TestResamplerFactory { OutputDelta = -2 };
        AssertCode(ErrorCode.CorruptInput, () => new PcmConverter(factory).Convert(Mono, [Packet(4800)], Press,
            Press.Add(TimeSpan.FromMilliseconds(300)), CancellationToken.None));
        var format = Mono with { Encoding = PcmEncoding.Float, BitsPerSample = 32, ValidBitsPerSample = 32 };
        var data = new byte[4800 * 4];
        BinaryPrimitives.WriteSingleLittleEndian(data, float.NaN);
        AssertCode(ErrorCode.CorruptInput, () => new PcmConverter(new TestResamplerFactory()).Convert(format,
            [new(data, 4800, 0, Press, AudioPacketFlags.None)], Press, Press.Add(TimeSpan.FromMilliseconds(300)), CancellationToken.None));
    }

    [TestMethod]
    public void ConversionCancellationNeverCreatesWave()
    {
        var factory = new TestResamplerFactory();
        Assert.ThrowsExactly<OperationCanceledException>(() => new PcmConverter(factory).Convert(Mono, [Packet(4800)],
            Press, Press.Add(TimeSpan.FromMilliseconds(300)), new CancellationToken(true)));
        Assert.IsNull(factory.Format);
    }

    [TestMethod]
    public async Task RecorderStopsOnOwnerThreadAndRepeatedStopReturnsSameLease()
    {
        var clock = new AudioTestClock();
        var store = new TestSessionStore();
        var factory = new TestDeviceFactory();
        var recorder = Recorder(store, clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        clock.Advance(TimeSpan.FromSeconds(1));
        factory.Device!.Enqueue(Packet(16000));
        var stopped = await recorder.StopAsync(attempt, clock.GetTimestamp(), CancellationToken.None);
        Assert.IsTrue(stopped.IsSuccess, stopped.Failure?.Code.ToString());
        var repeated = await recorder.StopAsync(attempt, Press, CancellationToken.None);
        Assert.AreSame(stopped.Value, repeated.Value);
        Assert.AreEqual(1, store.Commits);
        Assert.AreEqual("chosen-input", factory.OpenedId);
        Assert.AreEqual(1, factory.Device.Starts);
        Assert.AreEqual(1, factory.Device.Stops);
        Assert.IsTrue(factory.Device.Disposed);
        Assert.IsTrue(factory.Device.OwnerThreadOnly);
        Assert.IsTrue((await recorder.CancelAsync(attempt, new CancellationToken(true))).IsSuccess);
        await stopped.Value!.DisposeAsync();
    }

    [TestMethod]
    public async Task CannotSwitchMicrophonesOrOverlapAttempts()
    {
        var clock = new AudioTestClock();
        var factory = new TestDeviceFactory();
        var recorder = Recorder(new(), clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        Assert.AreEqual(ErrorCode.Busy, (await recorder.StartAsync(attempt, "different-input", Press, CancellationToken.None)).Failure?.Code);
        Assert.AreEqual(ErrorCode.Busy, (await recorder.StartAsync(AttemptId.New(), "chosen-input", Press, CancellationToken.None)).Failure?.Code);
        Assert.IsTrue((await recorder.CancelAsync(attempt, CancellationToken.None)).IsSuccess);
        Assert.IsTrue((await recorder.CancelAsync(attempt, CancellationToken.None)).IsSuccess);
        Assert.AreEqual(1, factory.Opens);
    }

    [TestMethod]
    public async Task PermissionDenialProvidesSettingsLinkAndNextExplicitRetryWorks()
    {
        var clock = new AudioTestClock();
        var factory = new TestDeviceFactory { OpenError = new COMException("denied", unchecked((int)0x80070005)) };
        var recorder = Recorder(new(), clock, factory);
        var failure = await recorder.StartAsync(AttemptId.New(), "chosen-input", Press, CancellationToken.None);
        Assert.AreEqual(ErrorCode.MicrophoneDenied, failure.Failure?.Code);
        Assert.AreEqual("ms-settings:privacy-microphone", AudioRecovery.SettingsUriFor(failure.Failure!.Code));
        Assert.AreEqual(RecoveryAction.OpenMicrophoneSettings, AudioRecovery.ActionFor(failure.Failure.Code));
        factory.OpenError = null;
        var retry = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(retry, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        Assert.IsTrue((await recorder.CancelAsync(retry, CancellationToken.None)).IsSuccess);
    }

    [TestMethod]
    public async Task DeviceRemovalDiscardsAllAudioAndAllowsExplicitReconnect()
    {
        var clock = new AudioTestClock();
        var store = new TestSessionStore();
        var factory = new TestDeviceFactory();
        var recorder = Recorder(store, clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        factory.Device!.ReadError = new COMException("removed", unchecked((int)0x88890004));
        var failed = await recorder.StopAsync(attempt, Press.Add(TimeSpan.FromSeconds(1)), CancellationToken.None);
        Assert.AreEqual(ErrorCode.MicrophoneDisconnected, failed.Failure?.Code);
        Assert.AreEqual(0, store.Commits);
        Assert.IsTrue(factory.Device.Disposed);
        Assert.AreEqual(RecoveryAction.ReconnectMicrophone, AudioRecovery.ActionFor(failed.Failure!.Code));
        var retry = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(retry, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        Assert.IsTrue((await recorder.CancelAsync(retry, CancellationToken.None)).IsSuccess);
    }

    [TestMethod]
    public async Task ReleaseDuringInitializationPreventsLateStart()
    {
        var clock = new AudioTestClock();
        using var blocked = new ManualResetEventSlim();
        var factory = new TestDeviceFactory { OpenBlock = blocked };
        var recorder = Recorder(new(), clock, factory);
        var attempt = AttemptId.New();
        var start = recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None).AsTask();
        await factory.OpenEntered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        var stop = recorder.StopAsync(attempt, Press.Add(TimeSpan.FromMilliseconds(10)), CancellationToken.None).AsTask();
        blocked.Set();
        Assert.AreEqual(OutcomeKind.Cancelled, (await start).Kind);
        Assert.AreEqual(OutcomeKind.Cancelled, (await stop).Kind);
        Assert.AreEqual(0, factory.Device!.Starts);
        Assert.IsTrue(factory.Device.Disposed);
    }

    [TestMethod]
    public async Task StartDeadlineCancelsAndJoinsItsWorker()
    {
        var clock = new AudioTestClock();
        using var blocked = new ManualResetEventSlim();
        var factory = new TestDeviceFactory { OpenBlock = blocked };
        var recorder = Recorder(new(), clock, factory);
        var attempt = AttemptId.New();
        var start = recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None).AsTask();
        await factory.OpenEntered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        clock.Advance(AudioPolicy.StartDeadline);
        await clock.WaitForDelayCountAsync(2);
        blocked.Set();
        Assert.AreEqual(OutcomeKind.TimedOut, (await start).Kind);
        Assert.AreEqual(0, factory.Device!.Starts);
    }

    [TestMethod]
    public async Task ShutdownDeadlineFailsClosedAndNeverOpensAnotherDevice()
    {
        var clock = new AudioTestClock();
        using var blocked = new ManualResetEventSlim();
        var factory = new TestDeviceFactory { StopBlock = blocked };
        var recorder = Recorder(new(), clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        var stop = recorder.StopAsync(attempt, Press, CancellationToken.None).AsTask();
        await factory.Device!.StopEntered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        clock.Advance(AudioPolicy.StopDeadline);
        Assert.AreEqual(ErrorCode.AudioShutdownFailed, (await stop).Failure?.Code);
        Assert.AreEqual(ErrorCode.AudioShutdownFailed, (await recorder.StartAsync(AttemptId.New(), "chosen-input", Press, CancellationToken.None)).Failure?.Code);
        blocked.Set();
        await factory.Device.DisposedSignal.Task.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.AreEqual(1, factory.Opens);
    }

    [TestMethod]
    public async Task StorageDisposalFailureCannotPublishSuccessfulLease()
    {
        var clock = new AudioTestClock();
        var store = new TestSessionStore { FailDispose = true };
        var factory = new TestDeviceFactory();
        var recorder = Recorder(store, clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        clock.Advance(TimeSpan.FromSeconds(1));
        factory.Device!.Enqueue(Packet(16000));
        var outcome = await recorder.StopAsync(attempt, clock.GetTimestamp(), CancellationToken.None);
        Assert.AreEqual(ErrorCode.CleanupFailed, outcome.Failure?.Code);
        Assert.IsTrue(store.Lease!.IsDisposed);
    }

    [TestMethod]
    public async Task CancellationRacingCommitDisposesLeaseBeforeAcknowledgment()
    {
        var clock = new AudioTestClock();
        var store = new TestSessionStore();
        var factory = new TestDeviceFactory();
        var recorder = Recorder(store, clock, factory);
        var attempt = AttemptId.New();
        Task<Outcome<Unit>>? cancellation = null;
        store.OnCommit = () => cancellation = recorder.CancelAsync(attempt, new CancellationToken(true)).AsTask();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        clock.Advance(TimeSpan.FromSeconds(1));
        factory.Device!.Enqueue(Packet(16000));
        var outcome = await recorder.StopAsync(attempt, clock.GetTimestamp(), CancellationToken.None);
        Assert.AreEqual(OutcomeKind.Cancelled, outcome.Kind);
        Assert.IsNotNull(cancellation);
        Assert.IsTrue((await cancellation).IsSuccess);
        Assert.IsTrue(store.Lease!.IsDisposed);
        Assert.AreEqual(1, store.Lease.DisposalCount);
    }

    [TestMethod]
    public async Task MaximumHoldStopsAndDiscardsWithoutRelease()
    {
        var clock = new AudioTestClock();
        var store = new TestSessionStore();
        var factory = new TestDeviceFactory();
        var recorder = Recorder(store, clock, factory);
        var attempt = AttemptId.New();
        Assert.IsTrue((await recorder.StartAsync(attempt, "chosen-input", Press, CancellationToken.None)).IsSuccess);
        clock.Advance(AudioPolicy.MaximumHold);
        await factory.Device!.DisposedSignal.Task.WaitAsync(TimeSpan.FromSeconds(5));
        var outcome = await recorder.StopAsync(attempt, clock.GetTimestamp(), CancellationToken.None);
        Assert.AreEqual(ErrorCode.HoldInterrupted, outcome.Failure?.Code);
        Assert.AreEqual(0, store.Commits);
    }

    [TestMethod]
    public void MissingMediaFeaturePackIsTypedAndActionable()
    {
        var status = new RecoveryStatus(AttemptId.New(), ErrorCode.MediaFoundationUnavailable, RecoveryAction.InstallMediaFeaturePack);
        Assert.AreEqual(status, JsonSerializer.Deserialize<RecoveryStatus>(JsonSerializer.Serialize(status)));
        Assert.AreEqual("ms-settings:optionalfeatures", AudioRecovery.SettingsUriFor(status.Code));
        Assert.AreEqual(status.Action, AudioRecovery.ActionFor(status.Code));
    }

    private static WasapiRecorder Recorder(TestSessionStore store, AudioTestClock clock, TestDeviceFactory factory) => new(store, clock, factory, new(new TestResamplerFactory()));
    private static AudioPacket Packet(int frames) => new(Samples(frames), frames, 0, Press, AudioPacketFlags.None);
    private static byte[] Samples(int count, short amplitude = 8000)
    {
        var pcm = new byte[count * 2];
        for (var index = 0; index < count; index++) { BinaryPrimitives.WriteInt16LittleEndian(pcm.AsSpan(index * 2), amplitude); }
        return pcm;
    }

    private static void AssertCode(ErrorCode expected, Action action) => Assert.AreEqual(expected, Assert.ThrowsExactly<AudioCaptureException>(action).Code);

    private sealed class TestResamplerFactory : IPcmResamplerFactory
    {
        internal PcmSourceFormat? Format;
        internal int Quality;
        internal int ReceivedBytes;
        internal int Drains;
        internal int OutputDelta;
        internal bool InputWasAllZero = true;
        public IPcmResampler Create(PcmSourceFormat source, int quality)
        {
            Format = source;
            Quality = quality;
            return new TestResampler(this);
        }

        private sealed class TestResampler(TestResamplerFactory factory) : IPcmResampler
        {
            private readonly MemoryStream stream = new();
            public void Push(ReadOnlyMemory<byte> source)
            {
                factory.ReceivedBytes += source.Length;
                foreach (var value in source.Span) { if (value != 0) { factory.InputWasAllZero = false; } }
                stream.Write(source.Span);
            }
            public byte[] Drain()
            {
                factory.Drains++;
                var bytes = stream.ToArray();
                Array.Resize(ref bytes, bytes.Length + factory.OutputDelta);
                return bytes;
            }
            public void Dispose() => stream.Dispose();
        }
    }

    private sealed class TestSessionStore : IAudioSessionStore
    {
        internal int Commits;
        internal bool FailDispose;
        internal Action? OnCommit;
        internal TestAudioLease? Lease;
        public IAudioSession Create(AttemptId attempt) => new Session(this, attempt);
        private sealed class Session(TestSessionStore store, AttemptId attempt) : IAudioSession
        {
            public string OwnedWavePath => $"owned/{attempt.Value:D}/input.wav";
            public AudioLease Commit(AudioDescriptor descriptor, ReadOnlyMemory<byte> wave)
            {
                Assert.AreEqual(descriptor.FrameCount * 2 + 44, wave.Length);
                store.Commits++;
                store.Lease = new(descriptor);
                store.OnCommit?.Invoke();
                return store.Lease;
            }
            public void Dispose() { if (store.FailDispose) { throw new IOException("cleanup failed"); } }
        }
    }

    private sealed class AudioTestClock : IClock
    {
        private readonly object gate = new();
        private readonly List<(long Deadline, AttemptId Attempt, TaskCompletionSource<Outcome<Unit>> Completion)> pending = [];
        private long ticks = Press.Ticks;
        private int delays;
        public MonotonicTimestamp GetTimestamp() => new(Interlocked.Read(ref ticks));
        public async ValueTask<Outcome<Unit>> DelayUntilAsync(AttemptId attempt, MonotonicTimestamp deadline, CancellationToken cancellationToken)
        {
            var completion = new TaskCompletionSource<Outcome<Unit>>(TaskCreationOptions.RunContinuationsAsynchronously);
            lock (gate)
            {
                delays++;
                if (deadline.Ticks <= ticks) { completion.SetResult(Outcome<Unit>.Success(attempt, new())); }
                else { pending.Add((deadline.Ticks, attempt, completion)); }
            }
            using var registration = cancellationToken.Register(() => completion.TrySetResult(Outcome<Unit>.Cancelled(attempt)));
            return await completion.Task;
        }
        internal void Advance(TimeSpan elapsed)
        {
            lock (gate)
            {
                ticks += elapsed.Ticks;
                foreach (var wait in pending.Where(value => value.Deadline <= ticks)) { wait.Completion.TrySetResult(Outcome<Unit>.Success(wait.Attempt, new())); }
                pending.RemoveAll(value => value.Completion.Task.IsCompleted);
            }
        }
        internal async Task WaitForDelayCountAsync(int count)
        {
            using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            while (true)
            {
                lock (gate) { if (delays >= count) { return; } }
                await Task.Delay(1, deadline.Token);
            }
        }
    }

    private sealed class TestDeviceFactory : IAudioCaptureDeviceFactory
    {
        internal Exception? OpenError;
        internal ManualResetEventSlim? OpenBlock;
        internal ManualResetEventSlim? StopBlock;
        internal TestDevice? Device;
        internal string? OpenedId;
        internal int Opens;
        internal TaskCompletionSource OpenEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public IReadOnlyList<MicrophoneEndpoint> Enumerate() => [new("chosen-input", "Test microphone", true)];
        public IAudioCaptureDevice Open(string endpointId)
        {
            Opens++;
            OpenedId = endpointId;
            OpenEntered.TrySetResult();
            OpenBlock?.Wait(TimeSpan.FromSeconds(5));
            if (OpenError is { } error) { throw error; }
            return Device = new(StopBlock);
        }
    }

    private sealed class TestDevice(ManualResetEventSlim? stopBlock) : IAudioCaptureDevice
    {
        private readonly int owner = Environment.CurrentManagedThreadId;
        private readonly AutoResetEvent ready = new(false);
        private readonly ConcurrentQueue<AudioPacket> packets = new();
        internal int Starts;
        internal int Stops;
        internal bool Disposed;
        internal bool OwnerThreadOnly = true;
        internal Exception? ReadError;
        internal TaskCompletionSource StopEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal TaskCompletionSource DisposedSignal { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public PcmSourceFormat Format => Mono;
        public WaitHandle PacketReady => ready;
        public void Start() { CheckOwner(); Starts++; }
        public AudioPacket? ReadPacket()
        {
            CheckOwner();
            if (ReadError is { } error) { throw error; }
            return packets.TryDequeue(out var packet) ? packet : null;
        }
        public void Stop()
        {
            CheckOwner();
            if (Starts == 0 || Stops != 0) { return; }
            StopEntered.TrySetResult();
            stopBlock?.Wait(TimeSpan.FromSeconds(5));
            Stops++;
        }
        public void Dispose() { CheckOwner(); Disposed = true; ready.Dispose(); DisposedSignal.TrySetResult(); }
        internal void Enqueue(AudioPacket packet) { packets.Enqueue(packet); ready.Set(); }
        private void CheckOwner() { OwnerThreadOnly &= owner == Environment.CurrentManagedThreadId; }
    }
}

[TestClass]
[TestCategory("WindowsNativeAudio")]
public sealed class MediaFoundationAudioTests
{
    [TestMethod]
    [DataRow(44100, 16, PcmEncoding.Integer)]
    [DataRow(48000, 24, PcmEncoding.Integer)]
    [DataRow(48000, 32, PcmEncoding.Integer)]
    [DataRow(48000, 32, PcmEncoding.Float)]
    public void NativeResamplerConvertsAndDrainsRealFormats(int rate, int bits, PcmEncoding encoding)
    {
        if (!OperatingSystem.IsWindows()) { Assert.Inconclusive("Native Media Foundation requires a Windows host; portable tests do not verify it."); }
        var format = new PcmSourceFormat(rate, 2, bits, bits, 3, encoding);
        var data = new byte[rate * format.BlockAlignment];
        for (var frame = 0; frame < rate; frame++)
        {
            var value = Math.Sin(2 * Math.PI * 440 * frame / rate) * 0.25;
            for (var channel = 0; channel < 2; channel++)
            {
                var offset = frame * format.BlockAlignment + channel * bits / 8;
                if (encoding == PcmEncoding.Float) { BinaryPrimitives.WriteSingleLittleEndian(data.AsSpan(offset), (float)value); }
                else if (bits == 16) { BinaryPrimitives.WriteInt16LittleEndian(data.AsSpan(offset), (short)(value * 32767)); }
                else if (bits == 32) { BinaryPrimitives.WriteInt32LittleEndian(data.AsSpan(offset), (int)(value * int.MaxValue)); }
                else
                {
                    var sample = (int)(value * 8388607);
                    data[offset] = (byte)sample;
                    data[offset + 1] = (byte)(sample >> 8);
                    data[offset + 2] = (byte)(sample >> 16);
                }
            }
        }

        var press = new MonotonicTimestamp(TimeSpan.TicksPerSecond);
        var result = new PcmConverter().Convert(format, [new(data, rate, 0, press, AudioPacketFlags.None)],
            press, press.Add(TimeSpan.FromSeconds(1)), CancellationToken.None);
        Assert.AreEqual(16000L, result.FrameCount);
        Assert.AreEqual(32044, result.Wave.Length);
        Assert.IsTrue(result.Energy.ActiveDuration >= TimeSpan.FromMilliseconds(900));
    }
}

// PHYSICAL CAPTURE PROTOCOL — not executed or passed by the tests above:
// 1. On each physical Windows 10 22H2 x64 / Windows 11 25H2 x64 host record OS
//    build, endpoint ID/name/mix format, app SHA and exact artifact hash. Run the
//    WindowsNativeAudio category; retain its real results, never portable mocks.
// 2. Select a microphone once. Speak audible markers before press, during hold,
//    and after release. Inspect/listen to the owned WAV BEFORE lease disposal:
//    16 kHz mono PCM16, exact RIFF/data counts, no outside marker. Repeat 10 times.
// 3. Deny desktop microphone access, start, verify MicrophoneDenied and the
//    ms-settings:privacy-microphone link; permit access and explicitly retry.
//    Unplug mid-hold: verify discard, no file/inference, Reconnect then retry,
//    and no switch to a different available microphone.
// 4. Exercise silence, <300 ms, 120-second hold expiry, Escape, lost release,
//    release during startup and application exit. Confirm stop acknowledgment,
//    no surviving microphone indicator and no owned temporary WAV after cleanup.
// 5. On Windows N without Media Feature Pack verify MediaFoundationUnavailable
//    and Optional Features guidance; install the pack manually, restart and
//    repeat capture. Any missing host/device observation remains UNVERIFIED.
