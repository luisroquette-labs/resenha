using Resenha.Core;

namespace Resenha.Testing;

// No file, microphone, clipboard, input, network or child-process side effects.
// Deliberate defaults are failures; tests must opt into a successful response.
internal sealed class ManualClock : IClock
{
    private readonly List<(AttemptId Attempt, MonotonicTimestamp Deadline, CancellationToken Token, TaskCompletionSource<Outcome<Unit>> Completion)> waits = [];
    public MonotonicTimestamp Now { get; private set; }
    public MonotonicTimestamp GetTimestamp() => Now;

    public ValueTask<Outcome<Unit>> DelayUntilAsync(AttemptId attempt, MonotonicTimestamp deadline, CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested)
        {
            return ValueTask.FromResult(Outcome<Unit>.Cancelled(attempt));
        }

        if (deadline.Ticks <= Now.Ticks)
        {
            return ValueTask.FromResult(Outcome<Unit>.Success(attempt, default));
        }

        var completion = new TaskCompletionSource<Outcome<Unit>>(TaskCreationOptions.RunContinuationsAsynchronously);
        waits.Add((attempt, deadline, cancellationToken, completion));
        return WaitAsync(attempt, completion.Task, cancellationToken);
    }

    private static async ValueTask<Outcome<Unit>> WaitAsync(AttemptId attempt, Task<Outcome<Unit>> task, CancellationToken cancellationToken)
    {
        try
        {
            return await task.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return Outcome<Unit>.Cancelled(attempt);
        }
    }

    public void Advance(TimeSpan elapsed)
    {
        if (elapsed < TimeSpan.Zero) { throw new ArgumentOutOfRangeException(nameof(elapsed)); }
        Now = Now.Add(elapsed);
        foreach (var wait in waits.ToArray())
        {
            if (wait.Token.IsCancellationRequested || wait.Deadline.Ticks <= Now.Ticks)
            {
                wait.Completion.TrySetResult(wait.Token.IsCancellationRequested
                    ? Outcome<Unit>.Cancelled(wait.Attempt)
                    : Outcome<Unit>.Success(wait.Attempt, default));
                waits.Remove(wait);
            }
        }
    }
}

internal sealed class TestAudioLease(AudioDescriptor audio) : AudioLease(audio)
{
    public int DisposalCount { get; private set; }
    public Func<ValueTask> Cleanup { get; set; } = () => ValueTask.CompletedTask;

    protected override ValueTask DisposeCoreAsync()
    {
        DisposalCount++;
        return Cleanup();
    }
}

internal sealed class TestModelLease(AttemptId attempt, ModelDescriptor model, string path) : VerifiedModelLease(attempt, model, path)
{
    public int DisposalCount { get; private set; }
    protected override ValueTask DisposeCoreAsync()
    {
        DisposalCount++;
        return ValueTask.CompletedTask;
    }
}

internal sealed class FakeShortcutSource : IShortcutSource
{
    public event Action<ShortcutEdge>? Edge;
    public Shortcut? ConfiguredShortcut { get; private set; }
    public bool IsListening { get; private set; }
    public void Emit(ShortcutEdge edge) { if (IsListening) { Edge?.Invoke(edge); } }

    public ValueTask<Outcome<Unit>> ConfigureAsync(AttemptId attempt, Shortcut shortcut, CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested) { return ValueTask.FromResult(Outcome<Unit>.Cancelled(attempt)); }
        ConfiguredShortcut = shortcut;
        return ValueTask.FromResult(Outcome<Unit>.Success(attempt, default));
    }

    public ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested) { return ValueTask.FromResult(Outcome<Unit>.Cancelled(attempt)); }
        IsListening = ConfiguredShortcut is not null;
        return ValueTask.FromResult(IsListening ? Outcome<Unit>.Success(attempt, default) : Outcome<Unit>.Failed(attempt, ErrorCode.NotReady));
    }

    public ValueTask<Outcome<Unit>> StopAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        IsListening = false;
        return ValueTask.FromResult(Outcome<Unit>.Success(attempt, default));
    }
}

internal sealed class FakeAudioRecorder : IAudioRecorder
{
    public Func<AttemptId, string, MonotonicTimestamp, CancellationToken, ValueTask<Outcome<Unit>>> OnStart { get; set; } = (a, _, _, _) => ValueTask.FromResult(Outcome<Unit>.Failed(a, ErrorCode.NotReady));
    public Func<AttemptId, MonotonicTimestamp, CancellationToken, ValueTask<Outcome<AudioLease>>> OnStop { get; set; } = (a, _, _) => ValueTask.FromResult(Outcome<AudioLease>.Failed(a, ErrorCode.NotReady));
    public Func<AttemptId, CancellationToken, ValueTask<Outcome<Unit>>> OnCancel { get; set; } = (a, _) => ValueTask.FromResult(Outcome<Unit>.Success(a, default));
    public ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, string deviceId, MonotonicTimestamp pressedAt, CancellationToken cancellationToken) => OnStart(attempt, deviceId, pressedAt, cancellationToken);
    public ValueTask<Outcome<AudioLease>> StopAsync(AttemptId attempt, MonotonicTimestamp releasedAt, CancellationToken cancellationToken) => OnStop(attempt, releasedAt, cancellationToken);
    public ValueTask<Outcome<Unit>> CancelAsync(AttemptId attempt, CancellationToken cancellationToken) => OnCancel(attempt, cancellationToken);
}

internal sealed class FakeModelStore : IModelStore
{
    public Func<AttemptId, CancellationToken, ValueTask<Outcome<VerifiedModelLease>>> OnAcquire { get; set; } = (a, _) => ValueTask.FromResult(Outcome<VerifiedModelLease>.Failed(a, ErrorCode.ModelMissing));
    public ValueTask<Outcome<VerifiedModelLease>> AcquireVerifiedAsync(AttemptId attempt, CancellationToken cancellationToken) => OnAcquire(attempt, cancellationToken);
}

internal sealed class FakeTranscriber : ITranscriber
{
    public Func<AttemptId, AudioLease, VerifiedModelLease, DictationLanguage, MonotonicTimestamp, CancellationToken, ValueTask<TranscriptResult>> OnTranscribe { get; set; } = (a, _, _, _, _, _) => ValueTask.FromResult(TranscriptResult.WithoutText(a, TranscriptOutcome.EngineFailure));
    public ValueTask<TranscriptResult> TranscribeAsync(AttemptId attempt, AudioLease audio, VerifiedModelLease model, DictationLanguage language, MonotonicTimestamp deadline, CancellationToken cancellationToken) => OnTranscribe(attempt, audio, model, language, deadline, cancellationToken);
}

internal sealed class FakeTargetProbe : ITargetProbe
{
    public Func<AttemptId, MonotonicTimestamp, CancellationToken, ValueTask<Outcome<TargetSnapshot>>> OnCapture { get; set; } = (a, _, _) => ValueTask.FromResult(Outcome<TargetSnapshot>.Failed(a, ErrorCode.TargetUnknown));
    public Func<AttemptId, TargetSnapshot, CancellationToken, ValueTask<Outcome<TargetCheck>>> OnCheck { get; set; } = (a, _, _) => ValueTask.FromResult(Outcome<TargetCheck>.Success(a, TargetCheck.Unknown));
    public ValueTask<Outcome<TargetSnapshot>> CaptureAsync(AttemptId attempt, MonotonicTimestamp pressedAt, CancellationToken cancellationToken) => OnCapture(attempt, pressedAt, cancellationToken);
    public ValueTask<Outcome<TargetCheck>> CheckAsync(AttemptId attempt, TargetSnapshot target, CancellationToken cancellationToken) => OnCheck(attempt, target, cancellationToken);
}

internal sealed class FakeClipboard : IClipboard
{
    public Func<AttemptId, string, CancellationToken, ValueTask<Outcome<ClipboardToken>>> OnCommit { get; set; } = (a, _, _) => ValueTask.FromResult(Outcome<ClipboardToken>.Failed(a, ErrorCode.ClipboardBusy));
    public Func<AttemptId, ClipboardToken, CancellationToken, ValueTask<Outcome<bool>>> OnIsCurrent { get; set; } = (a, _, _) => ValueTask.FromResult(Outcome<bool>.Success(a, false));
    public ValueTask<Outcome<ClipboardToken>> CommitAsync(AttemptId attempt, string text, CancellationToken cancellationToken) => OnCommit(attempt, text, cancellationToken);
    public ValueTask<Outcome<bool>> IsCurrentAsync(AttemptId attempt, ClipboardToken token, CancellationToken cancellationToken) => OnIsCurrent(attempt, token, cancellationToken);
}

internal sealed class FakeTextInjector : ITextInjector
{
    public Func<AttemptId, TargetSnapshot, ClipboardToken, CancellationToken, ValueTask<Outcome<InjectionResult>>> OnInsert { get; set; } = (a, _, _, _) => ValueTask.FromResult(Outcome<InjectionResult>.Success(a, new(InjectionDisposition.ManualPaste, ErrorCode.TargetUnknown)));
    public ValueTask<Outcome<InjectionResult>> TryInsertAsync(AttemptId attempt, TargetSnapshot target, ClipboardToken clipboard, CancellationToken cancellationToken) => OnInsert(attempt, target, clipboard, cancellationToken);
}
