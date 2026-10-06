using System.Text;

namespace Resenha.Core;

public static class OutputPolicy
{
    public const int MaximumCharacters = 100_000;

    public static string? Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) { return null; }
        var normalized = raw.Normalize(NormalizationForm.FormC).Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');
        if (normalized.Length > MaximumCharacters
            || normalized.Any(character => char.IsControl(character) && character is not '\n' and not '\t'))
        {
            return null;
        }

        var output = new StringBuilder(normalized.Length);
        var pendingSpace = false;
        foreach (var character in normalized)
        {
            if (char.IsWhiteSpace(character))
            {
                pendingSpace = output.Length > 0;
                continue;
            }
            if (pendingSpace) { output.Append(' '); pendingSpace = false; }
            output.Append(character);
        }
        return output.Length == 0 ? null : output.ToString();
    }
}

public interface ITargetAttemptLifetime
{
    void End(AttemptId attempt);
}

public sealed record DictationStatus(DictationState State, AttemptId? Attempt,
    RecoveryStatus? Recovery, bool IsFatal, bool HasLastResult);
