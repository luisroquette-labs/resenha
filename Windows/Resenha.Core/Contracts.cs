using System.Collections.Immutable;
using System.Text.Json.Serialization;

namespace Resenha.Core;

public readonly record struct AttemptId(Guid Value)
{
    public static AttemptId New() => new(Guid.NewGuid());

    public void ThrowIfEmpty()
    {
        if (Value == Guid.Empty)
        {
            throw new ArgumentException("An operation must have an attempt identity.");
        }
    }
}

// Ticks are TimeSpan ticks from one process-local monotonic origin, never UTC.
// Platform clocks normalize QPC to this unit before publishing timestamps.
public readonly record struct MonotonicTimestamp(long Ticks)
{
    public MonotonicTimestamp Add(TimeSpan duration) => new(checked(Ticks + duration.Ticks));
    public TimeSpan ElapsedSince(MonotonicTimestamp earlier) => TimeSpan.FromTicks(checked(Ticks - earlier.Ticks));
}

public readonly record struct Unit;

public enum OutcomeKind { Succeeded, Failed, Cancelled, TimedOut }

public enum ErrorCode
{
    None, Cancelled, TimedOut, NotReady, Busy, ShortcutInvalid, ShortcutOccupied,
    HookUnavailable, HoldInterrupted, MicrophoneDenied, MicrophoneUnavailable,
    MicrophoneDisconnected, AudioFormatUnsupported, AudioTimestampInvalid,
    AudioShutdownFailed, AudioTooShort, ModelMissing, ModelCorrupt, ModelDownloadFailed,
    StorageUnsafe, CleanupFailed, CorruptInput, EngineFailure, OutputInvalid,
    TargetChanged, TargetUnsafe, TargetUnknown, ClipboardBusy, ClipboardChanged,
    CopyRequired, ManualPaste, UnsupportedPlatform, UnsupportedCpu
}

// Failures contain codes only: no native exception strings, paths, audio or text.
public sealed record Failure(ErrorCode Code);

public sealed record Outcome<T>
{
    private Outcome(AttemptId attempt, OutcomeKind kind, T? value, Failure? failure)
    {
        attempt.ThrowIfEmpty();
        Attempt = attempt;
        Kind = kind;
        Value = value;
        Failure = failure;
    }

    public AttemptId Attempt { get; }
    public OutcomeKind Kind { get; }
    public T? Value { get; }
    public Failure? Failure { get; }
    public bool IsSuccess => Kind == OutcomeKind.Succeeded;

    public static Outcome<T> Success(AttemptId attempt, T value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return new(attempt, OutcomeKind.Succeeded, value, null);
    }

    public static Outcome<T> Failed(AttemptId attempt, ErrorCode code)
    {
        if (code is ErrorCode.None or ErrorCode.Cancelled or ErrorCode.TimedOut)
        {
            throw new ArgumentOutOfRangeException(nameof(code));
        }

        return new(attempt, OutcomeKind.Failed, default, new(code));
    }

    public static Outcome<T> Cancelled(AttemptId attempt) => new(attempt, OutcomeKind.Cancelled, default, new(ErrorCode.Cancelled));
    public static Outcome<T> TimedOut(AttemptId attempt) => new(attempt, OutcomeKind.TimedOut, default, new(ErrorCode.TimedOut));
}

[Flags]
public enum ShortcutModifiers
{
    None = 0, LeftControl = 1, RightControl = 2, LeftAlt = 4, RightAlt = 8,
    LeftShift = 16, RightShift = 32, LeftWindows = 64, RightWindows = 128
}

public sealed record Shortcut(ushort ScanCode, bool IsExtended, ShortcutModifiers Modifiers);
public enum ShortcutEdgeKind { Pressed, Released, Interrupted }
public sealed record ShortcutEdge(ShortcutEdgeKind Kind, MonotonicTimestamp At);
public enum DictationLanguage { Pt, En, Es }
public enum DictationState { Idle, Recording, Transcribing, Inserting, Failed }

public static class LanguageCodes
{
    public static string ToWhisperCode(this DictationLanguage language) => language switch
    {
        DictationLanguage.Pt => "pt",
        DictationLanguage.En => "en",
        DictationLanguage.Es => "es",
        _ => throw new ArgumentOutOfRangeException(nameof(language))
    };
}

public sealed record ProductPreferences(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("shortcut")] Shortcut Shortcut,
    [property: JsonPropertyName("microphoneEndpointId")] string MicrophoneEndpointId,
    [property: JsonPropertyName("language")] DictationLanguage Language);

public enum RecoveryAction { None, Retry, OpenMicrophoneSettings, ChooseMicrophone, ReconnectMicrophone, DownloadOrImportModel, CopyAgain, PasteManually, ReopenApplication }

// Action is a stable localization key. Completed text belongs only to RAM.
public sealed record RecoveryStatus(AttemptId Attempt, ErrorCode Code, RecoveryAction Action, [property: JsonIgnore] string? CompletedText = null)
{
    public override string ToString() => $"{nameof(RecoveryStatus)} {{ Attempt = {Attempt}, Code = {Code}, Action = {Action} }}";
}

public sealed record AudioEnergySummary(double RootMeanSquareDbfs, long FramesAboveThreshold, TimeSpan ActiveDuration);
public sealed record AudioDescriptor(
    AttemptId Attempt, string OwnedPath, long FrameCount, TimeSpan Duration,
    AudioEnergySummary Energy, MonotonicTimestamp PressedAt, MonotonicTimestamp ReleasedAt)
{
    public const int SampleRate = 16_000;
    public const int Channels = 1;
    public const int BitsPerSample = 16;
}

public sealed record ModelDescriptor(string FileName, long ByteLength, string Sha256);

// A lease is a class, not a copyable record. Concurrent disposal joins one task;
// failures remain observable. Cleanup must not accept a cancelled attempt token.
public abstract class OwnedLease : IAsyncDisposable
{
    private readonly object disposalLock = new();
    private Task? disposal;

    protected OwnedLease(AttemptId attempt)
    {
        attempt.ThrowIfEmpty();
        Attempt = attempt;
    }

    public AttemptId Attempt { get; }

    public bool IsDisposalStarted
    {
        get { lock (disposalLock) { return disposal is not null; } }
    }

    public bool IsDisposed
    {
        get { lock (disposalLock) { return disposal?.IsCompletedSuccessfully == true; } }
    }

    public ValueTask DisposeAsync()
    {
        lock (disposalLock)
        {
            disposal ??= DisposeOnceAsync();
            return new ValueTask(disposal);
        }
    }

    public void RequireUsableBy(AttemptId attempt)
    {
        if (attempt != Attempt || IsDisposalStarted)
        {
            throw new InvalidOperationException("The lease is not available to this attempt.");
        }
    }

    private async Task DisposeOnceAsync() => await DisposeCoreAsync().ConfigureAwait(false);
    protected abstract ValueTask DisposeCoreAsync();
}

public abstract class AudioLease : OwnedLease
{
    protected AudioLease(AudioDescriptor audio) : base(audio.Attempt)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(audio.OwnedPath);
        if (audio.FrameCount < 0 || audio.Duration < TimeSpan.Zero || audio.ReleasedAt.Ticks < audio.PressedAt.Ticks)
        {
            throw new ArgumentException("Invalid owned audio interval.", nameof(audio));
        }

        Audio = audio;
    }

    public AudioDescriptor Audio { get; }
}

// The concrete model-store lease MUST retain an open verified read handle that
// denies write/delete until disposal; a path/hash by itself is not such a lease.
public abstract class VerifiedModelLease : OwnedLease
{
    protected VerifiedModelLease(AttemptId attempt, ModelDescriptor model, string ownedPath) : base(attempt)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ownedPath);
        ArgumentNullException.ThrowIfNull(model);
        Model = model;
        OwnedPath = ownedPath;
    }

    public ModelDescriptor Model { get; }
    public string OwnedPath { get; }
}

public enum TranscriptOutcome { Text, Silence, Cancelled, TimedOut, CorruptInput, CorruptModel, EngineFailure }

public sealed record TranscriptResult
{
    private TranscriptResult(AttemptId attempt, TranscriptOutcome outcome, string? text)
    {
        attempt.ThrowIfEmpty();
        Attempt = attempt;
        Outcome = outcome;
        Text = text;
    }

    public AttemptId Attempt { get; }
    public TranscriptOutcome Outcome { get; }
    public string? Text { get; }

    public static TranscriptResult Completed(AttemptId attempt, string text)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(text);
        return new(attempt, TranscriptOutcome.Text, text);
    }

    public static TranscriptResult WithoutText(AttemptId attempt, TranscriptOutcome outcome)
    {
        if (outcome == TranscriptOutcome.Text || !Enum.IsDefined(outcome))
        {
            throw new ArgumentOutOfRangeException(nameof(outcome));
        }

        return new(attempt, outcome, null);
    }

    public override string ToString() => $"{nameof(TranscriptResult)} {{ Attempt = {Attempt}, Outcome = {Outcome} }}";
}

// Handles are unsigned metadata, not Windows/UI references in the portable Core.
// Runtime IDs and selection tokens contain identity only, never field contents.
public enum TargetIntegrity { Unknown, Low, Medium, High, System }
public enum TargetCheck { SameTarget, Changed, Unsafe, Unknown }
public sealed record SelectionIdentity(string Token, bool HasCaret, bool HasSelection);
public sealed record TargetSnapshot(
    AttemptId Attempt, ulong ForegroundWindow, ulong RootWindow, ulong FocusedChildWindow,
    uint ProcessId, long ProcessCreationFileTime, uint SessionId, string DesktopIdentity,
    TargetIntegrity Integrity, ImmutableArray<int> AutomationRuntimeId, int ControlType,
    bool IsPassword, bool IsEditable, bool IsReadOnly, long FocusGeneration,
    SelectionIdentity? Selection, MonotonicTimestamp CapturedAt);

public sealed record ClipboardToken
{
    [JsonConstructor]
    public ClipboardToken(AttemptId attempt, uint sequenceNumber, string textSha256)
    {
        attempt.ThrowIfEmpty();
        if (sequenceNumber == 0)
        {
            throw new ArgumentOutOfRangeException(nameof(sequenceNumber));
        }

        if (textSha256 is null || textSha256.Length != 64 || !textSha256.All(Uri.IsHexDigit))
        {
            throw new ArgumentException("Expected a SHA-256 hexadecimal digest.", nameof(textSha256));
        }

        Attempt = attempt;
        SequenceNumber = sequenceNumber;
        TextSha256 = textSha256.ToLowerInvariant();
    }

    public AttemptId Attempt { get; }
    public uint SequenceNumber { get; }
    public string TextSha256 { get; }
}

public enum InjectionDisposition { Dispatched, ManualPaste, CopyRequired }
public sealed record InjectionResult(InjectionDisposition Disposition, ErrorCode Reason);

public interface IClock
{
    MonotonicTimestamp GetTimestamp();
    ValueTask<Outcome<Unit>> DelayUntilAsync(AttemptId attempt, MonotonicTimestamp deadline, CancellationToken cancellationToken);
}

// Configuration/listening calls use operation IDs. Raw edges have no dictation
// attempt yet: only the coordinator allocates that ID when accepting a press.
public interface IShortcutSource
{
    event Action<ShortcutEdge>? Edge;
    ValueTask<Outcome<Unit>> ConfigureAsync(AttemptId attempt, Shortcut shortcut, CancellationToken cancellationToken);
    ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, CancellationToken cancellationToken);
    ValueTask<Outcome<Unit>> StopAsync(AttemptId attempt, CancellationToken cancellationToken);
}

public interface IAudioRecorder
{
    ValueTask<Outcome<Unit>> StartAsync(AttemptId attempt, string deviceId, MonotonicTimestamp pressedAt, CancellationToken cancellationToken);
    ValueTask<Outcome<AudioLease>> StopAsync(AttemptId attempt, MonotonicTimestamp releasedAt, CancellationToken cancellationToken);
    ValueTask<Outcome<Unit>> CancelAsync(AttemptId attempt, CancellationToken cancellationToken);
}

public interface IModelStore
{
    ValueTask<Outcome<VerifiedModelLease>> AcquireVerifiedAsync(AttemptId attempt, CancellationToken cancellationToken);
}

public interface ITranscriber
{
    ValueTask<TranscriptResult> TranscribeAsync(AttemptId attempt, AudioLease audio, VerifiedModelLease model, DictationLanguage language, MonotonicTimestamp deadline, CancellationToken cancellationToken);
}

public interface ITargetProbe
{
    ValueTask<Outcome<TargetSnapshot>> CaptureAsync(AttemptId attempt, MonotonicTimestamp pressedAt, CancellationToken cancellationToken);
    ValueTask<Outcome<TargetCheck>> CheckAsync(AttemptId attempt, TargetSnapshot target, CancellationToken cancellationToken);
}

public interface IClipboard
{
    ValueTask<Outcome<ClipboardToken>> CommitAsync(AttemptId attempt, string text, CancellationToken cancellationToken);
    ValueTask<Outcome<bool>> IsCurrentAsync(AttemptId attempt, ClipboardToken token, CancellationToken cancellationToken);
}

public interface ITextInjector
{
    ValueTask<Outcome<InjectionResult>> TryInsertAsync(AttemptId attempt, TargetSnapshot target, ClipboardToken clipboard, CancellationToken cancellationToken);
}
