using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class OutputTests
{
    [TestMethod]
    public void ExistingReferenceCorpusIsPreservedExactly()
    {
        using var corpus = JsonDocument.Parse(File.ReadAllText(FindRepositoryFile("Tests/Fixtures/output-corpus.json")));
        foreach (var fixture in corpus.RootElement.EnumerateArray())
        {
            var text = fixture.GetProperty("text").GetString();
            Assert.AreEqual(text, OutputPolicy.Normalize(text), fixture.GetProperty("id").GetString());
        }
    }

    [TestMethod]
    public void NormalizationIsDeterministicAndMeaningPreserving()
    {
        Assert.AreEqual("Éric fez o benchmark do whisper.cpp.",
            OutputPolicy.Normalize("  E\u0301ric\t fez  o benchmark\r\ndo whisper.cpp.  "));
        Assert.AreEqual("onboarding loading time deadline", OutputPolicy.Normalize("onboarding loading time deadline"));
        Assert.IsNull(OutputPolicy.Normalize("\r\n\t"));
        Assert.IsNull(OutputPolicy.Normalize("texto\0oculto"));
        Assert.IsNull(OutputPolicy.Normalize(new string('a', OutputPolicy.MaximumCharacters + 1)));
    }

    private static string FindRepositoryFile(string relative)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, relative.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(candidate)) { return candidate; }
            directory = directory.Parent;
        }
        Assert.Fail($"Repository fixture not found: {relative}");
        return string.Empty;
    }
}
