using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class PersonalVocabularyTests
{
    [TestMethod]
    public void CandidateDiscoveryOffersHostelWithoutChangingRostoByItself()
    {
        const string text = "Meu rosto ficou vermelho.";
        var occurrences = PersonalVocabulary.FindCandidates(text, "Hostel");

        Assert.HasCount(1, occurrences);
        Assert.AreEqual("rosto", occurrences[0].Heard);
        Assert.AreEqual("Hostel", occurrences[0].Replacement);
        Assert.AreEqual(text, PersonalVocabulary.Apply(text, []));
    }

    [TestMethod]
    public void ReplacementRequiresNinetyPercentConfidenceAndExactRange()
    {
        const string text = "Meu rosto ficou vermelho.";
        var low = new ContextualDecision("o1", "rosto", "Hostel", 4, 5, true, 0.89);
        var accepted = low with { Confidence = 0.90 };
        var stale = accepted with { Start = 0 };

        Assert.AreEqual(text, PersonalVocabulary.Apply(text, [low]));
        Assert.AreEqual("Meu Hostel ficou vermelho.", PersonalVocabulary.Apply(text, [accepted]));
        Assert.AreEqual(text, PersonalVocabulary.Apply(text, [stale]));
    }

    [TestMethod]
    public void VocabularyRejectsControlsOversizedTermsAndMoreThanTwoHundredTerms()
    {
        Assert.IsFalse(PersonalVocabulary.IsValid("Hostel\u0001"));
        Assert.IsFalse(PersonalVocabulary.IsValid(new string('a', 65)));
        Assert.IsFalse(PersonalVocabulary.IsValid(string.Join('\n', Enumerable.Range(1, 201))));
        Assert.IsTrue(PersonalVocabulary.IsValid("Hostel\nCOESA Energia"));
    }
}
