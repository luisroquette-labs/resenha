using System.Buffers.Binary;

namespace Resenha.Core;

/// <summary>Deterministic energy eligibility, not a speech detector.</summary>
public static class AudioPolicy
{
    public static readonly TimeSpan MinimumCapture = TimeSpan.FromMilliseconds(300);
    public static readonly TimeSpan MinimumActiveDuration = TimeSpan.FromMilliseconds(200);
    public static readonly TimeSpan MaximumHold = TimeSpan.FromSeconds(120);
    public static readonly TimeSpan StartDeadline = TimeSpan.FromSeconds(2);
    public static readonly TimeSpan StopDeadline = TimeSpan.FromSeconds(1);
    public static readonly TimeSpan EnergyFrameDuration = TimeSpan.FromMilliseconds(20);
    public const double EnergyThresholdDbfs = -50;
    public const int SamplesPerEnergyFrame = 320;

    public static AudioEnergySummary AnalyzePcm16(ReadOnlySpan<byte> pcm)
    {
        if (pcm.Length % 2 != 0)
        {
            throw new ArgumentException("PCM16 must contain whole samples.", nameof(pcm));
        }

        double totalSquares = 0;
        double windowSquares = 0;
        long activeFrames = 0;
        var sampleCount = pcm.Length / 2;
        var thresholdSquared = Math.Pow(10, EnergyThresholdDbfs / 10);
        for (var sample = 0; sample < sampleCount; sample++)
        {
            var normalized = BinaryPrimitives.ReadInt16LittleEndian(pcm.Slice(sample * 2, 2)) / 32768.0;
            var square = normalized * normalized;
            totalSquares += square;
            windowSquares += square;
            if ((sample + 1) % SamplesPerEnergyFrame == 0)
            {
                if (windowSquares / SamplesPerEnergyFrame > thresholdSquared)
                {
                    activeFrames++;
                }

                windowSquares = 0;
            }
        }

        // A partial 20 ms window cannot manufacture another active frame.
        var dbfs = totalSquares == 0 ? double.NegativeInfinity : 10 * Math.Log10(totalSquares / sampleCount);
        return new(dbfs, activeFrames, TimeSpan.FromTicks(activeFrames * EnergyFrameDuration.Ticks));
    }

    public static ErrorCode? Check(MonotonicTimestamp pressedAt, MonotonicTimestamp releasedAt,
        long sampleCount, AudioEnergySummary energy)
    {
        if (pressedAt.Ticks < 0 || releasedAt.Ticks < pressedAt.Ticks)
        {
            return ErrorCode.AudioTimestampInvalid;
        }

        var heldTicks = releasedAt.Ticks - pressedAt.Ticks;
        if (heldTicks >= MaximumHold.Ticks)
        {
            return ErrorCode.HoldInterrupted;
        }

        if (sampleCount < AudioDescriptor.SampleRate * MinimumCapture.TotalSeconds ||
            heldTicks < MinimumCapture.Ticks || energy.ActiveDuration < MinimumActiveDuration ||
            energy.FramesAboveThreshold < MinimumActiveDuration.Ticks / EnergyFrameDuration.Ticks)
        {
            return ErrorCode.AudioTooShort;
        }

        if (sampleCount > AudioDescriptor.SampleRate * MaximumHold.TotalSeconds ||
            (decimal)sampleCount * TimeSpan.TicksPerSecond > (decimal)heldTicks * AudioDescriptor.SampleRate ||
            double.IsNaN(energy.RootMeanSquareDbfs) || energy.RootMeanSquareDbfs > 0 ||
            energy.FramesAboveThreshold > sampleCount / SamplesPerEnergyFrame ||
            energy.ActiveDuration.Ticks != energy.FramesAboveThreshold * EnergyFrameDuration.Ticks)
        {
            return ErrorCode.CorruptInput;
        }

        return null;
    }
}
