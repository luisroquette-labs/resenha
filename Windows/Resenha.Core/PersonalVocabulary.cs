using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Resenha.Core;

public static partial class PersonalVocabulary
{
    public const int MaximumCharacters = 4096;
    public const int MaximumTerms = 200;

    public static bool IsValid(string value)
    {
        if (value.Length > MaximumCharacters
            || value.Any(character => char.IsControl(character) && character is not '\r' and not '\n' and not '\t'))
        { return false; }
        var raw = value.Split([',', ';', '\r', '\n'],
            StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        return raw.Length <= MaximumTerms && raw.All(term => term.Length is > 0 and <= 64);
    }

    public static IReadOnlyList<string> Parse(string value)
    {
        if (!IsValid(value)) { return []; }
        return value.Split([',', ';', '\r', '\n'], StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Where(term => term.Length is > 0 and <= 64 && term.All(character => !char.IsControl(character)))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(MaximumTerms + 1)
            .ToArray();
    }

    public static IReadOnlyList<ContextualOccurrence> FindCandidates(string text, string vocabulary)
    {
        var terms = Parse(vocabulary);
        if (terms.Count is 0 or > MaximumTerms || text.Length is 0 or > 600) { return []; }
        var result = new List<ContextualOccurrence>(3);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (Match match in Word().Matches(text))
        {
            var heard = match.Value;
            var heardFolded = Fold(heard);
            var candidate = terms.Select(term => (Term: term, Score: Similarity(heardFolded, Fold(term))))
                .Where(item => item.Score >= 0.50 && item.Score < 1
                    && Digits(heard) == Digits(item.Term)
                    && Math.Abs(heard.Length - item.Term.Length) <= 3)
                .OrderByDescending(item => item.Score)
                .ThenBy(item => item.Term, StringComparer.OrdinalIgnoreCase)
                .FirstOrDefault();
            if (candidate.Term is null || !seen.Add(heard)) { continue; }
            result.Add(new($"o{result.Count + 1}", heard, candidate.Term, 1));
            if (result.Count == 3) { break; }
        }
        return result;
    }

    public static string Apply(string text, IReadOnlyList<ContextualDecision> decisions)
    {
        var resolved = text;
        foreach (var decision in decisions.Where(value => value.Replace && value.Confidence >= 0.90)
            .OrderByDescending(value => value.Start))
        {
            if (decision.Start < 0 || decision.Start + decision.Length > resolved.Length
                || !string.Equals(resolved.Substring(decision.Start, decision.Length), decision.Heard,
                    StringComparison.Ordinal)) { continue; }
            resolved = resolved.Remove(decision.Start, decision.Length).Insert(decision.Start, decision.Replacement);
        }
        return resolved;
    }

    internal static IReadOnlyList<(ContextualOccurrence Occurrence, int Start)> Locate(
        string text, IReadOnlyList<ContextualOccurrence> occurrences)
    {
        var located = new List<(ContextualOccurrence, int)>();
        foreach (var occurrence in occurrences)
        {
            var start = 0;
            for (var ordinal = 1; ordinal <= occurrence.Ordinal; ordinal++)
            {
                start = text.IndexOf(occurrence.Heard, start, StringComparison.OrdinalIgnoreCase);
                if (start < 0) { break; }
                if (ordinal < occurrence.Ordinal) { start += occurrence.Heard.Length; }
            }
            if (start >= 0) { located.Add((occurrence, start)); }
        }
        return located;
    }

    private static string Digits(string value) => new(value.Where(char.IsDigit).ToArray());

    private static string Fold(string value)
    {
        var normalized = value.Normalize(NormalizationForm.FormD);
        return new string(normalized.Where(character => CharUnicodeInfo.GetUnicodeCategory(character)
            != UnicodeCategory.NonSpacingMark).Select(char.ToLowerInvariant).ToArray()).Normalize();
    }

    private static double Similarity(string left, string right)
    {
        var maximum = Math.Max(left.Length, right.Length);
        if (maximum == 0) { return 1; }
        var previous = Enumerable.Range(0, right.Length + 1).ToArray();
        for (var i = 1; i <= left.Length; i++)
        {
            var current = new int[right.Length + 1];
            current[0] = i;
            for (var j = 1; j <= right.Length; j++)
            {
                current[j] = Math.Min(Math.Min(current[j - 1] + 1, previous[j] + 1),
                    previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1));
            }
            previous = current;
        }
        return 1 - (double)previous[^1] / maximum;
    }

    [GeneratedRegex(@"[\p{L}\p{N}][\p{L}\p{N}'’\-]{1,63}", RegexOptions.CultureInvariant)]
    private static partial Regex Word();
}

public sealed record ContextualOccurrence(string QuestionId, string Heard, string Replacement, int Ordinal);
public sealed record ContextualDecision(string QuestionId, string Heard, string Replacement,
    int Start, int Length, bool Replace, double Confidence);
