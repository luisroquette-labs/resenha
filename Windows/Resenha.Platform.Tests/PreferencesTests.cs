using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class PreferencesTests
{
    [TestMethod]
    public async Task RoundTripPersistsOnlySixWhitelistedFieldsAndNeverCredential()
    {
        using var directory = new TemporaryDirectory();
        var store = new PreferencesStore(directory.Path);
        var operation = AttemptId.New();
        var value = new ProductPreferences(1, ShortcutPolicy.Default, "microfone-é", DictationLanguage.Pt,
            true, "Hostel\nCOESA Energia");
        Assert.IsTrue((await store.SaveAsync(operation, value, default)).IsSuccess);
        var restored = await store.LoadAsync(operation, default);
        Assert.AreEqual(value, restored.Value);
        using var document = JsonDocument.Parse(await File.ReadAllTextAsync(System.IO.Path.Combine(
            directory.Path, "Resenha", "settings.json")));
        CollectionAssert.AreEquivalent(new[] { "schemaVersion", "shortcut", "microphoneEndpointId", "language", "contextualEnabled", "personalVocabulary" },
            document.RootElement.EnumerateObject().Select(property => property.Name).ToArray());
        Assert.IsFalse(document.RootElement.ToString().Contains("transcript", StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(document.RootElement.ToString().Contains("sk-or-", StringComparison.Ordinal));
    }

    [TestMethod]
    public async Task MalformedUnknownOrInvalidSettingsFailClosed()
    {
        foreach (var json in new[]
        {
            "not-json",
            "{}",
            "{\"schemaVersion\":1,\"shortcut\":{\"scanCode\":57,\"isExtended\":false,\"modifiers\":5},\"microphoneEndpointId\":\"mic\",\"language\":0,\"transcript\":\"secret\"}",
            "{\"schemaVersion\":99,\"shortcut\":{\"scanCode\":57,\"isExtended\":false,\"modifiers\":5},\"microphoneEndpointId\":\"mic\",\"language\":0}"
        })
        {
            using var directory = new TemporaryDirectory();
            var owned = System.IO.Path.Combine(directory.Path, "Resenha");
            Directory.CreateDirectory(owned);
            await File.WriteAllTextAsync(System.IO.Path.Combine(owned, "settings.json"), json);
            var loaded = await new PreferencesStore(directory.Path).LoadAsync(AttemptId.New(), default);
            Assert.AreEqual(ErrorCode.CorruptInput, loaded.Failure?.Code, json);
        }
    }

    [TestMethod]
    public async Task VersionZeroPointOneSettingsLoadWithJevOff()
    {
        using var directory = new TemporaryDirectory();
        var owned = System.IO.Path.Combine(directory.Path, "Resenha");
        Directory.CreateDirectory(owned);
        await File.WriteAllTextAsync(System.IO.Path.Combine(owned, "settings.json"),
            "{\"schemaVersion\":1,\"shortcut\":{\"scanCode\":57,\"isExtended\":false,\"modifiers\":5},\"microphoneEndpointId\":\"mic\",\"language\":0}");

        var loaded = await new PreferencesStore(directory.Path).LoadAsync(AttemptId.New(), default);

        Assert.IsTrue(loaded.IsSuccess);
        Assert.IsFalse(loaded.Value!.ContextualEnabled);
        Assert.AreEqual(string.Empty, loaded.Value.PersonalVocabulary);
    }

    [TestMethod]
    public async Task MissingMicrophoneCanBeSavedButWhitespaceIdentifierCannot()
    {
        using var directory = new TemporaryDirectory();
        var store = new PreferencesStore(directory.Path);
        var first = new ProductPreferences(1, ShortcutPolicy.Default, "mic", DictationLanguage.En);
        Assert.IsTrue((await store.SaveAsync(AttemptId.New(), first, default)).IsSuccess);
        var withoutMicrophone = first with { MicrophoneEndpointId = "" };
        Assert.IsTrue((await store.SaveAsync(AttemptId.New(), withoutMicrophone, default)).IsSuccess);
        Assert.AreEqual(withoutMicrophone, (await store.LoadAsync(AttemptId.New(), default)).Value);
        var invalid = first with { MicrophoneEndpointId = " " };
        Assert.AreEqual(ErrorCode.CorruptInput,
            (await store.SaveAsync(AttemptId.New(), invalid, default)).Failure?.Code);
        Assert.AreEqual(withoutMicrophone, (await store.LoadAsync(AttemptId.New(), default)).Value);
    }

    [TestMethod]
    public async Task InvalidVocabularyDoesNotReplaceLastValidSettings()
    {
        using var directory = new TemporaryDirectory();
        var store = new PreferencesStore(directory.Path);
        var valid = new ProductPreferences(1, ShortcutPolicy.Default, "mic", DictationLanguage.Pt,
            true, "Hostel");
        Assert.IsTrue((await store.SaveAsync(AttemptId.New(), valid, default)).IsSuccess);
        var invalid = valid with { PersonalVocabulary = "Hostel\u0001" };
        Assert.AreEqual(ErrorCode.CorruptInput,
            (await store.SaveAsync(AttemptId.New(), invalid, default)).Failure?.Code);
        Assert.AreEqual(valid, (await store.LoadAsync(AttemptId.New(), default)).Value);
    }

    private sealed class TemporaryDirectory : IDisposable
    {
        internal TemporaryDirectory()
        {
            Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "resenha-preferences-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path);
        }
        internal string Path { get; }
        public void Dispose() { if (Directory.Exists(Path)) { Directory.Delete(Path, recursive: true); } }
    }
}
