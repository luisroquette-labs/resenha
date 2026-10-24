using System.Collections.Immutable;
using System.ComponentModel;
using System.Globalization;
using System.Text;
using Resenha.Core;

namespace Resenha.Platform;

public sealed class WhisperCliTranscriber : ITranscriber
{
    public const string UpstreamCommit = "4979e04f5dcaccb36057e059bbaed8a2f5288315";
    public const long ModelBytes = 190085487;
    public const string ModelSha256 = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb";
    public const int MaximumResultBytes = 256 * 1024;
    public const int MaximumResultCharacters = 100_000;
    public static readonly TimeSpan MaximumInferenceTime = TimeSpan.FromSeconds(120);
    private readonly string executable;
    private readonly IClock clock;
    private readonly IChildProcessJob jobs;
    private int active;
    private int terminationUnconfirmed;

    public WhisperCliTranscriber(string installationDirectory, IClock clock, IChildProcessJob? jobs = null)
    {
        if (!Path.IsPathFullyQualified(installationDirectory)) { throw new ArgumentException("An absolute installation directory is required.", nameof(installationDirectory)); }
        executable = Path.Combine(Path.GetFullPath(installationDirectory), "native", "whisper-cli.exe");
        this.clock = clock;
        this.jobs = jobs ?? new ChildProcessJob();
    }

    public static ImmutableArray<string> BuildArguments(string model, string audio, string outputBase, DictationLanguage language, int logicalProcessorCount)
    {
        if (logicalProcessorCount <= 0) { throw new ArgumentOutOfRangeException(nameof(logicalProcessorCount)); }
        return ["--model", model, "--file", audio, "--language", language.ToWhisperCode(),
            "--threads", Math.Min(4, logicalProcessorCount).ToString(CultureInfo.InvariantCulture), "--processors", "1",
            "--no-gpu", "--output-txt", "--output-file", outputBase, "--no-timestamps", "--no-prints",
            "--temperature", "0", "--temperature-inc", "0", "--beam-size", "5", "--no-fallback",
            "--max-context", "0", "--no-speech-thold", "0.6", "--suppress-nst"];
        // Pinned defaults: translate=false, no_context=true. There is no
        // --no-context CLI flag at this pin; max-context=0 additionally prevents
        // text context. A fresh process and no prompt prevent session carryover.
    }

    public async ValueTask<TranscriptResult> TranscribeAsync(AttemptId attempt, AudioLease audio, VerifiedModelLease model,
        DictationLanguage language, MonotonicTimestamp deadline, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (Volatile.Read(ref terminationUnconfirmed) != 0) { throw new ChildProcessTerminationException(); }
        if (Interlocked.CompareExchange(ref active, 1, 0) != 0) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.EngineFailure); }
        try
        {
            if (cancellationToken.IsCancellationRequested) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.Cancelled); }
            audio.RequireUsableBy(attempt);
            model.RequireUsableBy(attempt);
            if (!Enum.IsDefined(language)) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.CorruptInput); }
            if (model.Model.FileName != "ggml-small-q5_1.bin" || model.Model.ByteLength != ModelBytes
                || !string.Equals(model.Model.Sha256, ModelSha256, StringComparison.OrdinalIgnoreCase)
                || !File.Exists(model.OwnedPath) || !IsCanonicalWithoutReparse(model.OwnedPath)) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.CorruptModel); }
            if (!ValidateAudio(audio.Audio)) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.CorruptInput); }
            if (audio.Audio.Duration < TimeSpan.FromMilliseconds(300) || audio.Audio.Energy.ActiveDuration < TimeSpan.FromMilliseconds(200))
            {
                return TranscriptResult.WithoutText(attempt, TranscriptOutcome.Silence);
            }
            var directory = Path.GetDirectoryName(audio.Audio.OwnedPath)!;
            var output = Path.Combine(directory, "result.txt");
            if (!File.Exists(executable) || !IsCanonicalWithoutReparse(executable) || File.Exists(output) || Directory.Exists(output))
            {
                return TranscriptResult.WithoutText(attempt, TranscriptOutcome.EngineFailure);
            }
            var remaining = deadline.ElapsedSince(clock.GetTimestamp());
            if (remaining <= TimeSpan.Zero) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.TimedOut); }
            var timeout = remaining < MaximumInferenceTime ? remaining : MaximumInferenceTime;
            IChildProcessHandle child;
            try
            {
                child = jobs.Start(new(executable, directory, BuildArguments(model.OwnedPath, audio.Audio.OwnedPath,
                    Path.Combine(directory, "result"), language, Environment.ProcessorCount)));
            }
            catch (Exception error) when (error is Win32Exception or IOException or UnauthorizedAccessException or PlatformNotSupportedException)
            {
                return TranscriptResult.WithoutText(attempt, TranscriptOutcome.EngineFailure);
            }

            var confirmed = false;
            try
            {
                // WaitForExitAsync itself enforces the real wall-clock deadline;
                // polling also terminates output growth before reading any text.
                var wait = child.WaitForExitAsync(timeout, cancellationToken).AsTask();
                var oversized = false;
                while (!wait.IsCompleted)
                {
                    try
                    {
                        oversized = File.Exists(output) && (new FileInfo(output).Length > MaximumResultBytes || !IsCanonicalWithoutReparse(output));
                    }
                    catch (IOException) { oversized = true; }
                    catch (UnauthorizedAccessException) { oversized = true; }
                    if (oversized) { await child.TerminateAsync().ConfigureAwait(false); break; }
                    await Task.WhenAny(wait, Task.Delay(20, CancellationToken.None)).ConfigureAwait(false);
                }
                var exit = await wait.ConfigureAwait(false);
                confirmed = true;
                if (cancellationToken.IsCancellationRequested || exit.Outcome == ChildProcessExit.Cancelled)
                {
                    return TranscriptResult.WithoutText(attempt, oversized ? TranscriptOutcome.EngineFailure : TranscriptOutcome.Cancelled);
                }
                if (exit.Outcome == ChildProcessExit.TimedOut || clock.GetTimestamp().Ticks >= deadline.Ticks)
                {
                    return TranscriptResult.WithoutText(attempt, TranscriptOutcome.TimedOut);
                }
                if (oversized || exit.ExitCode != 0) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.EngineFailure); }
                try
                {
                    var text = await ReadResultAsync(output, cancellationToken).ConfigureAwait(false);
                    if (cancellationToken.IsCancellationRequested) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.Cancelled); }
                    if (clock.GetTimestamp().Ticks >= deadline.Ticks) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.TimedOut); }
                    return string.IsNullOrWhiteSpace(text) ? TranscriptResult.WithoutText(attempt, TranscriptOutcome.Silence) : TranscriptResult.Completed(attempt, text);
                }
                catch (OperationCanceledException) { return TranscriptResult.WithoutText(attempt, TranscriptOutcome.Cancelled); }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException or DecoderFallbackException or InvalidDataException)
                {
                    return TranscriptResult.WithoutText(attempt, TranscriptOutcome.EngineFailure);
                }
            }
            finally
            {
                // Dispose also reaps if an unexpected exception interrupted the
                // wait. If it cannot confirm termination it throws and no owned
                // output is deleted. Audio/model leases remain caller-owned.
                await child.DisposeAsync().ConfigureAwait(false);
                if (confirmed && File.Exists(output))
                {
                    if (!IsCanonicalWithoutReparse(output)) { throw new IOException("Unsafe inference output; session cleanup is required."); }
                    File.Delete(output); // Failure deliberately stays observable.
                }
            }
        }
        catch (ChildProcessTerminationException)
        {
            Volatile.Write(ref terminationUnconfirmed, 1);
            throw;
        }
        finally { Volatile.Write(ref active, 0); }
    }

    public static async ValueTask<string> ReadResultAsync(string path, CancellationToken cancellationToken)
    {
        if (!IsCanonicalWithoutReparse(path)) { throw new InvalidDataException("Unsafe inference output."); }
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.Asynchronous);
        if (stream.Length > MaximumResultBytes) { throw new InvalidDataException("Inference output exceeds its byte limit."); }
        var bytes = new byte[checked((int)stream.Length)];
        await stream.ReadExactlyAsync(bytes, cancellationToken).ConfigureAwait(false);
        var offset = bytes.AsSpan().StartsWith(new byte[] { 0xEF, 0xBB, 0xBF }) ? 3 : 0;
        var text = new UTF8Encoding(false, true).GetString(bytes, offset, bytes.Length - offset);
        if (text.Length > MaximumResultCharacters || text.Any(character => char.IsControl(character) && character is not '\r' and not '\n' and not '\t'))
        {
            throw new InvalidDataException("Invalid inference text.");
        }
        return text;
    }

    private static bool ValidateAudio(AudioDescriptor audio)
    {
        if (!IsCanonicalWithoutReparse(audio.OwnedPath) || Path.GetFileName(audio.OwnedPath) != "input.wav"
            || !Guid.TryParse(Path.GetFileName(Path.GetDirectoryName(audio.OwnedPath)), out var id) || id != audio.Attempt.Value
            || audio.FrameCount <= 0 || audio.FrameCount > 120L * AudioDescriptor.SampleRate
            || audio.Duration != TimeSpan.FromTicks(audio.FrameCount * TimeSpan.TicksPerSecond / AudioDescriptor.SampleRate)
            || double.IsNaN(audio.Energy.RootMeanSquareDbfs) || audio.Energy.RootMeanSquareDbfs > 0 || audio.Energy.ActiveDuration < TimeSpan.Zero
            || audio.Energy.ActiveDuration > audio.Duration || audio.Energy.FramesAboveThreshold < 0
            || audio.Energy.ActiveDuration.Ticks != audio.Energy.FramesAboveThreshold * TimeSpan.FromMilliseconds(20).Ticks) { return false; }
        try
        {
            using var stream = File.OpenRead(audio.OwnedPath);
            using var reader = new BinaryReader(stream, Encoding.ASCII, false);
            if (stream.Length < 44 || new string(reader.ReadChars(4)) != "RIFF" || reader.ReadUInt32() != stream.Length - 8
                || new string(reader.ReadChars(4)) != "WAVE") { return false; }
            var formatFound = false;
            var dataFound = false;
            while (stream.Position + 8 <= stream.Length)
            {
                var name = new string(reader.ReadChars(4));
                var length = reader.ReadUInt32();
                var next = stream.Position + length + (length & 1);
                if (next > stream.Length) { return false; }
                if (name == "fmt ")
                {
                    if (formatFound || length < 16 || reader.ReadUInt16() != 1 || reader.ReadUInt16() != 1 || reader.ReadUInt32() != 16000
                        || reader.ReadUInt32() != 32000 || reader.ReadUInt16() != 2 || reader.ReadUInt16() != 16) { return false; }
                    formatFound = true;
                }
                else if (name == "data")
                {
                    if (dataFound || length != audio.FrameCount * 2) { return false; }
                    dataFound = true;
                }
                stream.Position = next;
            }
            return formatFound && dataFound && stream.Position == stream.Length;
        }
        catch (IOException) { return false; }
        catch (UnauthorizedAccessException) { return false; }
    }

    private static bool IsCanonicalWithoutReparse(string path)
    {
        if (!Path.IsPathFullyQualified(path) || !string.Equals(path, Path.GetFullPath(path), StringComparison.OrdinalIgnoreCase)) { return false; }
        try
        {
            for (var current = path; current is not null; current = Path.GetDirectoryName(current))
            {
                if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) { return false; }
            }
            return true;
        }
        catch (IOException) { return false; }
        catch (UnauthorizedAccessException) { return false; }
    }
}
