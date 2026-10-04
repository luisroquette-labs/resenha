using System.Collections.Immutable;
using System.Reflection;
using System.Text.Json;
using System.Xml.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Resenha.Core;
using Resenha.Testing;

[assembly: Parallelize(Scope = ExecutionScope.MethodLevel)]

namespace Resenha.Core.Tests;

[TestClass]
public sealed class ContractTests
{
    [TestMethod]
    public void PreferencesRoundTripPreservesPhysicalKeyAndExactSides()
    {
        var preferences = new ProductPreferences(1, new Shortcut(0x39, false, ShortcutModifiers.LeftControl | ShortcutModifiers.LeftAlt), "device-id", DictationLanguage.Pt);
        var json = JsonSerializer.Serialize(preferences);
        Assert.AreEqual(preferences, JsonSerializer.Deserialize<ProductPreferences>(json));
        using var document = JsonDocument.Parse(json);
        CollectionAssert.AreEquivalent(new[] { "schemaVersion", "shortcut", "microphoneEndpointId", "language" }, document.RootElement.EnumerateObject().Select(property => property.Name).ToArray());
        Assert.AreNotEqual(ShortcutModifiers.LeftAlt, ShortcutModifiers.RightAlt);
    }

    [TestMethod]
    public void TargetAndClipboardRoundTripKeepIdentityWithoutFieldContents()
    {
        var attempt = AttemptId.New();
        var target = new TargetSnapshot(attempt, 42, 40, 43, 10, 1234, 1, "desktop", TargetIntegrity.Medium, ImmutableArray.Create(1, 2, 3), 50004, false, true, false, 7, new("opaque-selection", true, false), new(90));
        var restored = JsonSerializer.Deserialize<TargetSnapshot>(JsonSerializer.Serialize(target));
        Assert.IsNotNull(restored);
        Assert.AreEqual(target.Attempt, restored.Attempt);
        Assert.AreEqual(target.ProcessCreationFileTime, restored.ProcessCreationFileTime);
        Assert.AreEqual(target.FocusGeneration, restored.FocusGeneration);
        Assert.AreEqual(target.Selection, restored.Selection);
        CollectionAssert.AreEqual(target.AutomationRuntimeId.ToArray(), restored.AutomationRuntimeId.ToArray());
        var token = new ClipboardToken(attempt, 9, new string('a', 64));
        Assert.AreEqual(token, JsonSerializer.Deserialize<ClipboardToken>(JsonSerializer.Serialize(token)));
        Assert.Throws<ArgumentOutOfRangeException>(() => new ClipboardToken(attempt, 0, new string('a', 64)));
        Assert.Throws<ArgumentException>(() => new ClipboardToken(attempt, 1, "not-a-hash"));
    }

    [TestMethod]
    public void RecoveryAndDiagnosticStringsDoNotPersistCompletedText()
    {
        const string privateText = "private dictated text";
        var attempt = AttemptId.New();
        var recovery = new RecoveryStatus(attempt, ErrorCode.ClipboardBusy, RecoveryAction.CopyAgain, privateText);
        Assert.AreEqual(privateText, recovery.CompletedText);
        Assert.IsFalse(JsonSerializer.Serialize(recovery).Contains(privateText, StringComparison.Ordinal));
        Assert.IsFalse(recovery.ToString().Contains(privateText, StringComparison.Ordinal));
        Assert.IsFalse(TranscriptResult.Completed(attempt, privateText).ToString().Contains(privateText, StringComparison.Ordinal));
    }

    [TestMethod]
    public void FailureResultsHaveNoValueAndCannotMasqueradeAsText()
    {
        var attempt = AttemptId.New();
        var failed = Outcome<string>.Failed(attempt, ErrorCode.ModelCorrupt);
        Assert.AreEqual(attempt, failed.Attempt);
        Assert.IsNull(failed.Value);
        Assert.IsFalse(failed.IsSuccess);
        Assert.AreEqual(ErrorCode.ModelCorrupt, failed.Failure?.Code);
        Assert.Throws<ArgumentException>(() => Outcome<string>.Success(default, "text"));
        Assert.Throws<ArgumentOutOfRangeException>(() => Outcome<string>.Failed(attempt, ErrorCode.None));
        Assert.Throws<ArgumentException>(() => TranscriptResult.Completed(attempt, " "));
        foreach (var outcome in Enum.GetValues<TranscriptOutcome>().Where(value => value != TranscriptOutcome.Text))
        {
            Assert.IsNull(TranscriptResult.WithoutText(attempt, outcome).Text);
        }
    }

    [TestMethod]
    public async Task LeaseDisposalRunsOnceAndRejectsCrossAttemptUse()
    {
        var attempt = AttemptId.New();
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var lease = new TestAudioLease(new(attempt, "owned-session/input.wav", 16000, TimeSpan.FromSeconds(1), new(-20, 16000, TimeSpan.FromSeconds(1)), new(0), new(TimeSpan.TicksPerSecond)))
        {
            Cleanup = () => new ValueTask(completion.Task)
        };
        lease.RequireUsableBy(attempt);
        Assert.Throws<InvalidOperationException>(() => lease.RequireUsableBy(AttemptId.New()));
        var first = lease.DisposeAsync().AsTask();
        var second = lease.DisposeAsync().AsTask();
        Assert.AreSame(first, second);
        Assert.AreEqual(1, lease.DisposalCount);
        Assert.IsFalse(lease.IsDisposed);
        Assert.Throws<InvalidOperationException>(() => lease.RequireUsableBy(attempt));
        completion.SetResult();
        await Task.WhenAll(first, second);
        Assert.IsTrue(lease.IsDisposed);
    }

    [TestMethod]
    public async Task LeaseCleanupFailureIsObservableAndDoesNotClaimDisposal()
    {
        var attempt = AttemptId.New();
        var lease = new TestAudioLease(new(attempt, "owned/input.wav", 0, TimeSpan.Zero, new(-100, 0, TimeSpan.Zero), new(0), new(0)))
        {
            Cleanup = () => ValueTask.FromException(new IOException("test cleanup failure"))
        };
        await Assert.ThrowsAsync<IOException>(async () => await lease.DisposeAsync());
        await Assert.ThrowsAsync<IOException>(async () => await lease.DisposeAsync());
        Assert.IsFalse(lease.IsDisposed);
        Assert.AreEqual(1, lease.DisposalCount);
    }

    [TestMethod]
    public async Task FakeClockSupportsDeterministicDeadlinesAndCancellation()
    {
        var attempt = AttemptId.New();
        var clock = new ManualClock();
        var pending = clock.DelayUntilAsync(attempt, new(TimeSpan.TicksPerSecond), CancellationToken.None).AsTask();
        clock.Advance(TimeSpan.FromMilliseconds(999));
        Assert.IsFalse(pending.IsCompleted);
        clock.Advance(TimeSpan.FromMilliseconds(1));
        Assert.AreEqual(OutcomeKind.Succeeded, (await pending).Kind);
        using var cancellation = new CancellationTokenSource();
        var cancelled = clock.DelayUntilAsync(attempt, clock.Now.Add(TimeSpan.FromSeconds(1)), cancellation.Token).AsTask();
        cancellation.Cancel();
        Assert.AreEqual(OutcomeKind.Cancelled, (await cancelled).Kind);
        Assert.Throws<ArgumentOutOfRangeException>(() => clock.Advance(TimeSpan.FromTicks(-1)));
    }

    [TestMethod]
    public void AsyncBoundariesCarryAttemptAndCancellation()
    {
        Type[] boundaries = [typeof(IShortcutSource), typeof(IClock), typeof(IAudioRecorder), typeof(IModelStore), typeof(ITranscriber), typeof(ITargetProbe), typeof(IClipboard), typeof(ITextInjector)];
        foreach (var method in boundaries.SelectMany(type => type.GetMethods()).Where(method => method.Name.EndsWith("Async", StringComparison.Ordinal)))
        {
            var parameters = method.GetParameters();
            Assert.AreEqual(typeof(AttemptId), parameters[0].ParameterType, method.Name);
            Assert.AreEqual(typeof(CancellationToken), parameters[^1].ParameterType, method.Name);
            Assert.IsTrue(method.ReturnType.IsGenericType && method.ReturnType.GetGenericTypeDefinition() == typeof(ValueTask<>), method.Name);
        }
    }

    [TestMethod]
    public void CoreHasNoWindowsUiNativeOrPackageDependencies()
    {
        var project = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Boundary", "Resenha.Core.csproj"));
        Assert.AreEqual("net10.0", project.Descendants("TargetFramework").Single().Value);
        Assert.IsFalse(project.Descendants("PackageReference").Any());
        Assert.IsFalse(project.Descendants("ProjectReference").Any());
        Assert.IsFalse(project.Descendants("UseWPF").Any());
        var names = typeof(AttemptId).Assembly.GetReferencedAssemblies().Select(assembly => assembly.Name ?? "").ToArray();
        Assert.IsFalse(names.Any(name => name.StartsWith("Resenha.Platform", StringComparison.Ordinal) || name.StartsWith("Presentation", StringComparison.Ordinal) || name.StartsWith("WindowsBase", StringComparison.Ordinal)));
        Assert.IsFalse(typeof(AttemptId).Assembly.GetTypes().SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance)).Any(method => (method.Attributes & MethodAttributes.PinvokeImpl) != 0));
    }
}
