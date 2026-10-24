using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Resenha.Core;

namespace Resenha.Platform;

public sealed class JevContextualResolver : IContextualTextResolver, IDisposable
{
    public const string Model = "typesafe/jev-1.14";
    public const int MaximumRequestBytes = 4096;
    public const int MaximumResponseBytes = 64 * 1024;
    private static readonly Uri Endpoint = new("https://openrouter.ai/api/alpha/decisions");
    private readonly IClock clock;
    private readonly Func<string?> credential;
    private readonly HttpClient client;
    private readonly bool ownsClient;

    public JevContextualResolver(IClock clock, Func<string?> credential, HttpClient? client = null)
    {
        this.clock = clock;
        this.credential = credential;
        if (client is null)
        {
            this.client = new(new HttpClientHandler { AllowAutoRedirect = false, UseCookies = false });
            ownsClient = true;
        }
        else { this.client = client; }
    }

    public async ValueTask<string> ResolveAsync(AttemptId attempt, string text,
        ProductPreferences preferences, MonotonicTimestamp deadline, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (!preferences.ContextualEnabled || text.Length is 0 or > 600) { return text; }
        var key = credential();
        var occurrences = PersonalVocabulary.FindCandidates(text, preferences.PersonalVocabulary);
        if (!OpenRouterCredentialStore.IsValid(key) || occurrences.Count == 0) { return text; }
        var remaining = deadline.ElapsedSince(clock.GetTimestamp());
        if (remaining <= TimeSpan.Zero) { return text; }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(remaining < TimeSpan.FromMilliseconds(900) ? remaining : TimeSpan.FromMilliseconds(900));
        try
        {
            var body = JsonSerializer.SerializeToUtf8Bytes(RequestPayload.Create(text,
                preferences.Language.ToWhisperCode(), occurrences), JsonOptions);
            if (body.Length > MaximumRequestBytes) { return text; }
            using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
            {
                Content = new ByteArrayContent(body)
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
            request.Content.Headers.ContentType = new("application/json");
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead,
                timeout.Token).ConfigureAwait(false);
            if (response.StatusCode != HttpStatusCode.OK) { return text; }
            await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token).ConfigureAwait(false);
            using var limited = new MemoryStream();
            var buffer = new byte[4096];
            while (true)
            {
                var count = await stream.ReadAsync(buffer, timeout.Token).ConfigureAwait(false);
                if (count == 0) { break; }
                if (limited.Length + count > MaximumResponseBytes) { return text; }
                await limited.WriteAsync(buffer.AsMemory(0, count), timeout.Token).ConfigureAwait(false);
            }
            var payload = JsonSerializer.Deserialize<ResponsePayload>(limited.ToArray(), JsonOptions);
            return Resolve(text, occurrences, payload);
        }
        catch (Exception error) when (error is HttpRequestException or OperationCanceledException
            or JsonException or IOException)
        { return text; }
    }

    internal static string Resolve(string text, IReadOnlyList<ContextualOccurrence> occurrences,
        ResponsePayload? payload)
    {
        if (payload?.Model is null || payload.Answers is null
            || !(payload.Model == Model || payload.Model.StartsWith(Model + "-", StringComparison.Ordinal))
            || payload.Answers.Count != occurrences.Count) { return text; }
        var located = PersonalVocabulary.Locate(text, occurrences);
        if (located.Count != occurrences.Count) { return text; }
        var decisions = new List<ContextualDecision>();
        foreach (var (occurrence, start) in located)
        {
            if (!payload.Answers.TryGetValue(occurrence.QuestionId, out var answer)
                || answer.Type != "choice"
                || answer.Choice is not ("keep_original" or "replace_1")
                || answer.Probabilities is null
                || answer.Probabilities.Count != 2
                || !answer.Probabilities.TryGetValue(answer.Choice, out var chosen)
                || answer.Probabilities.Values.Any(value => !double.IsFinite(value) || value < 0 || value > 1)
                || Math.Abs(answer.Probabilities.Values.Sum() - 1) > 0.000001
                || !double.IsFinite(answer.Confidence) || answer.Confidence < 0 || answer.Confidence > 1)
            { return text; }
            var runnerUp = answer.Probabilities.Where(pair => pair.Key != answer.Choice).Select(pair => pair.Value).Single();
            decisions.Add(new(occurrence.QuestionId, occurrence.Heard, occurrence.Replacement,
                start, occurrence.Heard.Length, answer.Choice == "replace_1"
                    && answer.Confidence >= 0.90 && chosen >= 0.90 && chosen - runnerUp >= 0.15,
                answer.Confidence));
        }
        return PersonalVocabulary.Apply(text, decisions);
    }

    public void Dispose() { if (ownsClient) { client.Dispose(); } }

    private static JsonSerializerOptions JsonOptions { get; } = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow
    };

    internal sealed record RequestPayload(string Model, RequestState State,
        IReadOnlyDictionary<string, RequestQuestion> Questions)
    {
        internal static RequestPayload Create(string text, string language,
            IReadOnlyList<ContextualOccurrence> occurrences) => new(JevContextualResolver.Model,
            new(language, text, occurrences.Select(value => new RequestOccurrence(value.Heard,
                value.Replacement, value.Ordinal)).ToArray()),
            occurrences.ToDictionary(value => value.QuestionId, value => new RequestQuestion("choice",
                $"Escolha a forma correta para a ocorrência {value.Ordinal} no contexto.",
                new Dictionary<string, string>
                {
                    ["keep_original"] = "Manter exatamente a forma ouvida no contexto.",
                    ["replace_1"] = $"Substituir exatamente por: {value.Replacement}"
                })));
    }

    internal sealed record RequestState(string Language, string Text,
        IReadOnlyList<RequestOccurrence> Occurrences);
    internal sealed record RequestOccurrence(string Heard, string Canonical, int Ordinal);
    internal sealed record RequestQuestion(string Type, string Instructions,
        IReadOnlyDictionary<string, string> Criteria);
    internal sealed record ResponsePayload(string? Model,
        IReadOnlyDictionary<string, ResponseAnswer>? Answers, JsonElement? Usage = null,
        string? Id = null, string? Provider = null);
    internal sealed record ResponseAnswer(string? Type, string? Choice,
        IReadOnlyDictionary<string, double>? Probabilities, double Confidence);
}
