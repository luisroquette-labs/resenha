using System.Buffers.Binary;
using System.Numerics;
using System.Runtime.InteropServices;
using Resenha.Core;

namespace Resenha.Platform;

public enum PcmEncoding { Integer, Float }

public sealed record PcmSourceFormat(int SampleRate, int Channels, int BitsPerSample,
    int ValidBitsPerSample, uint ChannelMask, PcmEncoding Encoding)
{
    public int BlockAlignment => checked(Channels * BitsPerSample / 8);

    public void Validate()
    {
        if (SampleRate is < 8000 or > 192000 || Channels is < 1 or > 8 ||
            BitsPerSample is not (16 or 24 or 32) || ValidBitsPerSample is not (16 or 24 or 32) ||
            ValidBitsPerSample > BitsPerSample || !Enum.IsDefined(Encoding) ||
            (Encoding == PcmEncoding.Float && (BitsPerSample != 32 || ValidBitsPerSample != 32)) ||
            BitOperations.PopCount(ChannelMask) != Channels || (ChannelMask & ~0x3ffffu) != 0)
        {
            throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
        }
    }

    public static PcmSourceFormat FromWaveFormat(ReadOnlySpan<byte> waveFormat)
    {
        if (waveFormat.Length < 18)
        {
            throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
        }

        var tag = BinaryPrimitives.ReadUInt16LittleEndian(waveFormat);
        var channels = BinaryPrimitives.ReadUInt16LittleEndian(waveFormat[2..]);
        var rate = BinaryPrimitives.ReadInt32LittleEndian(waveFormat[4..]);
        var bits = BinaryPrimitives.ReadUInt16LittleEndian(waveFormat[14..]);
        var validBits = bits;
        var extra = BinaryPrimitives.ReadUInt16LittleEndian(waveFormat[16..]);
        uint mask = channels switch { 1 => 4, 2 => 3, _ => 0 };
        if (tag == 0xfffe)
        {
            if (extra < 22 || waveFormat.Length < 18 + extra)
            {
                throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
            }

            validBits = BinaryPrimitives.ReadUInt16LittleEndian(waveFormat[18..]);
            mask = BinaryPrimitives.ReadUInt32LittleEndian(waveFormat[20..]);
            var subtype = new Guid(waveFormat.Slice(24, 16));
            tag = subtype == AudioCom.PcmSubtype ? (ushort)1 : subtype == AudioCom.FloatSubtype ? (ushort)3 : (ushort)0;
        }

        if (tag is not (1 or 3))
        {
            throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
        }

        var format = new PcmSourceFormat(rate, channels, bits, validBits, mask,
            tag == 3 ? PcmEncoding.Float : PcmEncoding.Integer);
        format.Validate();
        if (BinaryPrimitives.ReadUInt16LittleEndian(waveFormat[12..]) != format.BlockAlignment ||
            BinaryPrimitives.ReadInt32LittleEndian(waveFormat[8..]) != rate * format.BlockAlignment)
        {
            throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
        }

        return format;
    }

    public byte[] ToWaveFormat()
    {
        Validate();
        var bytes = new byte[40];
        BinaryPrimitives.WriteUInt16LittleEndian(bytes, 0xfffe);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(2), (ushort)Channels);
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(4), SampleRate);
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(8), SampleRate * BlockAlignment);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(12), (ushort)BlockAlignment);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(14), (ushort)BitsPerSample);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(16), 22);
        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(18), (ushort)ValidBitsPerSample);
        BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(20), ChannelMask);
        (Encoding == PcmEncoding.Float ? AudioCom.FloatSubtype : AudioCom.PcmSubtype).TryWriteBytes(bytes.AsSpan(24));
        return bytes;
    }
}

[Flags]
public enum AudioPacketFlags : uint { None = 0, Discontinuity = 1, Silent = 2, TimestampError = 4 }

// QpcPosition is WASAPI's 100 ns QPC value, not the raw performance-counter value.
public sealed record AudioPacket(byte[] Data, int Frames, ulong DevicePosition,
    MonotonicTimestamp QpcPosition, AudioPacketFlags Flags);

public sealed class AudioCaptureException : Exception
{
    public AudioCaptureException(ErrorCode code) : base(code.ToString()) => Code = code;
    public ErrorCode Code { get; }
}

public interface IPcmResampler : IDisposable
{
    void Push(ReadOnlyMemory<byte> source);
    byte[] Drain();
}

public interface IPcmResamplerFactory
{
    IPcmResampler Create(PcmSourceFormat source, int quality);
}

public sealed record ConvertedAudio(byte[] Wave, long FrameCount, AudioEnergySummary Energy)
{
    public TimeSpan Duration => TimeSpan.FromTicks(FrameCount * TimeSpan.TicksPerSecond / AudioDescriptor.SampleRate);
}

/// <summary>Validates packet continuity and trims whole source frames before any filter sees them.</summary>
public sealed class PcmConverter(IPcmResamplerFactory? factory = null)
{
    public const int ResamplerQuality = 60;
    private readonly IPcmResamplerFactory factory = factory ?? new MediaFoundationResamplerFactory();

    public ConvertedAudio Convert(PcmSourceFormat format, IReadOnlyList<AudioPacket> packets,
        MonotonicTimestamp pressedAt, MonotonicTimestamp releasedAt, CancellationToken cancellationToken)
    {
        format.Validate();
        if (pressedAt.Ticks < 0 || releasedAt.Ticks < pressedAt.Ticks)
        {
            throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
        }

        if (releasedAt.Ticks - pressedAt.Ticks >= AudioPolicy.MaximumHold.Ticks)
        {
            throw new AudioCaptureException(ErrorCode.HoldInterrupted);
        }

        cancellationToken.ThrowIfCancellationRequested();
        using var resampler = factory.Create(format, ResamplerQuality);
        var sequence = new AudioPacketSequence(format);
        long keptFrames = 0;
        foreach (var packet in packets)
        {
            cancellationToken.ThrowIfCancellationRequested();
            sequence.Validate(packet);
            var (first, count) = Trim(packet, format.SampleRate, pressedAt, releasedAt);
            if (count == 0)
            {
                continue;
            }

            var bytes = packet.Data.AsMemory(first * format.BlockAlignment, count * format.BlockAlignment);
            if (packet.Flags.HasFlag(AudioPacketFlags.Silent))
            {
                // Never read undefined driver memory for AUDCLNT_BUFFERFLAGS_SILENT.
                var silence = new byte[bytes.Length];
                resampler.Push(silence);
            }
            else
            {
                if (format.Encoding == PcmEncoding.Float)
                {
                    for (var index = 0; index < bytes.Length; index += 4)
                    {
                        if (!float.IsFinite(BinaryPrimitives.ReadSingleLittleEndian(bytes.Span[index..])))
                        {
                            throw new AudioCaptureException(ErrorCode.CorruptInput);
                        }
                    }
                }

                resampler.Push(bytes);
            }

            keptFrames += count;
        }

        cancellationToken.ThrowIfCancellationRequested();
        var pcm = resampler.Drain();
        try
        {
            var expectedFrames = keptFrames * AudioDescriptor.SampleRate / format.SampleRate;
            // One rounding sample may be emitted by MF. Never pad a short drain or
            // keep filter-tail samples beyond the duration of the trimmed source.
            if (pcm.Length % 2 != 0 || pcm.LongLength / 2 < expectedFrames || pcm.LongLength / 2 > expectedFrames + 1)
            {
                throw new AudioCaptureException(ErrorCode.CorruptInput);
            }

            var exactPcm = pcm.AsSpan(0, checked((int)expectedFrames * 2));
            var energy = AudioPolicy.AnalyzePcm16(exactPcm);
            var failure = AudioPolicy.Check(pressedAt, releasedAt, expectedFrames, energy);
            if (failure is { } code)
            {
                throw new AudioCaptureException(code);
            }

            cancellationToken.ThrowIfCancellationRequested();
            return new(CreateWave(exactPcm), expectedFrames, energy);
        }
        finally
        {
            Array.Clear(pcm);
        }
    }

    public static (int FirstFrame, int FrameCount) Trim(AudioPacket packet, int sampleRate,
        MonotonicTimestamp pressedAt, MonotonicTimestamp releasedAt)
    {
        if (sampleRate <= 0 || packet.Frames < 0 || releasedAt.Ticks < pressedAt.Ticks)
        {
            throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
        }

        // Decimal avoids overflow and keeps fractional 44.1 kHz frames exact.
        var first = (int)Math.Clamp(decimal.Ceiling(((decimal)pressedAt.Ticks - packet.QpcPosition.Ticks) * sampleRate / TimeSpan.TicksPerSecond), 0, packet.Frames);
        var end = (int)Math.Clamp(decimal.Floor(((decimal)releasedAt.Ticks - packet.QpcPosition.Ticks) * sampleRate / TimeSpan.TicksPerSecond), 0, packet.Frames);
        return (first, Math.Max(0, end - first));
    }

    public static byte[] CreateWave(ReadOnlySpan<byte> pcm)
    {
        if (pcm.Length % 2 != 0 || pcm.Length > AudioDescriptor.SampleRate * 2 * AudioPolicy.MaximumHold.TotalSeconds)
        {
            throw new AudioCaptureException(ErrorCode.CorruptInput);
        }

        var wave = new byte[checked(44 + pcm.Length)];
        "RIFF"u8.CopyTo(wave);
        BinaryPrimitives.WriteInt32LittleEndian(wave.AsSpan(4), wave.Length - 8);
        "WAVEfmt "u8.CopyTo(wave.AsSpan(8));
        BinaryPrimitives.WriteInt32LittleEndian(wave.AsSpan(16), 16);
        BinaryPrimitives.WriteUInt16LittleEndian(wave.AsSpan(20), 1);
        BinaryPrimitives.WriteUInt16LittleEndian(wave.AsSpan(22), 1);
        BinaryPrimitives.WriteInt32LittleEndian(wave.AsSpan(24), AudioDescriptor.SampleRate);
        BinaryPrimitives.WriteInt32LittleEndian(wave.AsSpan(28), AudioDescriptor.SampleRate * 2);
        BinaryPrimitives.WriteUInt16LittleEndian(wave.AsSpan(32), 2);
        BinaryPrimitives.WriteUInt16LittleEndian(wave.AsSpan(34), 16);
        "data"u8.CopyTo(wave.AsSpan(36));
        BinaryPrimitives.WriteInt32LittleEndian(wave.AsSpan(40), pcm.Length);
        pcm.CopyTo(wave.AsSpan(44));
        return wave;
    }
}

public sealed class AudioPacketSequence(PcmSourceFormat format)
{
    private ulong? nextDevicePosition;
    private ulong firstDevicePosition;
    private long firstQpc;

    public void Validate(AudioPacket packet)
    {
        if (packet.Flags.HasFlag(AudioPacketFlags.TimestampError) || packet.Flags.HasFlag(AudioPacketFlags.Discontinuity) ||
            (packet.Flags & ~(AudioPacketFlags.Silent | AudioPacketFlags.TimestampError | AudioPacketFlags.Discontinuity)) != 0 ||
            packet.QpcPosition.Ticks <= 0 || packet.Frames <= 0 ||
            packet.Data.Length != (long)packet.Frames * format.BlockAlignment)
        {
            throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
        }

        if (nextDevicePosition is { } next)
        {
            var predicted = (decimal)firstQpc + ((decimal)packet.DevicePosition - firstDevicePosition) * TimeSpan.TicksPerSecond / format.SampleRate;
            if (packet.DevicePosition != next || Math.Abs(packet.QpcPosition.Ticks - predicted) > (decimal)TimeSpan.TicksPerSecond / format.SampleRate + 1)
            {
                throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
            }
        }
        else
        {
            firstDevicePosition = packet.DevicePosition;
            firstQpc = packet.QpcPosition.Ticks;
        }

        if (packet.DevicePosition > ulong.MaxValue - (uint)packet.Frames)
        {
            throw new AudioCaptureException(ErrorCode.AudioTimestampInvalid);
        }

        nextDevicePosition = packet.DevicePosition + (uint)packet.Frames;
    }
}

public sealed class MediaFoundationResamplerFactory : IPcmResamplerFactory
{
    public IPcmResampler Create(PcmSourceFormat source, int quality)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new AudioCaptureException(ErrorCode.UnsupportedPlatform);
        }

        try
        {
            return new MediaFoundationResampler(source, quality);
        }
        catch (Exception exception) when (exception is DllNotFoundException or EntryPointNotFoundException ||
            exception is COMException { HResult: unchecked((int)0x80040154) })
        {
            throw new AudioCaptureException(ErrorCode.MediaFoundationUnavailable);
        }
    }
}

// The worker owns every MF reference and drains before ending the stream.
// API/vtable contract: mftransform.h, mfobjects.h, wmcodecdsp.h (Windows SDK).
internal sealed class MediaFoundationResampler : IPcmResampler
{
    private const int NeedMoreInput = unchecked((int)0xc00d6d72);
    private readonly MemoryStream output = new();
    private readonly int owner = Environment.CurrentManagedThreadId;
    private readonly PcmSourceFormat source;
    private nint transform;
    private bool started;
    private bool comInitialized;
    private bool drained;
    private long inputFrames;
    private int outputBufferSize;
    private int outputAlignment;

    internal MediaFoundationResampler(PcmSourceFormat source, int quality)
    {
        this.source = source;
        source.Validate();
        if (quality != PcmConverter.ResamplerQuality)
        {
            throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
        }

        try
        {
            AudioCom.Check(AudioCom.CoInitializeEx(0, Thread.CurrentThread.GetApartmentState() == ApartmentState.STA ? 2u : 0u));
            comInitialized = true;
            AudioCom.Check(AudioCom.MFStartup(0x20070, 0));
            started = true;
            var clsid = new Guid("f447b69e-1884-4a7e-8055-346f74d6edb3");
            var iid = new Guid("bf94c121-5b05-4e6f-8000-ba598961414d");
            AudioCom.Check(AudioCom.CoCreateInstance(in clsid, 0, 1, in iid, out transform));
            var propsId = new Guid("e7e9984f-f09f-4da4-903f-6e2e0efe56b5");
            AudioCom.Check(Marshal.QueryInterface(transform, in propsId, out var props));
            try
            {
                AudioCom.Check(AudioCom.Method<AudioCom.IntArgument>(props, 3)(props, quality));
            }
            finally { Marshal.Release(props); }

            SetType(15, source);
            SetType(16, new(AudioDescriptor.SampleRate, 1, 16, 16, 4, PcmEncoding.Integer));
            AudioCom.Check(AudioCom.Method<AudioCom.OutputInfo>(transform, 7)(transform, 0, out var info));
            if ((info.Flags & 0x100) != 0 || info.Size > 4 * 1024 * 1024 ||
                info.Alignment > 4096 || (info.Alignment != 0 && !BitOperations.IsPow2(info.Alignment)))
            {
                throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
            }

            outputBufferSize = Math.Max(32768, checked((int)info.Size));
            outputAlignment = Math.Max(15, checked((int)info.Alignment) - 1);
            Message(0x10000000); // NOTIFY_BEGIN_STREAMING
            Message(0x10000003); // NOTIFY_START_OF_STREAM
        }
        catch
        {
            Dispose();
            throw;
        }
    }

    public void Push(ReadOnlyMemory<byte> data)
    {
        RequireOwner();
        if (drained || transform == 0 || data.Length == 0 || data.Length % source.BlockAlignment != 0)
        {
            throw new AudioCaptureException(ErrorCode.CorruptInput);
        }

        nint sample = 0;
        nint buffer = 0;
        try
        {
            AudioCom.Check(AudioCom.MFCreateSample(out sample));
            AudioCom.Check(AudioCom.MFCreateMemoryBuffer(data.Length, out buffer));
            AudioCom.Check(AudioCom.Method<AudioCom.LockBuffer>(buffer, 3)(buffer, out var address, out _, out _));
            try
            {
                var copy = data.ToArray();
                try { Marshal.Copy(copy, 0, address, copy.Length); }
                finally { Array.Clear(copy); }
            }
            finally { AudioCom.Check(AudioCom.Method<AudioCom.NoArgument>(buffer, 4)(buffer)); }

            AudioCom.Check(AudioCom.Method<AudioCom.IntArgument>(buffer, 6)(buffer, data.Length));
            AudioCom.Check(AudioCom.Method<AudioCom.PointerArgument>(sample, 42)(sample, buffer));
            var nextFrames = inputFrames + data.Length / source.BlockAlignment;
            AudioCom.Check(AudioCom.Method<AudioCom.LongArgument>(sample, 36)(sample, inputFrames * TimeSpan.TicksPerSecond / source.SampleRate));
            AudioCom.Check(AudioCom.Method<AudioCom.LongArgument>(sample, 38)(sample,
                nextFrames * TimeSpan.TicksPerSecond / source.SampleRate - inputFrames * TimeSpan.TicksPerSecond / source.SampleRate));
            AudioCom.Check(AudioCom.Method<AudioCom.ProcessInput>(transform, 24)(transform, 0, sample, 0));
            inputFrames = nextFrames;
            ReadOutput();
        }
        finally
        {
            if (buffer != 0) { Marshal.Release(buffer); }
            if (sample != 0) { Marshal.Release(sample); }
        }
    }

    public byte[] Drain()
    {
        RequireOwner();
        if (drained || transform == 0)
        {
            throw new AudioCaptureException(ErrorCode.CorruptInput);
        }

        Message(0x10000002); // NOTIFY_END_OF_STREAM
        Message(1); // COMMAND_DRAIN: pull until MF_E_TRANSFORM_NEED_MORE_INPUT
        ReadOutput();
        Message(0x10000001); // NOTIFY_END_STREAMING
        drained = true;
        return output.ToArray();
    }

    private void ReadOutput()
    {
        // A broken native transform cannot grow unbounded data or loop forever.
        for (var iteration = 0; iteration < 4096; iteration++)
        {
            nint sample = 0;
            nint buffer = 0;
            var result = new AudioCom.OutputData();
            try
            {
                AudioCom.Check(AudioCom.MFCreateSample(out sample));
                AudioCom.Check(AudioCom.MFCreateAlignedMemoryBuffer(outputBufferSize, outputAlignment, out buffer));
                AudioCom.Check(AudioCom.Method<AudioCom.PointerArgument>(sample, 42)(sample, buffer));
                result.Sample = sample;
                var hr = AudioCom.Method<AudioCom.ProcessOutput>(transform, 25)(transform, 0, 1, ref result, out _);
                if (hr == NeedMoreInput) { return; }
                AudioCom.Check(hr);
                if (result.Sample != sample || (result.Status & 0x100) != 0)
                {
                    throw new AudioCaptureException(ErrorCode.AudioFormatUnsupported);
                }

                AudioCom.Check(AudioCom.Method<AudioCom.LockBuffer>(buffer, 3)(buffer, out var address, out _, out var length));
                try
                {
                    if (length <= 0 || length % 2 != 0 || output.Length + length > 16_000 * 2 * 120 + 2)
                    {
                        throw new AudioCaptureException(ErrorCode.CorruptInput);
                    }

                    var bytes = new byte[length];
                    try
                    {
                        Marshal.Copy(address, bytes, 0, length);
                        output.Write(bytes);
                    }
                    finally { Array.Clear(bytes); }
                }
                finally { AudioCom.Check(AudioCom.Method<AudioCom.NoArgument>(buffer, 4)(buffer)); }
            }
            finally
            {
                if (result.Events != 0) { Marshal.Release(result.Events); }
                if (result.Sample != 0 && result.Sample != sample) { Marshal.Release(result.Sample); }
                if (buffer != 0) { Marshal.Release(buffer); }
                if (sample != 0) { Marshal.Release(sample); }
            }
        }

        throw new AudioCaptureException(ErrorCode.CorruptInput);
    }

    private void SetType(int slot, PcmSourceFormat format)
    {
        AudioCom.Check(AudioCom.MFCreateMediaType(out var mediaType));
        try
        {
            var waveFormat = format.ToWaveFormat();
            AudioCom.Check(AudioCom.MFInitMediaTypeFromWaveFormatEx(mediaType, waveFormat, waveFormat.Length));
            AudioCom.Check(AudioCom.Method<AudioCom.SetMediaType>(transform, slot)(transform, 0, mediaType, 0));
        }
        finally { Marshal.Release(mediaType); }
    }

    private void Message(uint message) => AudioCom.Check(AudioCom.Method<AudioCom.ProcessMessage>(transform, 23)(transform, message, 0));
    private void RequireOwner()
    {
        if (Environment.CurrentManagedThreadId != owner) { throw new InvalidOperationException("MF ownership changed threads."); }
    }

    public void Dispose()
    {
        RequireOwner();
        if (transform != 0) { Marshal.Release(transform); transform = 0; }
        try
        {
            if (started) { AudioCom.Check(AudioCom.MFShutdown()); started = false; }
        }
        finally
        {
            if (comInitialized) { AudioCom.CoUninitialize(); comInitialized = false; }
            if (output.TryGetBuffer(out var bytes)) { Array.Clear(bytes.Array!, bytes.Offset, bytes.Count); }
            output.Dispose();
        }
    }
}

internal static class AudioCom
{
    internal static readonly Guid PcmSubtype = new("00000001-0000-0010-8000-00aa00389b71");
    internal static readonly Guid FloatSubtype = new("00000003-0000-0010-8000-00aa00389b71");
    internal static T Method<T>(nint instance, int slot) where T : Delegate =>
        Marshal.GetDelegateForFunctionPointer<T>(Marshal.ReadIntPtr(Marshal.ReadIntPtr(instance), slot * IntPtr.Size));
    internal static void Check(int hr) { if (hr < 0) { Marshal.ThrowExceptionForHR(hr); } }

    [StructLayout(LayoutKind.Sequential)] internal struct OutputStreamInfo { internal uint Flags; internal uint Size; internal uint Alignment; }
    [StructLayout(LayoutKind.Sequential)] internal struct OutputData { internal uint Stream; internal nint Sample; internal uint Status; internal nint Events; }
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int NoArgument(nint self);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int IntArgument(nint self, int value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int LongArgument(nint self, long value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int PointerArgument(nint self, nint value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int LockBuffer(nint self, out nint buffer, out int maximumLength, out int currentLength);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int SetMediaType(nint self, uint stream, nint type, uint flags);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int ProcessMessage(nint self, uint message, nuint parameter);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int ProcessInput(nint self, uint stream, nint sample, uint flags);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int ProcessOutput(nint self, uint flags, uint count, ref OutputData result, out uint status);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] internal delegate int OutputInfo(nint self, uint stream, out OutputStreamInfo info);
    [DllImport("ole32.dll", ExactSpelling = true)] internal static extern int CoCreateInstance(in Guid clsid, nint outer, uint context, in Guid iid, out nint instance);
    [DllImport("ole32.dll", ExactSpelling = true)] internal static extern int CoInitializeEx(nint reserved, uint flags);
    [DllImport("ole32.dll", ExactSpelling = true)] internal static extern void CoUninitialize();
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFStartup(uint version, uint flags);
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFShutdown();
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFCreateMediaType(out nint type);
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFInitMediaTypeFromWaveFormatEx(nint type, byte[] format, int size);
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFCreateSample(out nint sample);
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFCreateMemoryBuffer(int maximumLength, out nint buffer);
    [DllImport("mfplat.dll", ExactSpelling = true)] internal static extern int MFCreateAlignedMemoryBuffer(int maximumLength, int alignment, out nint buffer);
}
