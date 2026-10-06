using System.Text;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Resenha.Core.Tests;

[TestClass]
public sealed class ReleasePolicyTests
{
    private static string Root
    {
        get
        {
            for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
                if (File.Exists(Path.Combine(directory.FullName, "Windows", "release-manifest.schema.json"))) return directory.FullName;
            throw new DirectoryNotFoundException("Run portable tests from the repository; release fixtures are required, never skipped.");
        }
    }

    private static string Schema => File.ReadAllText(Path.Combine(Root, "Windows", "release-manifest.schema.json"));
    private static JsonObject Bundle(string stage = "hosted-ready") => JsonNode.Parse(File.ReadAllText(Path.Combine(Root, "Scripts", "fixtures", "windows-release", $"synthetic-{stage}.bundle.json")))!.AsObject();

    public static IEnumerable<object[]> NegativeCases()
    {
        var fixture = JsonNode.Parse(File.ReadAllText(Path.Combine(Root, "Scripts", "fixtures", "windows-release", "negative-cases.json")))!;
        return fixture["cases"]!.AsArray().Select(item => new object[] { item!["name"]!.GetValue<string>(), item.ToJsonString() });
    }

    [TestMethod]
    [DataRow("candidate-ready")]
    [DataRow("hosted-ready")]
    public void CompleteSyntheticContractNeverEnablesPublication(string stage)
    {
        var decision = Evaluate(Bundle(stage));
        Assert.IsTrue(decision.ContractValid, string.Join(", ", decision.Errors));
        Assert.IsFalse(decision.CandidateReady);
        Assert.IsFalse(decision.HostedReady);
        Assert.IsFalse(decision.CanEnablePublicDownload);
    }

    [TestMethod]
    [DynamicData(nameof(NegativeCases))]
    public void MissingContradictoryOrChangedEvidenceFailsClosed(string name, string fixtureJson)
    {
        var bundle = Bundle();
        var fixture = JsonNode.Parse(fixtureJson)!;
        var parts = fixture["path"]!.GetValue<string>().Split('/');
        JsonNode target = bundle;
        foreach (var part in parts[..^1]) target = Child(target, part)!;
        if (fixture["remove"]?.GetValue<bool>() == true) target.AsObject().Remove(parts[^1]);
        else if (target is JsonArray array) array[int.Parse(parts[^1], System.Globalization.CultureInfo.InvariantCulture)] = fixture["value"]?.DeepClone();
        else target[parts[^1]] = fixture["value"]?.DeepClone();
        var decision = Evaluate(bundle);
        Assert.IsFalse(decision.ContractValid, name);
        Assert.IsFalse(decision.CanEnablePublicDownload, name);
        Assert.IsTrue(decision.Errors.Length > 0, name);
        if (fixture["error"] is JsonNode expected)
            Assert.IsTrue(decision.Errors.Contains(expected.GetValue<string>()), $"{name}: {string.Join(", ", decision.Errors)}");
    }

    [TestMethod]
    public void ReportBytesCannotChangeWhileRetainingTheirIdentity()
    {
        var bundle = Bundle();
        var path = bundle["manifest"]!["scan"]!["report"]!["path"]!.GetValue<string>();
        bundle["evidenceFiles"]![path] = bundle["evidenceFiles"]![path]!.GetValue<string>() + "\n";
        var decision = Evaluate(bundle);
        Assert.IsFalse(decision.ContractValid);
        Assert.IsTrue(decision.Errors.Any(error => error.StartsWith("report.hash:", StringComparison.Ordinal)));
    }

    [TestMethod]
    public void IncompletePeSignatureInventoryIsRejectedWithoutRelyingOnReportHash()
    {
        var bundle = Bundle();
        bundle["manifest"]!["signatures"]!["items"]!.AsArray().RemoveAt(0);
        var decision = Evaluate(bundle);
        Assert.IsFalse(decision.ContractValid);
        CollectionAssert.Contains(decision.Errors.ToArray(), "signatures.incomplete-pe-inventory");
    }

    [TestMethod]
    public void ChangedSchemaAndDuplicateJsonKeysFailClosed()
    {
        CollectionAssert.Contains(Evaluate(Bundle(), Schema + "\n").Errors.ToArray(), "schema.identity");
        var bundle = Bundle();
        var json = bundle["manifest"]!.ToJsonString().Replace("\"schemaVersion\":1", "\"schemaVersion\":1,\"schemaVersion\":1", StringComparison.Ordinal);
        CollectionAssert.Contains(Evaluate(bundle, manifestJson: json).Errors.ToArray(), "json.duplicate-key");
    }

    [TestMethod]
    public void MissingUnderlyingReportsCannotBeReplacedWithPassedBoolean()
    {
        var bundle = Bundle();
        bundle["manifest"]!["verification"] = new JsonObject { ["passed"] = true };
        Assert.IsFalse(Evaluate(bundle).ContractValid);
    }

    [TestMethod]
    public void RootLevelWhisperDoesNotSatisfyTheNativePayloadPath()
    {
        var bundle = Bundle();
        var payload = bundle["payloadUtf8"]!.AsObject();
        payload["whisper-cli.exe"] = payload["native/whisper-cli.exe"]!.DeepClone();
        payload.Remove("native/whisper-cli.exe");
        var files = bundle["manifest"]!["payload"]!["files"]!.AsArray();
        files.Single(file => file!["path"]!.GetValue<string>() == "native/whisper-cli.exe")!["path"] = "whisper-cli.exe";
        var canonicalFiles = new JsonArray(files.OrderBy(file => file!["path"]!.GetValue<string>(), StringComparer.Ordinal).Select(file => (JsonNode)new JsonObject
        {
            ["byteLength"] = file!["byteLength"]!.DeepClone(),
            ["isPe"] = file["isPe"]!.DeepClone(),
            ["path"] = file["path"]!.DeepClone(),
            ["sha256"] = file["sha256"]!.DeepClone()
        }).ToArray());
        bundle["manifest"]!["payload"]!["files"] = canonicalFiles;
        bundle["manifest"]!["payload"]!["inventorySha256"] = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalFiles.ToJsonString())));
        CollectionAssert.Contains(Evaluate(bundle).Errors.ToArray(), "payload.required-pe:native/whisper-cli.exe");
    }

    [TestMethod]
    public void NativeWhisperRequiresTheReleasePublisher()
    {
        var bundle = Bundle();
        var native = bundle["manifest"]!["signatures"]!["items"]!.AsArray().Single(item => item!["path"]!.GetValue<string>() == "native/whisper-cli.exe")!;
        native["authority"] = "vendor";
        CollectionAssert.Contains(Evaluate(bundle).Errors.ToArray(), "signatures.owned-publisher");
    }

    [TestMethod]
    public void VendorTimestampBeforeBuildIsValidButReleaseTimestampBeforeBuildIsRejected()
    {
        var bundle = Bundle();
        var items = bundle["manifest"]!["signatures"]!["items"]!.AsArray();
        var vendor = items.Single(item => item!["authority"]!.GetValue<string>() == "vendor")!;
        var vendorTime = vendor["timestamp"]!["atUtc"]!.GetValue<string>();
        Assert.IsTrue(string.CompareOrdinal(vendorTime, bundle["manifest"]!["build"]!["recordedAtUtc"]!.GetValue<string>()) < 0);
        var baseline = Evaluate(bundle);
        Assert.IsTrue(baseline.ContractValid, string.Join(", ", baseline.Errors));
        items.First(item => item!["authority"]!.GetValue<string>() == "release")!["timestamp"]!["atUtc"] = vendorTime;
        CollectionAssert.Contains(Evaluate(bundle).Errors.ToArray(), "signatures.timestamp-order");
    }

    [TestMethod]
    public void EarlierVendorTimestampStillRequiresAValidCertificateInterval()
    {
        var bundle = Bundle();
        var vendor = bundle["manifest"]!["signatures"]!["items"]!.AsArray().Single(item => item!["authority"]!.GetValue<string>() == "vendor")!;
        vendor["certificateNotBeforeUtc"] = "2026-10-01T00:00:00Z";
        CollectionAssert.Contains(Evaluate(bundle).Errors.ToArray(), "signatures.certificate-time");
    }

    [TestMethod]
    public void EnglishAnglicismRetentionIsNotApplicableWithoutInventedMeasurement()
    {
        var bundle = Bundle();
        var corpus = bundle["manifest"]!["physical"]![0]!["corpus"]!.AsArray();
        var english = corpus.Single(result => result!["language"]!.GetValue<string>() == "en")!;
        Assert.AreEqual("not-applicable", english["anglicismRetention"]!.GetValue<string>());
        Assert.IsTrue(Evaluate(bundle).ContractValid);
        english["anglicismRetention"] = 1;
        Assert.IsFalse(Evaluate(bundle).ContractValid);
    }

    private static JsonNode? Child(JsonNode value, string key) => value is JsonArray array ? array[int.Parse(key, System.Globalization.CultureInfo.InvariantCulture)] : value[key];

    private static ReleaseDecision Evaluate(JsonObject bundle, string? schema = null, string? manifestJson = null)
    {
        var expected = bundle["expected"]!;
        using var artifact = new MemoryStream(Encoding.UTF8.GetBytes(bundle["artifactUtf8"]!.GetValue<string>()));
        using var hostedArtifact = new MemoryStream(Encoding.UTF8.GetBytes(bundle["artifactUtf8"]!.GetValue<string>()));
        var payload = bundle["payloadUtf8"]!.AsObject().ToDictionary(pair => pair.Key, pair => (Stream)new MemoryStream(Encoding.UTF8.GetBytes(pair.Value!.GetValue<string>())), StringComparer.Ordinal);
        try
        {
            var evidence = bundle["evidenceFiles"]!.AsObject().ToDictionary(pair => pair.Key, pair => (ReadOnlyMemory<byte>)Encoding.UTF8.GetBytes(pair.Value!.GetValue<string>()), StringComparer.Ordinal);
            var inputs = new ReleaseEvidenceInputs(expected["sourceCommit"]!.GetValue<string>(), expected["publisher"]!.GetValue<string>(), expected["certificateThumbprint"]!.GetValue<string>(), expected["toolSha256"]!.GetValue<string>(), DateTimeOffset.Parse(expected["evaluationTimeUtc"]!.GetValue<string>(), System.Globalization.CultureInfo.InvariantCulture), artifact, payload, evidence, hostedArtifact);
            return ReleasePolicy.Evaluate(manifestJson ?? bundle["manifest"]!.ToJsonString(), schema ?? Schema, inputs);
        }
        finally
        {
            foreach (var stream in payload.Values) stream.Dispose();
        }
    }
}
