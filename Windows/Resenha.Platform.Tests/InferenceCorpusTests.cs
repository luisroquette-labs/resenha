using System.Diagnostics;
using System.Globalization;
using System.Net.NetworkInformation;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;

namespace Resenha.Platform.Tests;

internal static class CorpusScoring
{
    internal static string[] Words(string text)
    {
        var normalized = new StringBuilder();
        foreach (var rune in text.Normalize(NormalizationForm.FormC).ToLowerInvariant().EnumerateRunes())
        {
            var category = Rune.GetUnicodeCategory(rune);
            normalized.Append(Rune.IsLetterOrDigit(rune) || category is UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark
                ? rune.ToString() : " ");
        }
        return normalized.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries);
    }

    internal static (int Errors, int Words) WordError(string reference, string actual)
    {
        var expected = Words(reference);
        var hypothesis = Words(actual);
        var row = Enumerable.Range(0, hypothesis.Length + 1).ToArray();
        for (var i = 1; i <= expected.Length; i++)
        {
            var diagonal = row[0];
            row[0] = i;
            for (var j = 1; j <= hypothesis.Length; j++)
            {
                var prior = row[j];
                row[j] = Math.Min(Math.Min(row[j] + 1, row[j - 1] + 1), diagonal + (expected[i - 1] == hypothesis[j - 1] ? 0 : 1));
                diagonal = prior;
            }
        }
        return (row[^1], expected.Length);
    }

    internal static (int Retained, int Expected) Anglicisms(string reference, string actual, IEnumerable<string> annotations)
    {
        var expectedWords = Words(reference);
        var actualWords = Words(actual);
        var retained = 0;
        var total = 0;
        foreach (var annotation in annotations.GroupBy(value => string.Join(' ', Words(value)), StringComparer.Ordinal))
        {
            var phrase = Words(annotation.Key);
            var expected = annotation.Count();
            if (phrase.Length == 0 || Count(expectedWords, phrase) != expected) { throw new InvalidDataException("Annotate every reference occurrence exactly once."); }
            total += expected;
            retained += Math.Min(expected, Count(actualWords, phrase));
        }
        return (retained, total);
    }

    private static int Count(string[] words, string[] phrase)
    {
        var count = 0;
        for (var i = 0; i <= words.Length - phrase.Length; i++)
        {
            if (words.AsSpan(i, phrase.Length).SequenceEqual(phrase)) { count++; }
        }
        return count;
    }
}

[TestClass]
[TestCategory("Portable")]
public sealed class CorpusScoringTests
{
    [TestMethod]
    public void NormalizationPreservesAccentNumberAndWordErrors()
    {
        Assert.AreEqual((0, 3), CorpusScoring.WordError("Olá, JOÃO! 123.", "ola\u0301 joa\u0303o 123"));
        Assert.AreEqual((3, 3), CorpusScoring.WordError("Olá João 123", "ola Joao 124"));
        Assert.AreEqual((2, 3), CorpusScoring.WordError("um dois três", "um extra quatro três"));
        Assert.AreEqual((2, 2), CorpusScoring.WordError("software feedback", "programa comentários"));
        Assert.AreEqual((1, 0), CorpusScoring.WordError("", "hallucination"));
    }

    [TestMethod]
    public void RetentionCountsOccurrencesWithoutTranslationOrSubstringMatches()
    {
        Assert.AreEqual((1, 2), CorpusScoring.Anglicisms("feedback e feedback", "feedback", ["feedback", "feedback"]));
        Assert.AreEqual((0, 1), CorpusScoring.Anglicisms("o roadmap", "os roadmaps", ["roadmap"]));
        Assert.AreEqual((0, 1), CorpusScoring.Anglicisms("o backup", "a cópia de segurança", ["backup"]));
        Assert.Throws<InvalidDataException>(() => CorpusScoring.Anglicisms("feedback feedback", "feedback", ["feedback"]));
    }

    [TestMethod]
    public void ProspectiveCorpusHasFiveImmutableReferencesPerLanguageAndExplicitBlocker()
    {
        using var manifest = JsonDocument.Parse(File.ReadAllText(Path.Combine(ModelProcessTests.FindRepository(), "Windows/Fixtures/speech-corpus.json")));
        var utterances = manifest.RootElement.GetProperty("utterances").EnumerateArray().ToArray();
        var requirements = manifest.RootElement.GetProperty("requirements");
        Assert.AreEqual(0.2, requirements.GetProperty("maximumWerPerLanguage").GetDouble());
        Assert.AreEqual(0.9, requirements.GetProperty("minimumAnglicismRetentionPerMixedLanguage").GetDouble());
        foreach (var language in new[] { "pt", "en", "es" })
        {
            Assert.IsTrue(utterances.Count(item => item.GetProperty("language").GetString() == language && item.GetProperty("reference").GetString()!.Length > 0) >= 5);
        }
        foreach (var item in utterances.Where(item => item.GetProperty("reference").GetString()!.Length > 0))
        {
            var reference = item.GetProperty("reference").GetString()!;
            var counts = CorpusScoring.Anglicisms(reference, reference, item.GetProperty("anglicisms").EnumerateArray().Select(value => value.GetString()!));
            Assert.AreEqual(counts.Expected, counts.Retained);
        }
        Assert.AreEqual(1, utterances.Count(item => item.GetProperty("id").GetString() == "silence" && item.GetProperty("reference").GetString() == ""));
        if (utterances.Any(item => item.GetProperty("sha256").ValueKind == JsonValueKind.Null || item.GetProperty("rights").ValueKind == JsonValueKind.Null))
        {
            Assert.AreEqual("blocked-missing-owned-or-licensed-recordings", manifest.RootElement.GetProperty("status").GetString());
            Assert.AreEqual(JsonValueKind.Null, manifest.RootElement.GetProperty("measurement").ValueKind);
        }
    }
}

[TestClass]
[TestCategory("WindowsIntegration")]
public sealed class InferenceCorpusTests
{
    public TestContext TestContext { get; set; } = null!;

    [TestMethod]
    public async Task RealOfflineEngineMeetsCommittedMultilingualCorpus()
    {
        Assert.IsTrue(OperatingSystem.IsWindows(), "Missing prerequisite: authorized physical Windows execution; never skip or substitute mocked accuracy.");
        Assert.IsFalse(NetworkInterface.GetAllNetworkInterfaces().Any(adapter => adapter.OperationalStatus == OperationalStatus.Up && adapter.NetworkInterfaceType != NetworkInterfaceType.Loopback), "Disable network adapters before the real offline corpus measurement.");
        var repository = ModelProcessTests.FindRepository();
        var fixtureRoot = Path.Combine(repository, "Windows/Fixtures");
        var manifestPath = Path.Combine(fixtureRoot, "speech-corpus.json");
        using var document = JsonDocument.Parse(await File.ReadAllTextAsync(manifestPath, TestContext.CancellationToken));
        var manifest = document.RootElement;
        Assert.AreEqual("ready", manifest.GetProperty("status").GetString(), "Missing prerequisite: owned/licensed audio and pinned hashes. No accuracy result exists.");
        await RequireCommitted(repository, "Windows/Fixtures/speech-corpus.json");
        await RequireCommitted(repository, "Windows/Fixtures/LICENSE.md");
        var installation = Environment.GetEnvironmentVariable("RESENHA_CORPUS_INSTALL_DIRECTORY");
        var modelPath = Environment.GetEnvironmentVariable("RESENHA_CORPUS_MODEL");
        Assert.IsFalse(string.IsNullOrWhiteSpace(installation), "Set RESENHA_CORPUS_INSTALL_DIRECTORY to the bundled Windows candidate.");
        Assert.IsFalse(string.IsNullOrWhiteSpace(modelPath), "Set RESENHA_CORPUS_MODEL to the verified multilingual model.");
        installation = Path.GetFullPath(installation!);
        modelPath = Path.GetFullPath(modelPath!);
        var cli = Path.Combine(installation, "native/whisper-cli.exe");
        Assert.IsTrue(File.Exists(cli), "The bundled pinned Windows CLI is required.");
        Assert.IsTrue(File.Exists(modelPath), "The pinned model is required.");
        TestContext.WriteLine("sourceSha=" + await Git(repository, ["rev-parse", "HEAD"]));
        TestContext.WriteLine("whisperCommit=" + WhisperCliTranscriber.UpstreamCommit);
        TestContext.WriteLine("cliSha256=" + Convert.ToHexStringLower(SHA256.HashData(await File.ReadAllBytesAsync(cli, TestContext.CancellationToken))));
        TestContext.WriteLine("corpusSha256=" + Convert.ToHexStringLower(SHA256.HashData(await File.ReadAllBytesAsync(manifestPath, TestContext.CancellationToken))));
        TestContext.WriteLine("modelSha256=" + WhisperCliTranscriber.ModelSha256);
        await using var verifiedModel = new FileStream(modelPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        Assert.AreEqual(WhisperCliTranscriber.ModelBytes, verifiedModel.Length);
        Assert.AreEqual(WhisperCliTranscriber.ModelSha256, Convert.ToHexStringLower(await SHA256.HashDataAsync(verifiedModel, TestContext.CancellationToken)));
        var totals = new Dictionary<string, (int Errors, int Words, int Retained, int Annotated)>();
        var utterances = manifest.GetProperty("utterances").EnumerateArray().ToArray();
        foreach (var language in new[] { "pt", "en", "es" })
        {
            Assert.IsTrue(utterances.Count(item => item.GetProperty("language").GetString() == language && item.GetProperty("reference").GetString()!.Length > 0) >= 5);
        }
        Assert.IsTrue(utterances.Any(item => item.GetProperty("id").GetString() == "silence"));
        foreach (var item in utterances)
        {
            var relative = item.GetProperty("file").GetString()!;
            var audio = Path.GetFullPath(Path.Combine(fixtureRoot, relative));
            Assert.IsTrue(audio.StartsWith(fixtureRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase));
            Assert.IsTrue(File.Exists(audio), $"Missing licensed fixture: {relative}");
            var rights = item.GetProperty("rights");
            Assert.AreEqual(JsonValueKind.Object, rights.ValueKind, $"Missing ownership/license: {relative}");
            foreach (var field in new[] { "owner", "license", "source", "permissionReference" }) { Assert.IsFalse(string.IsNullOrWhiteSpace(rights.GetProperty(field).GetString()), $"Missing {field}: {relative}"); }
            await RequireCommitted(repository, "Windows/Fixtures/" + relative);
            var bytes = await File.ReadAllBytesAsync(audio, TestContext.CancellationToken);
            Assert.AreEqual(item.GetProperty("sha256").GetString(), Convert.ToHexStringLower(SHA256.HashData(bytes)));
            RequirePcmFixture(bytes, item.GetProperty("id").GetString() == "silence");
            var language = item.GetProperty("language").GetString()!;
            var selected = language switch { "pt" => DictationLanguage.Pt, "en" => DictationLanguage.En, "es" => DictationLanguage.Es, _ => throw new InvalidDataException("Unknown corpus language.") };
            // Run the real engine even for silence, independently of the app's
            // earlier energy gate. That prevents silence policy from masking a
            // fabricated CLI result in this quality measurement.
            var session = Path.Combine(installation, "corpus-session-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(session);
            var safeToDelete = false;
            string transcript;
            try
            {
                await using (var child = new ChildProcessJob().Start(new(cli, session, WhisperCliTranscriber.BuildArguments(modelPath, audio, Path.Combine(session, "result"), selected, Environment.ProcessorCount))))
                {
                    var result = await child.WaitForExitAsync(WhisperCliTranscriber.MaximumInferenceTime, TestContext.CancellationToken);
                    safeToDelete = true;
                    Assert.AreEqual(ChildProcessExit.Exited, result.Outcome);
                    Assert.AreEqual(0, result.ExitCode);
                    transcript = await WhisperCliTranscriber.ReadResultAsync(Path.Combine(session, "result.txt"), TestContext.CancellationToken);
                }
            }
            finally { if (safeToDelete) { Directory.Delete(session, true); } }
            var reference = item.GetProperty("reference").GetString()!;
            if (item.GetProperty("id").GetString() == "silence") { Assert.IsTrue(string.IsNullOrWhiteSpace(transcript), "The real engine fabricated text from silence."); continue; }
            var wer = CorpusScoring.WordError(reference, transcript);
            var retention = CorpusScoring.Anglicisms(reference, transcript, item.GetProperty("anglicisms").EnumerateArray().Select(term => term.GetString()!));
            totals.TryGetValue(language, out var total);
            totals[language] = (total.Errors + wer.Errors, total.Words + wer.Words, total.Retained + retention.Retained, total.Annotated + retention.Expected);
        }
        foreach (var language in new[] { "pt", "en", "es" })
        {
            var total = totals[language];
            var wer = (double)total.Errors / total.Words;
            TestContext.WriteLine($"{language}: WER={wer:F4}, errors={total.Errors}, referenceWords={total.Words}");
            Assert.IsTrue(wer <= 0.20, $"{language} exceeds 20% WER.");
            if (language is "pt" or "es")
            {
                Assert.IsTrue(total.Annotated > 0);
                var retention = (double)total.Retained / total.Annotated;
                TestContext.WriteLine($"{language}: anglicismRetention={retention:F4}, retained={total.Retained}, annotated={total.Annotated}");
                Assert.IsTrue(retention >= 0.90, $"{language} falls below 90% anglicism retention.");
            }
        }
    }

    private static async Task RequireCommitted(string repository, string relative)
    {
        var current = await Git(repository, ["hash-object", "--", relative]);
        var committed = await Git(repository, ["rev-parse", "HEAD:" + relative]);
        Assert.AreEqual(committed, current, "Corpus expectations and licensed bytes must be committed before measurement.");
    }

    private static void RequirePcmFixture(byte[] bytes, bool silence)
    {
        Assert.IsTrue(bytes.Length >= 44 && bytes.Length <= 44 + 120 * 32000, "Corpus WAV must be bounded PCM16 mono at 16 kHz.");
        using var reader = new BinaryReader(new MemoryStream(bytes), Encoding.ASCII);
        Assert.AreEqual("RIFF", new string(reader.ReadChars(4)));
        Assert.AreEqual((uint)bytes.Length - 8, reader.ReadUInt32());
        Assert.AreEqual("WAVEfmt ", new string(reader.ReadChars(8)));
        Assert.AreEqual(16u, reader.ReadUInt32());
        Assert.AreEqual((ushort)1, reader.ReadUInt16());
        Assert.AreEqual((ushort)1, reader.ReadUInt16());
        Assert.AreEqual(16000u, reader.ReadUInt32());
        Assert.AreEqual(32000u, reader.ReadUInt32());
        Assert.AreEqual((ushort)2, reader.ReadUInt16());
        Assert.AreEqual((ushort)16, reader.ReadUInt16());
        Assert.AreEqual("data", new string(reader.ReadChars(4)));
        Assert.AreEqual((uint)bytes.Length - 44, reader.ReadUInt32());
        Assert.AreEqual(0, (bytes.Length - 44) % 2);
        Assert.IsTrue(bytes.Length >= 44 + 9600, "Record at least 300 ms per fixture.");
        if (silence) { Assert.IsTrue(bytes.AsSpan(44).IndexOfAnyExcept((byte)0) < 0, "The silence fixture must contain PCM zero samples."); }
    }

    private static async Task<string> Git(string repository, string[] arguments)
    {
        var start = new ProcessStartInfo("git") { UseShellExecute = false, WorkingDirectory = repository, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var argument in arguments) { start.ArgumentList.Add(argument); }
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Git is required for immutable corpus verification.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        try { await process.WaitForExitAsync(timeout.Token); }
        catch (OperationCanceledException) { process.Kill(true); await process.WaitForExitAsync(CancellationToken.None); throw; }
        Assert.AreEqual(0, process.ExitCode, "Corpus input is missing from HEAD; commit it before measuring.");
        await stderr;
        return (await stdout).Trim();
    }
}
