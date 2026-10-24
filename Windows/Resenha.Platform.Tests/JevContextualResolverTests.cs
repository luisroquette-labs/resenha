using System.Net;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

namespace Resenha.Platform.Tests;

[TestClass]
[TestCategory("Portable")]
public sealed class JevContextualResolverTests
{
    private static readonly ProductPreferences Preferences = new(1, ShortcutPolicy.Default, "mic",
        DictationLanguage.Pt, true, "Hostel");

    [TestMethod]
    public async Task OfficialResponseReplacesContextualCandidateAndSendsOnlyText()
    {
        const string response = """
            {"model":"typesafe/jev-1.14-20261014","answers":{"o1":{"type":"choice","choice":"replace_1","probabilities":{"keep_original":0.01,"replace_1":0.99},"confidence":0.98}},"usage":{"input_tokens":357,"output_tokens":38,"cost":0.000014994},"id":"synthetic-id","provider":"TypeSafe"}
            """;
        var handler = new CaptureHandler(new(HttpStatusCode.OK)
        {
            Content = new StringContent(response, Encoding.UTF8, "application/json")
        });
        using var client = new HttpClient(handler);
        using var resolver = new JevContextualResolver(new ManualClock(),
            () => "sk-or-test-key-1234567890", client);

        var result = await resolver.ResolveAsync(AttemptId.New(), "Reservei um rosto.", Preferences,
            new(TimeSpan.FromSeconds(1).Ticks), default);

        Assert.AreEqual("Reservei um Hostel.", result);
        Assert.AreEqual("https://openrouter.ai/api/alpha/decisions", handler.Request?.RequestUri?.ToString());
        Assert.AreEqual("Bearer", handler.Request?.Headers.Authorization?.Scheme);
        Assert.IsNotNull(handler.Body);
        StringAssert.Contains(handler.Body, "Reservei um rosto.");
        Assert.IsFalse(handler.Body.Contains("audio", StringComparison.OrdinalIgnoreCase));
    }

    [TestMethod]
    public async Task ErrorAmbiguityAndMissingKeyAlwaysPreserveLocalText()
    {
        const string text = "Meu rosto ficou vermelho.";
        foreach (var response in new[]
        {
            "not-json",
            "{\"model\":\"typesafe/jev-1.14\",\"answers\":{}}",
            "{\"model\":\"typesafe/jev-1.14\",\"answers\":{\"o1\":{\"type\":\"choice\",\"choice\":\"replace_1\",\"probabilities\":{\"keep_original\":0.11,\"replace_1\":0.89},\"confidence\":0.99}}}"
        })
        {
            using var client = new HttpClient(new CaptureHandler(new(HttpStatusCode.OK)
            { Content = new StringContent(response) }));
            using var resolver = new JevContextualResolver(new ManualClock(),
                () => "sk-or-test-key-1234567890", client);
            Assert.AreEqual(text, await resolver.ResolveAsync(AttemptId.New(), text, Preferences,
                new(TimeSpan.FromSeconds(1).Ticks), default));
        }

        using var missing = new JevContextualResolver(new ManualClock(), () => null,
            new HttpClient(new CaptureHandler(new(HttpStatusCode.InternalServerError))));
        Assert.AreEqual(text, await missing.ResolveAsync(AttemptId.New(), text, Preferences,
            new(TimeSpan.FromSeconds(1).Ticks), default));
    }

    [TestMethod]
    public void CredentialValidationRejectsWhitespaceAndNonOpenRouterKeys()
    {
        Assert.IsTrue(OpenRouterCredentialStore.IsValid("sk-or-test-key-1234567890"));
        Assert.IsFalse(OpenRouterCredentialStore.IsValid("sk-or-test key-1234567890"));
        Assert.IsFalse(OpenRouterCredentialStore.IsValid("other-test-key-1234567890"));
    }

    private sealed class CaptureHandler(HttpResponseMessage response) : HttpMessageHandler
    {
        internal HttpRequestMessage? Request { get; private set; }
        internal string? Body { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Request = request;
            Body = request.Content is null ? null : await request.Content.ReadAsStringAsync(cancellationToken);
            return response;
        }
    }
}
