using System.Collections.Immutable;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class ModelProcessTests
{
    [TestMethod]
    public void ExactArgumentContractUsesOnlyPinnedFlagsAndExplicitLanguage()
    {
        foreach (var language in Enum.GetValues<DictationLanguage>())
        {
            var arguments = WhisperCliTranscriber.BuildArguments("model.bin", "input.wav", "result", language, 16);
            CollectionAssert.AreEqual(new[] { "--model", "model.bin", "--file", "input.wav", "--language", language.ToWhisperCode(),
                "--threads", "4", "--processors", "1", "--no-gpu", "--output-txt", "--output-file", "result", "--no-timestamps", "--no-prints",
                "--temperature", "0", "--temperature-inc", "0", "--beam-size", "5", "--no-fallback", "--max-context", "0", "--no-speech-thold", "0.6", "--suppress-nst" }, arguments.ToArray());
        }
        Assert.AreEqual("1", WhisperCliTranscriber.BuildArguments("m", "a", "o", DictationLanguage.Pt, 1)[7]);
        Assert.Throws<ArgumentOutOfRangeException>(() => WhisperCliTranscriber.BuildArguments("m", "a", "o", (DictationLanguage)100, 4));
    }

    [TestMethod]
    public void CommandLinePreservesSpacesUnicodeQuotesAndTrailingBackslashesWithoutShell()
    {
        var specification = new ChildProcessSpec(@"C:\Resenha João\native\whisper-cli.exe", @"C:\owned", ["", "pt", "a\"b", "end\\", "$(touch bad)&|%PATH%"]);
        Assert.AreEqual("\"C:\\Resenha João\\native\\whisper-cli.exe\" \"\" \"pt\" \"a\\\"b\" \"end\\\\\" \"$(touch bad)&|%PATH%\"", ChildProcessJob.BuildCommandLine(specification));
        Assert.Throws<ArgumentException>(() => ChildProcessJob.BuildCommandLine(specification with { Arguments = ["bad\0argument"] }));
    }

    [TestMethod]
    public void NativePresetRetainsCpuBaselineAndTwoWorkerLimit()
    {
        using var preset = JsonDocument.Parse(File.ReadAllText(Path.Combine(FindRepository(), "Windows/native/CMakePresets.json")));
        var root = preset.RootElement;
        Assert.AreEqual(2, root.GetProperty("buildPresets")[0].GetProperty("jobs").GetInt32());
        var cache = root.GetProperty("configurePresets")[0].GetProperty("cacheVariables");
        Assert.AreEqual("NEW", cache.GetProperty("CMAKE_POLICY_DEFAULT_CMP0091").GetString());
        Assert.AreEqual("MultiThreaded$<$<CONFIG:Debug>:Debug>", cache.GetProperty("CMAKE_MSVC_RUNTIME_LIBRARY").GetString());
        foreach (var name in new[] { "GGML_CPU", "GGML_AVX", "GGML_AVX2", "GGML_SSE42", "GGML_STATIC" }) { Assert.AreEqual("ON", cache.GetProperty(name).GetString()); }
        foreach (var name in new[] { "BUILD_SHARED_LIBS", "GGML_NATIVE", "GGML_OPENMP", "GGML_BLAS", "GGML_CUDA", "GGML_MUSA", "GGML_HIP", "GGML_VULKAN", "GGML_WEBGPU", "GGML_METAL", "GGML_RPC", "GGML_SYCL", "GGML_OPENCL", "GGML_ZDNN", "GGML_BMI2", "GGML_AVX_VNNI", "GGML_AVX512", "GGML_AVX512_VBMI", "GGML_AVX512_VNNI", "GGML_AVX512_BF16", "WHISPER_CURL", "WHISPER_BUILD_SERVER" }) { Assert.AreEqual("OFF", cache.GetProperty(name).GetString()); }
        StringAssert.Contains(File.ReadAllText(Path.Combine(FindRepository(), "Windows/native/CMakeLists.txt")), WhisperCliTranscriber.UpstreamCommit);
    }

    [TestMethod]
    public async Task SuccessReadsOnlyAfterConfirmedExitAndCleansOnlyItsOutput()
    {
        using var fixture = new InferenceFixture();
        fixture.Process.Text = "  Reunião sobre o feedback.\n";
        var result = await fixture.Run();
        Assert.AreEqual(TranscriptOutcome.Text, result.Outcome);
        Assert.AreEqual(fixture.Process.Text, result.Text);
        Assert.IsTrue(fixture.Process.Disposed);
        Assert.IsFalse(File.Exists(fixture.Output));
        Assert.IsTrue(File.Exists(fixture.Audio.Audio.OwnedPath));
        Assert.AreEqual(0, fixture.Audio.DisposalCount);
        Assert.AreEqual(0, fixture.Model.DisposalCount);
        Assert.AreEqual(TimeSpan.FromSeconds(120), fixture.Process.Timeout);
    }

    [TestMethod]
    public async Task CrashMissingMalformedOversizeAndControlTextFailWithoutTranscript()
    {
        foreach (var mode in new[] { "crash", "missing", "utf8", "bytes", "characters", "control" })
        {
            using var fixture = new InferenceFixture();
            fixture.Process.Mode = mode;
            var result = await fixture.Run();
            Assert.AreEqual(TranscriptOutcome.EngineFailure, result.Outcome, mode);
            Assert.IsNull(result.Text);
            Assert.IsFalse(File.Exists(fixture.Output));
        }
    }

    [TestMethod]
    public async Task CancellationTimeoutAndLateResultsNeverProduceText()
    {
        foreach (var outcome in new[] { ChildProcessExit.Cancelled, ChildProcessExit.TimedOut })
        {
            using var fixture = new InferenceFixture();
            fixture.Process.Exit = outcome;
            Assert.AreEqual(outcome == ChildProcessExit.Cancelled ? TranscriptOutcome.Cancelled : TranscriptOutcome.TimedOut, (await fixture.Run()).Outcome);
            Assert.IsFalse(File.Exists(fixture.Output));
        }
        using var late = new InferenceFixture();
        using var cancel = new CancellationTokenSource();
        late.Process.OnExit = cancel.Cancel;
        Assert.AreEqual(TranscriptOutcome.Cancelled, (await late.Run(cancel.Token)).Outcome);
    }

    [TestMethod]
    public async Task UnconfirmedTerminationRetainsOutputAndLeases()
    {
        using var fixture = new InferenceFixture();
        fixture.Process.Unconfirmed = true;
        await Assert.ThrowsAsync<ChildProcessTerminationException>(() => fixture.Run().AsTask());
        Assert.IsTrue(File.Exists(fixture.Output));
        Assert.AreEqual(0, fixture.Audio.DisposalCount);
        Assert.AreEqual(0, fixture.Model.DisposalCount);
        fixture.Process.Unconfirmed = false;
        await Assert.ThrowsAsync<ChildProcessTerminationException>(() => fixture.Run().AsTask());
        Assert.AreEqual(1, fixture.Process.StartCount);
    }

    [TestMethod]
    public async Task GrowingOversizedOutputTerminatesBeforeReading()
    {
        using var fixture = new InferenceFixture();
        fixture.Process.Mode = "bytes";
        fixture.Process.HoldUntilTerminated = true;
        Assert.AreEqual(TranscriptOutcome.EngineFailure, (await fixture.Run()).Outcome);
        Assert.IsTrue(fixture.Process.Terminated);
        Assert.IsTrue(fixture.Process.Disposed);
        Assert.IsFalse(File.Exists(fixture.Output));
    }

    [TestMethod]
    public async Task BusyTranscriberDoesNotLaunchAnotherProcess()
    {
        using var fixture = new InferenceFixture();
        fixture.Process.HoldUntilTerminated = true;
        var first = fixture.Run().AsTask();
        Assert.AreEqual(TranscriptOutcome.EngineFailure, (await fixture.Run()).Outcome);
        Assert.AreEqual(1, fixture.Process.StartCount);
        await fixture.Process.TerminateAsync();
        Assert.AreEqual(TranscriptOutcome.Cancelled, (await first).Outcome);
    }

    [TestMethod]
    public async Task StaleOutputAndCorruptInputNeverLaunch()
    {
        using var stale = new InferenceFixture();
        File.WriteAllText(stale.Output, "old result");
        Assert.AreEqual(TranscriptOutcome.EngineFailure, (await stale.Run()).Outcome);
        Assert.AreEqual(0, stale.Process.StartCount);
        Assert.AreEqual("old result", File.ReadAllText(stale.Output));
        using var corrupt = new InferenceFixture();
        File.WriteAllText(corrupt.Audio.Audio.OwnedPath, "invalid WAV");
        Assert.AreEqual(TranscriptOutcome.CorruptInput, (await corrupt.Run()).Outcome);
        Assert.AreEqual(0, corrupt.Process.StartCount);
    }

    [TestMethod]
    public async Task ExpiredDeadlineAndSilenceNeverLaunch()
    {
        using var fixture = new InferenceFixture();
        Assert.AreEqual(TranscriptOutcome.TimedOut, (await fixture.Transcriber.TranscribeAsync(fixture.Attempt, fixture.Audio, fixture.Model, DictationLanguage.Pt, new(0), CancellationToken.None)).Outcome);
        await using var silent = new TestAudioLease(fixture.Audio.Audio with { Energy = new(double.NegativeInfinity, 0, TimeSpan.Zero) });
        Assert.AreEqual(TranscriptOutcome.Silence, (await fixture.Transcriber.TranscribeAsync(fixture.Attempt, silent, fixture.Model, DictationLanguage.Pt, new(TimeSpan.FromSeconds(120).Ticks), CancellationToken.None)).Outcome);
        Assert.AreEqual(0, fixture.Process.StartCount);
    }

    [TestMethod]
    public async Task EarlierDeadlineCapsProcessWait()
    {
        using var fixture = new InferenceFixture();
        await fixture.Transcriber.TranscribeAsync(fixture.Attempt, fixture.Audio, fixture.Model, DictationLanguage.Pt, new(TimeSpan.FromSeconds(3).Ticks), CancellationToken.None);
        Assert.AreEqual(TimeSpan.FromSeconds(3), fixture.Process.Timeout);
    }

    [TestMethod]
    public async Task FractionalSecondAudioUsesExactPcmFrameDuration()
    {
        using var fixture = new InferenceFixture(15999);
        Assert.AreEqual(TranscriptOutcome.Text, (await fixture.Run()).Outcome);
    }

    internal static string FindRepository()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "Windows/toolchain-lock.json"))) { return directory.FullName; }
        }
        throw new DirectoryNotFoundException("The repository fixtures are required.");
    }

    private sealed class InferenceFixture : IDisposable
    {
        private readonly string root = Path.Combine(AppContext.BaseDirectory, "step08-" + Guid.NewGuid().ToString("N"));
        internal AttemptId Attempt { get; } = AttemptId.New();
        internal TestAudioLease Audio { get; }
        internal TestModelLease Model { get; }
        internal FakeProcess Process { get; } = new();
        internal WhisperCliTranscriber Transcriber { get; }
        internal string Output => Path.Combine(Path.GetDirectoryName(Audio.Audio.OwnedPath)!, "result.txt");
        internal InferenceFixture(int frames = 16000)
        {
            var session = Path.Combine(root, Attempt.Value.ToString("D"));
            Directory.CreateDirectory(session);
            Directory.CreateDirectory(Path.Combine(root, "native"));
            File.WriteAllBytes(Path.Combine(root, "native/whisper-cli.exe"), []);
            var model = Path.Combine(root, "ggml-small-q5_1.bin");
            File.WriteAllBytes(model, []); // Fake verified lease, never engine evidence.
            var audio = Path.Combine(session, "input.wav");
            WriteWave(audio, frames);
            var duration = TimeSpan.FromTicks((long)frames * TimeSpan.TicksPerSecond / 16000);
            var activeFrames = frames / 320;
            Audio = new(new(Attempt, audio, frames, duration, new(-20, activeFrames, TimeSpan.FromMilliseconds(activeFrames * 20)), new(0), new(duration.Ticks)));
            Model = new(Attempt, new("ggml-small-q5_1.bin", WhisperCliTranscriber.ModelBytes, WhisperCliTranscriber.ModelSha256), model);
            Transcriber = new(root, new ManualClock(), Process);
        }
        internal ValueTask<TranscriptResult> Run(CancellationToken token = default) => Transcriber.TranscribeAsync(Attempt, Audio, Model, DictationLanguage.Pt, new(TimeSpan.FromSeconds(120).Ticks), token);
        public void Dispose() => Directory.Delete(root, true);
        private static void WriteWave(string path, int frames)
        {
            using var writer = new BinaryWriter(File.Create(path));
            writer.Write("RIFF"u8); writer.Write(frames * 2 + 36); writer.Write("WAVEfmt "u8); writer.Write(16);
            writer.Write((short)1); writer.Write((short)1); writer.Write(16000); writer.Write(32000); writer.Write((short)2); writer.Write((short)16);
            writer.Write("data"u8); writer.Write(frames * 2); writer.Write(new byte[frames * 2]);
        }
    }

    private sealed class FakeProcess : IChildProcessJob, IChildProcessHandle
    {
        public uint ProcessId => 1;
        internal string Text { get; set; } = "texto";
        internal string Mode { get; set; } = "valid";
        internal bool Unconfirmed { get; set; }
        internal bool HoldUntilTerminated { get; set; }
        internal bool Terminated { get; private set; }
        internal bool Disposed { get; private set; }
        internal int StartCount { get; private set; }
        internal ChildProcessExit Exit { get; set; } = ChildProcessExit.Exited;
        internal TimeSpan Timeout { get; private set; }
        internal Action? OnExit { get; set; }
        private string output = "";
        private readonly TaskCompletionSource<ChildProcessResult> completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public IChildProcessHandle Start(ChildProcessSpec specification)
        {
            StartCount++;
            output = Path.Combine(specification.WorkingDirectory, "result.txt");
            return this;
        }
        public ValueTask<ChildProcessResult> WaitForExitAsync(TimeSpan timeout, CancellationToken cancellationToken)
        {
            Timeout = timeout;
            if (Mode != "missing")
            {
                File.WriteAllBytes(output, Mode switch
                {
                    "utf8" => [0xC3, 0x28],
                    "bytes" => new byte[WhisperCliTranscriber.MaximumResultBytes + 1],
                    "characters" => Encoding.UTF8.GetBytes(new string('a', WhisperCliTranscriber.MaximumResultCharacters + 1)),
                    "control" => Encoding.UTF8.GetBytes("bad\0text"),
                    _ => Encoding.UTF8.GetBytes(Text)
                });
            }
            OnExit?.Invoke();
            if (HoldUntilTerminated) { return new(completion.Task); }
            return Unconfirmed ? ValueTask.FromException<ChildProcessResult>(new ChildProcessTerminationException()) : ValueTask.FromResult(new ChildProcessResult(Exit, Mode == "crash" ? 9 : 0));
        }
        public ValueTask TerminateAsync()
        {
            Terminated = true;
            completion.TrySetResult(new(ChildProcessExit.Cancelled, 1));
            return ValueTask.CompletedTask;
        }
        public ValueTask DisposeAsync()
        {
            Disposed = true;
            return Unconfirmed ? ValueTask.FromException(new ChildProcessTerminationException()) : ValueTask.CompletedTask;
        }
    }
}

[TestClass]
[TestCategory("WindowsIntegration")]
public sealed class NativeChildProcessTests
{
    [TestMethod]
    public void PinnedSourceDefinesEveryCliOptionAndNoContextNoTranslationDefaults()
    {
        var upstream = Path.Combine(ModelProcessTests.FindRepository(), "Vendor/whisper.cpp");
        Assert.IsTrue(File.Exists(Path.Combine(upstream, "examples/cli/cli.cpp")), "Initialize the existing pinned source before native integration tests.");
        var source = File.ReadAllText(Path.Combine(upstream, "examples/cli/cli.cpp"));
        foreach (var option in WhisperCliTranscriber.BuildArguments("m", "a", "o", DictationLanguage.Pt, 4).Where(value => value.StartsWith("--", StringComparison.Ordinal)))
        {
            StringAssert.Contains(source, "arg == \"" + option + "\"");
        }
        StringAssert.Contains(source, "bool translate       = false;");
        StringAssert.Contains(File.ReadAllText(Path.Combine(upstream, "src/whisper.cpp")), "/*.no_context        =*/ true,");
    }

    [TestMethod]
    public async Task ParentExitKillsAndConfirmsItsOrphanDescendant()
    {
        Assert.IsTrue(OperatingSystem.IsWindows(), "An authorized Windows host is required; this test must not be skipped.");
        var executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell/v1.0/powershell.exe");
        var marker = Path.Combine(AppContext.BaseDirectory, "orphan-" + Guid.NewGuid().ToString("N") + ".pid");
        var script = "$p = Start-Process -FilePath '" + executable.Replace("'", "''", StringComparison.Ordinal)
            + "' -ArgumentList '-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60' -PassThru; [IO.File]::WriteAllText('"
            + marker.Replace("'", "''", StringComparison.Ordinal) + "', [string]$p.Id); exit 0";
        try
        {
            await using var parent = new ChildProcessJob().Start(new(executable, AppContext.BaseDirectory, ["-NoProfile", "-NonInteractive", "-Command", script]));
            Assert.AreEqual(0, (await parent.WaitForExitAsync(TimeSpan.FromSeconds(20), CancellationToken.None)).ExitCode);
            Assert.IsTrue(File.Exists(marker), "The controlled child did not start; this is not orphan-containment evidence.");
            var id = int.Parse(await File.ReadAllTextAsync(marker), System.Globalization.CultureInfo.InvariantCulture);
            try { using var orphan = Process.GetProcessById(id); Assert.IsTrue(orphan.HasExited, "A descendant survived the parent job."); }
            catch (ArgumentException) { /* Windows has already removed the exited PID. */ }
        }
        finally { if (File.Exists(marker)) { File.Delete(marker); } }
    }

    [TestMethod]
    public async Task RealWindowsJobReturnsCrashCodeAndConfirmsCancellation()
    {
        Assert.IsTrue(OperatingSystem.IsWindows(), "An authorized Windows host is required; this test must not be skipped.");
        var executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell/v1.0/powershell.exe");
        var factory = new ChildProcessJob();
        await using (var crashed = factory.Start(new(executable, AppContext.BaseDirectory, ["-NoProfile", "-NonInteractive", "-Command", "exit 17"])))
        {
            var result = await crashed.WaitForExitAsync(TimeSpan.FromSeconds(20), CancellationToken.None);
            Assert.AreEqual(ChildProcessExit.Exited, result.Outcome);
            Assert.AreEqual(17, result.ExitCode);
        }
        using var cancel = new CancellationTokenSource();
        await using var sleeping = factory.Start(new(executable, AppContext.BaseDirectory, ["-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 60"]));
        cancel.Cancel();
        var timer = Stopwatch.StartNew();
        Assert.AreEqual(ChildProcessExit.Cancelled, (await sleeping.WaitForExitAsync(TimeSpan.FromSeconds(120), cancel.Token)).Outcome);
        Assert.IsTrue(timer.Elapsed < TimeSpan.FromSeconds(3), "The two-second termination contract needs Windows investigation.");
    }
}
