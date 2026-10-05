namespace Resenha.Core;

public sealed class DictationCoordinator : IAsyncDisposable
{
    private readonly IClock clock;
    private readonly IAudioRecorder audio;
    private readonly IModelStore models;
    private readonly ITranscriber transcriber;
    private readonly ITargetProbe targets;
    private readonly IClipboard clipboard;
    private readonly ITextInjector injector;
    private readonly IShortcutAttemptContext? shortcutContext;
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly object tasksGate = new();
    private readonly HashSet<Task> background = [];
    private Attempt? current;
    private volatile DictationStatus status = new(DictationState.Idle, null, null, false, false);
    private string? lastResult;
    private bool disposed;

    public DictationCoordinator(IClock clock, IAudioRecorder audio, IModelStore models,
        ITranscriber transcriber, ITargetProbe targets, IClipboard clipboard,
        ITextInjector injector, IShortcutAttemptContext? shortcutContext = null)
    {
        this.clock = clock;
        this.audio = audio;
        this.models = models;
        this.transcriber = transcriber;
        this.targets = targets;
        this.clipboard = clipboard;
        this.injector = injector;
        this.shortcutContext = shortcutContext;
    }

    public event Action<DictationStatus>? StatusChanged;
    public DictationStatus Status => status;
    public string? LastResult => lastResult;

    public async ValueTask<Outcome<Unit>> HandleShortcutAsync(ShortcutEdge edge, ProductPreferences preferences,
        CancellationToken cancellationToken = default)
    {
        var operation = AttemptId.New();
        try { await gate.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        try
        {
            if (disposed) { return Outcome<Unit>.Failed(AttemptId.New(), ErrorCode.NotReady); }
            return edge.Kind switch
            {
                ShortcutEdgeKind.Pressed => Press(edge.At, preferences),
                ShortcutEdgeKind.Released => Release(edge.At),
                ShortcutEdgeKind.Interrupted => CancelCurrent(),
                _ => Outcome<Unit>.Failed(AttemptId.New(), ErrorCode.CorruptInput)
            };
        }
        finally { gate.Release(); }
    }

    public async ValueTask<Outcome<Unit>> CancelAsync(CancellationToken cancellationToken = default)
    {
        var operation = AttemptId.New();
        try { await gate.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        try { return CancelCurrent(); }
        finally { gate.Release(); }
    }

    public async ValueTask<Outcome<ClipboardToken>> CopyLastAsync(CancellationToken cancellationToken = default)
    {
        var operation = AttemptId.New();
        string? text;
        try { await gate.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<ClipboardToken>.Cancelled(operation); }
        try
        {
            if (current is not null) { return Outcome<ClipboardToken>.Failed(operation, ErrorCode.Busy); }
            text = lastResult;
        }
        finally { gate.Release(); }
        if (text is null) { return Outcome<ClipboardToken>.Failed(operation, ErrorCode.NotReady); }
        try { return await clipboard.CommitAsync(operation, text, cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<ClipboardToken>.Cancelled(operation); }
        catch (Exception) { return Outcome<ClipboardToken>.Failed(operation, ErrorCode.ClipboardBusy); }
    }

    public async ValueTask AcknowledgeFailureAsync()
    {
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (status.State == DictationState.Failed && !status.IsFatal && current is null)
            {
                Publish(new(DictationState.Idle, null, null, false, lastResult is not null));
            }
        }
        finally { gate.Release(); }
    }

    public async ValueTask<Outcome<Unit>> ClearLastResultAsync(CancellationToken cancellationToken = default)
    {
        var operation = AttemptId.New();
        try { await gate.WaitAsync(cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) { return Outcome<Unit>.Cancelled(operation); }
        try
        {
            if (current is not null) { return Outcome<Unit>.Failed(operation, ErrorCode.Busy); }
            lastResult = null;
            Publish(status with
            {
                Recovery = status.Recovery is null ? null : status.Recovery with { CompletedText = null },
                HasLastResult = false
            });
            return Outcome<Unit>.Success(operation, default);
        }
        finally { gate.Release(); }
    }

    public async ValueTask WaitForQuiescenceAsync()
    {
        while (true)
        {
            Task[] tasks;
            lock (tasksGate) { tasks = background.ToArray(); }
            if (tasks.Length == 0) { return; }
            await Task.WhenAll(tasks).ConfigureAwait(false);
        }
    }

    private Outcome<Unit> Press(MonotonicTimestamp at, ProductPreferences preferences)
    {
        var operation = AttemptId.New();
        if (current is not null || status.State != DictationState.Idle)
        {
            return Outcome<Unit>.Failed(operation, ErrorCode.Busy);
        }
        if (preferences.SchemaVersion != 1 || ShortcutPolicy.Validate(preferences.Shortcut) != ErrorCode.None
            || !Enum.IsDefined(preferences.Language))
        {
            return Outcome<Unit>.Failed(operation, ErrorCode.NotReady);
        }
        if (string.IsNullOrWhiteSpace(preferences.MicrophoneEndpointId))
        {
            Publish(new(DictationState.Failed, operation,
                new(operation, ErrorCode.MicrophoneUnavailable, RecoveryAction.ChooseMicrophone, lastResult),
                false, lastResult is not null));
            return Outcome<Unit>.Failed(operation, ErrorCode.MicrophoneUnavailable);
        }
        var attempt = new Attempt(operation, at, preferences);
        current = attempt;
        shortcutContext?.SetAttemptActive(true);
        Publish(new(DictationState.Recording, operation, null, false, lastResult is not null));
        Track(StartAsync(attempt));
        return Outcome<Unit>.Success(operation, default);
    }

    private Outcome<Unit> Release(MonotonicTimestamp at)
    {
        if (current is not { } attempt) { return Outcome<Unit>.Failed(AttemptId.New(), ErrorCode.NotReady); }
        if (attempt.ReleaseRequested) { return Outcome<Unit>.Success(attempt.Id, default); }
        attempt.ReleaseRequested = true;
        attempt.ReleasedAt = at;
        if (!attempt.Started)
        {
            attempt.Cancelled = true;
            attempt.Cancellation.Cancel();
            ScheduleCancelAndFinish(attempt);
        }
        else
        {
            attempt.PipelineStarted = true;
            Track(CompleteAsync(attempt));
        }
        return Outcome<Unit>.Success(attempt.Id, default);
    }

    private Outcome<Unit> CancelCurrent()
    {
        if (current is not { } attempt) { return Outcome<Unit>.Success(AttemptId.New(), default); }
        if (!attempt.Cancelled)
        {
            attempt.Cancelled = true;
            attempt.Cancellation.Cancel();
            if (attempt.PipelineStarted)
            {
                attempt.CancelOutcomeTask ??= audio.CancelAsync(attempt.Id, CancellationToken.None).AsTask();
            }
            else { ScheduleCancelAndFinish(attempt); }
        }
        return Outcome<Unit>.Success(attempt.Id, default);
    }

    private async Task StartAsync(Attempt attempt)
    {
        attempt.TargetTask = targets.CaptureAsync(attempt.Id, attempt.PressedAt, attempt.Cancellation.Token).AsTask();
        Outcome<Unit> result;
        try
        {
            result = await audio.StartAsync(attempt.Id, attempt.Preferences.MicrophoneEndpointId,
                attempt.PressedAt, attempt.Cancellation.Token).ConfigureAwait(false);
        }
        catch (Exception) { result = Outcome<Unit>.Failed(attempt.Id, ErrorCode.CleanupFailed); }
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (!ReferenceEquals(current, attempt) || attempt.Cancelled || attempt.ReleaseRequested)
            {
                if (!attempt.Cancelled) { attempt.Cancelled = true; attempt.Cancellation.Cancel(); }
                ScheduleCancelAndFinish(attempt);
                return;
            }
            if (!result.IsSuccess)
            {
                Track(FailAfterCancelAsync(attempt, result.Failure?.Code ?? ErrorCode.MicrophoneUnavailable));
                return;
            }
            attempt.Started = true;
        }
        finally { gate.Release(); }
    }

    private async Task CompleteAsync(Attempt attempt)
    {
        if (!await OwnsAsync(attempt).ConfigureAwait(false)) { return; }
        if (!await PublishIfCurrentAsync(attempt,
            new(DictationState.Transcribing, attempt.Id, null, false, lastResult is not null)).ConfigureAwait(false)) { return; }
        AudioLease? audioLease = null;
        VerifiedModelLease? modelLease = null;
        ErrorCode? failure = null;
        try
        {
            var stopped = await audio.StopAsync(attempt.Id, attempt.ReleasedAt, attempt.Cancellation.Token).ConfigureAwait(false);
            if (!stopped.IsSuccess) { failure = stopped.Failure?.Code ?? ErrorCode.AudioShutdownFailed; return; }
            audioLease = stopped.Value!;
            if (!await OwnsAsync(attempt).ConfigureAwait(false)) { return; }
            var model = await models.AcquireVerifiedAsync(attempt.Id, attempt.Cancellation.Token).ConfigureAwait(false);
            if (!model.IsSuccess) { failure = model.Failure?.Code ?? ErrorCode.ModelMissing; return; }
            modelLease = model.Value!;
            if (!await OwnsAsync(attempt).ConfigureAwait(false)) { return; }
            var transcript = await transcriber.TranscribeAsync(attempt.Id, audioLease, modelLease,
                attempt.Preferences.Language, clock.GetTimestamp().Add(TimeSpan.FromSeconds(120)), attempt.Cancellation.Token).ConfigureAwait(false);
            if (transcript.Outcome == TranscriptOutcome.Silence) { return; }
            if (transcript.Outcome != TranscriptOutcome.Text)
            {
                failure = transcript.Outcome switch
                {
                    TranscriptOutcome.Cancelled => ErrorCode.Cancelled,
                    TranscriptOutcome.TimedOut => ErrorCode.TimedOut,
                    TranscriptOutcome.CorruptInput => ErrorCode.CorruptInput,
                    TranscriptOutcome.CorruptModel => ErrorCode.ModelCorrupt,
                    _ => ErrorCode.EngineFailure
                };
                return;
            }
            var text = OutputPolicy.Normalize(transcript.Text);
            if (text is null) { failure = ErrorCode.OutputInvalid; return; }
            if (!await OwnsAsync(attempt).ConfigureAwait(false)) { return; }
            lastResult = text;
            if (!await PublishIfCurrentAsync(attempt,
                new(DictationState.Inserting, attempt.Id, null, false, true)).ConfigureAwait(false)) { return; }
            var copied = await clipboard.CommitAsync(attempt.Id, text, attempt.Cancellation.Token).ConfigureAwait(false);
            if (!copied.IsSuccess) { failure = copied.Failure?.Code ?? ErrorCode.ClipboardBusy; return; }
            if (!await OwnsAsync(attempt).ConfigureAwait(false)) { return; }
            var target = attempt.TargetTask is null ? null : await attempt.TargetTask.ConfigureAwait(false);
            if (target is null || !target.IsSuccess)
            {
                failure = target?.Failure?.Code ?? ErrorCode.ManualPaste;
                return;
            }
            var insertion = await injector.TryInsertAsync(attempt.Id, target.Value!, copied.Value!, attempt.Cancellation.Token).ConfigureAwait(false);
            if (!insertion.IsSuccess || insertion.Value!.Disposition != InjectionDisposition.Dispatched)
            {
                failure = insertion.Failure?.Code ?? insertion.Value?.Reason ?? ErrorCode.ManualPaste;
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception) { failure = ErrorCode.CleanupFailed; }
        finally
        {
            var cleanupFailed = false;
            try { if (modelLease is not null) { await modelLease.DisposeAsync().ConfigureAwait(false); } }
            catch { cleanupFailed = true; }
            try { if (audioLease is not null) { await audioLease.DisposeAsync().ConfigureAwait(false); } }
            catch { cleanupFailed = true; }
            if (attempt.CancelOutcomeTask is { } cancellation)
            {
                try
                {
                    var result = await cancellation.ConfigureAwait(false);
                    if (!result.IsSuccess && result.Failure?.Code != ErrorCode.Cancelled) { cleanupFailed = true; }
                }
                catch { cleanupFailed = true; }
            }
            if (cleanupFailed) { failure = ErrorCode.CleanupFailed; }
            await FinishAsync(attempt, failure).ConfigureAwait(false);
        }
    }

    private async Task CancelAndFinishAsync(Attempt attempt)
    {
        Outcome<Unit> result;
        try { result = await audio.CancelAsync(attempt.Id, CancellationToken.None).ConfigureAwait(false); }
        catch (Exception) { result = Outcome<Unit>.Failed(attempt.Id, ErrorCode.CleanupFailed); }
        await FinishAsync(attempt, result.IsSuccess ? null : result.Failure?.Code ?? ErrorCode.CleanupFailed).ConfigureAwait(false);
    }

    private void ScheduleCancelAndFinish(Attempt attempt)
    {
        if (Interlocked.Exchange(ref attempt.CleanupStarted, 1) == 0)
        {
            Track(CancelAndFinishAsync(attempt));
        }
    }

    private async Task FailAfterCancelAsync(Attempt attempt, ErrorCode code)
    {
        Outcome<Unit> cancelled;
        try { cancelled = await audio.CancelAsync(attempt.Id, CancellationToken.None).ConfigureAwait(false); }
        catch (Exception) { cancelled = Outcome<Unit>.Failed(attempt.Id, ErrorCode.CleanupFailed); }
        await FinishAsync(attempt, cancelled.IsSuccess ? code : cancelled.Failure?.Code ?? ErrorCode.CleanupFailed).ConfigureAwait(false);
    }

    private async Task<bool> OwnsAsync(Attempt attempt)
    {
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try { return ReferenceEquals(current, attempt) && !attempt.Cancelled; }
        finally { gate.Release(); }
    }

    private async Task<bool> PublishIfCurrentAsync(Attempt attempt, DictationStatus value)
    {
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (!ReferenceEquals(current, attempt) || attempt.Cancelled) { return false; }
            Publish(value);
            return true;
        }
        finally { gate.Release(); }
    }

    private async Task FinishAsync(Attempt attempt, ErrorCode? failure)
    {
        if (attempt.TargetTask is { } target)
        {
            try { await target.ConfigureAwait(false); }
            catch { failure = ErrorCode.CleanupFailed; }
        }
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (!ReferenceEquals(current, attempt)) { return; }
            current = null;
            try { shortcutContext?.SetAttemptActive(false); }
            catch (Exception) { failure = ErrorCode.CleanupFailed; }
            try { if (targets is ITargetAttemptLifetime lifetime) { lifetime.End(attempt.Id); } }
            catch (Exception) { failure = ErrorCode.CleanupFailed; }
            attempt.Cancellation.Dispose();
            var fatal = failure is ErrorCode.AudioShutdownFailed or ErrorCode.CleanupFailed;
            if (fatal)
            {
                Publish(new(DictationState.Failed, attempt.Id,
                    new(attempt.Id, failure!.Value, RecoveryFor(failure.Value), lastResult), true, lastResult is not null));
                return;
            }
            if (attempt.Cancelled || failure is null || failure == ErrorCode.Cancelled)
            {
                Publish(new(DictationState.Idle, null, null, false, lastResult is not null));
                return;
            }
            Publish(new(DictationState.Failed, attempt.Id,
                new(attempt.Id, failure.Value, RecoveryFor(failure.Value), lastResult), fatal, lastResult is not null));
        }
        finally { gate.Release(); }
    }

    private static RecoveryAction RecoveryFor(ErrorCode error) => error switch
    {
        ErrorCode.MicrophoneDenied => RecoveryAction.OpenMicrophoneSettings,
        ErrorCode.MicrophoneUnavailable or ErrorCode.AudioFormatUnsupported => RecoveryAction.ChooseMicrophone,
        ErrorCode.MicrophoneDisconnected => RecoveryAction.ReconnectMicrophone,
        ErrorCode.MediaFoundationUnavailable => RecoveryAction.InstallMediaFeaturePack,
        ErrorCode.ModelMissing or ErrorCode.ModelCorrupt or ErrorCode.ModelDownloadFailed => RecoveryAction.DownloadOrImportModel,
        ErrorCode.ClipboardBusy or ErrorCode.ClipboardChanged or ErrorCode.CopyRequired => RecoveryAction.CopyAgain,
        ErrorCode.TargetChanged or ErrorCode.TargetUnsafe or ErrorCode.TargetUnknown or ErrorCode.ManualPaste => RecoveryAction.PasteManually,
        ErrorCode.AudioShutdownFailed or ErrorCode.CleanupFailed => RecoveryAction.ReopenApplication,
        _ => RecoveryAction.Retry
    };

    private void Publish(DictationStatus value)
    {
        status = value;
        foreach (var observer in StatusChanged?.GetInvocationList().Cast<Action<DictationStatus>>() ?? [])
        {
            try { observer(value); }
            catch (Exception) { }
        }
    }

    private void Track(Task task)
    {
        lock (tasksGate) { if (!background.Add(task)) { return; } }
        _ = task.ContinueWith(completed =>
        {
            lock (tasksGate) { background.Remove(completed); }
        }, CancellationToken.None, TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
    }

    public async ValueTask DisposeAsync()
    {
        await gate.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (disposed) { return; }
            disposed = true;
            CancelCurrent();
        }
        finally { gate.Release(); }
        await WaitForQuiescenceAsync().ConfigureAwait(false);
        lastResult = null;
    }

    private sealed class Attempt(AttemptId id, MonotonicTimestamp pressedAt, ProductPreferences preferences)
    {
        internal AttemptId Id { get; } = id;
        internal MonotonicTimestamp PressedAt { get; } = pressedAt;
        internal ProductPreferences Preferences { get; } = preferences;
        internal CancellationTokenSource Cancellation { get; } = new();
        internal Task<Outcome<TargetSnapshot>>? TargetTask;
        internal MonotonicTimestamp ReleasedAt;
        internal bool Started;
        internal bool ReleaseRequested;
        internal bool Cancelled;
        internal bool PipelineStarted;
        internal int CleanupStarted;
        internal Task<Outcome<Unit>>? CancelOutcomeTask;
    }
}
