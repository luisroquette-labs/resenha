using System.Collections.Immutable;
using System.Diagnostics;
using System.IO.Pipes;
using System.Security.Cryptography;
using System.Text.Json;
using Resenha.Core;

namespace Resenha.Platform;

internal interface IFocusBrokerTransport
{
    ValueTask<TargetBrokerResponse?> ProbeAsync(AttemptId attempt, CancellationToken cancellationToken);
}

public sealed class TargetBrokerClient : ITargetProbe
{
    public static readonly TimeSpan BrokerTimeout = TimeSpan.FromMilliseconds(300);
    private readonly TargetActivityTracker activity;
    private readonly IClock clock;
    private readonly IFocusBrokerTransport broker;

    public TargetBrokerClient(string installationDirectory, TargetActivityTracker activity, IClock clock,
        IChildProcessJob? jobs = null)
        : this(activity, clock, new FocusBrokerTransport(installationDirectory, jobs ?? new ChildProcessJob())) { }

    internal TargetBrokerClient(TargetActivityTracker activity, IClock clock, IFocusBrokerTransport broker)
    {
        this.activity = activity ?? throw new ArgumentNullException(nameof(activity));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        this.broker = broker ?? throw new ArgumentNullException(nameof(broker));
    }

    public async ValueTask<Outcome<TargetSnapshot>> CaptureAsync(AttemptId attempt,
        MonotonicTimestamp pressedAt, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        var generation = activity.Begin(attempt);
        if (generation is null) { return Outcome<TargetSnapshot>.Failed(attempt, ErrorCode.TargetChanged); }
        var response = await ProbeAsync(attempt, cancellationToken).ConfigureAwait(false);
        if (response is null)
        {
            return cancellationToken.IsCancellationRequested
            ? Outcome<TargetSnapshot>.Cancelled(attempt)
            : Outcome<TargetSnapshot>.Failed(attempt, ErrorCode.TargetUnknown);
        }
        if (response.ProcessId == Environment.ProcessId)
        {
            return Outcome<TargetSnapshot>.Failed(attempt, ErrorCode.TargetUnsafe);
        }
        var classification = TargetIdentityPolicy.Classify(response);
        if (classification != TargetCheck.SameTarget)
        {
            return Outcome<TargetSnapshot>.Failed(attempt, classification switch
            {
                TargetCheck.Changed => ErrorCode.TargetChanged,
                TargetCheck.Unsafe => ErrorCode.TargetUnsafe,
                _ => ErrorCode.TargetUnknown
            });
        }
        var observed = activity.Read(attempt);
        if (!observed.Safe || observed.Generation != generation.Value)
        {
            return Outcome<TargetSnapshot>.Failed(attempt, ErrorCode.TargetChanged);
        }
        return Outcome<TargetSnapshot>.Success(attempt, TargetIdentityPolicy.ToSnapshot(
            response, generation.Value, clock.GetTimestamp()));
    }

    public async ValueTask<Outcome<TargetCheck>> CheckAsync(AttemptId attempt,
        TargetSnapshot target, CancellationToken cancellationToken)
    {
        attempt.ThrowIfEmpty();
        if (target.Attempt != attempt) { return Outcome<TargetCheck>.Failed(attempt, ErrorCode.TargetChanged); }
        var before = activity.Read(attempt);
        if (!before.Safe || before.Generation != target.FocusGeneration)
        {
            return Outcome<TargetCheck>.Success(attempt, TargetCheck.Changed);
        }
        var response = await ProbeAsync(attempt, cancellationToken).ConfigureAwait(false);
        if (response is null)
        {
            return cancellationToken.IsCancellationRequested
            ? Outcome<TargetCheck>.Cancelled(attempt)
            : Outcome<TargetCheck>.Success(attempt, TargetCheck.Unknown);
        }
        var after = activity.Read(attempt);
        var result = !after.Safe || after.Generation != target.FocusGeneration
            ? TargetCheck.Changed : TargetIdentityPolicy.Compare(target, response);
        return Outcome<TargetCheck>.Success(attempt, result);
    }

    public void End(AttemptId attempt) => activity.End(attempt);

    private async ValueTask<TargetBrokerResponse?> ProbeAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(BrokerTimeout);
        try { return await broker.ProbeAsync(attempt, deadline.Token).ConfigureAwait(false); }
        catch (OperationCanceledException) { return null; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException
            or JsonException or InvalidDataException or ArgumentException
            or System.ComponentModel.Win32Exception or PlatformNotSupportedException)
        { return null; }
    }
}

internal static class TargetIdentityPolicy
{
    internal static TargetCheck Classify(TargetBrokerResponse response)
    {
        if (response.SchemaVersion != 1 || response.Status == "changed") { return TargetCheck.Changed; }
        if (response.Status == "unsafe" || response.IsPassword || !response.IsEditable || response.IsReadOnly
            || response.Integrity is TargetIntegrity.Unknown or TargetIntegrity.High or TargetIntegrity.System)
        {
            return TargetCheck.Unsafe;
        }
        if (response.Status != "ok" || response.ForegroundWindow == 0 || response.RootWindow == 0
            || response.ProcessId == 0 || response.ProcessCreationFileTime <= 0 || response.SessionId == uint.MaxValue
            || string.IsNullOrWhiteSpace(response.DesktopIdentity) || response.AutomationRuntimeId.IsDefaultOrEmpty)
        {
            return TargetCheck.Unknown;
        }
        return TargetCheck.SameTarget;
    }

    internal static TargetSnapshot ToSnapshot(TargetBrokerResponse response, long generation, MonotonicTimestamp capturedAt) =>
        new(new(response.Attempt), response.ForegroundWindow, response.RootWindow, response.FocusedChildWindow,
            response.ProcessId, response.ProcessCreationFileTime, response.SessionId, response.DesktopIdentity,
            response.Integrity, response.AutomationRuntimeId, response.ControlType, response.IsPassword,
            response.IsEditable, response.IsReadOnly, generation,
            response.SelectionToken is null ? null : new(response.SelectionToken, response.HasCaret, response.HasSelection), capturedAt);

    internal static TargetCheck Compare(TargetSnapshot expected, TargetBrokerResponse actual)
    {
        var classification = Classify(actual);
        if (classification != TargetCheck.SameTarget) { return classification; }
        if (actual.Attempt != expected.Attempt.Value || actual.ForegroundWindow != expected.ForegroundWindow
            || actual.RootWindow != expected.RootWindow || actual.FocusedChildWindow != expected.FocusedChildWindow
            || actual.ProcessId != expected.ProcessId || actual.ProcessCreationFileTime != expected.ProcessCreationFileTime
            || actual.SessionId != expected.SessionId || actual.DesktopIdentity != expected.DesktopIdentity
            || actual.Integrity != expected.Integrity || actual.ControlType != expected.ControlType
            || !actual.AutomationRuntimeId.SequenceEqual(expected.AutomationRuntimeId)
            || actual.SelectionToken != expected.Selection?.Token || actual.HasCaret != expected.Selection?.HasCaret
            || actual.HasSelection != expected.Selection?.HasSelection)
        {
            return TargetCheck.Changed;
        }
        return TargetCheck.SameTarget;
    }
}

internal sealed class FocusBrokerTransport : IFocusBrokerTransport
{
    private const int MaximumPayload = 64 * 1024;
    private readonly string executable;
    private readonly string workingDirectory;
    private readonly IChildProcessJob jobs;

    internal FocusBrokerTransport(string installationDirectory, IChildProcessJob jobs)
    {
        if (!Path.IsPathFullyQualified(installationDirectory)) { throw new ArgumentException("An absolute installation directory is required.", nameof(installationDirectory)); }
        workingDirectory = Path.GetFullPath(installationDirectory);
        executable = Path.Combine(workingDirectory, "Resenha.TargetBroker.exe");
        this.jobs = jobs;
    }

    public async ValueTask<TargetBrokerResponse?> ProbeAsync(AttemptId attempt, CancellationToken cancellationToken)
    {
        var pipeName = "resenha-focus-" + Guid.NewGuid().ToString("N");
        var nonce = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(32));
        await using var pipe = new NamedPipeServerStream(pipeName, PipeDirection.In, 1,
            PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly, 4096, 4096);
        await using var child = jobs.Start(new(executable, workingDirectory,
            ImmutableArray.Create("--pipe", pipeName, "--attempt", attempt.Value.ToString("D"), "--nonce", nonce)));
        try
        {
            await pipe.WaitForConnectionAsync(cancellationToken).ConfigureAwait(false);
            var header = new byte[4];
            await pipe.ReadExactlyAsync(header, cancellationToken).ConfigureAwait(false);
            var length = BitConverter.ToInt32(header);
            if (length is <= 0 or > MaximumPayload) { throw new InvalidDataException(); }
            var payload = new byte[length];
            await pipe.ReadExactlyAsync(payload, cancellationToken).ConfigureAwait(false);
            var response = JsonSerializer.Deserialize<TargetBrokerResponse>(payload);
            if (response is null || response.Attempt != attempt.Value || response.Nonce != nonce
                || response.BrokerProcessId != child.ProcessId) { throw new InvalidDataException(); }
            var exit = await child.WaitForExitAsync(TargetBrokerClient.BrokerTimeout, cancellationToken).ConfigureAwait(false);
            return exit.Outcome == ChildProcessExit.Exited && exit.ExitCode == 0 ? response : null;
        }
        catch
        {
            await child.TerminateAsync().ConfigureAwait(false);
            throw;
        }
    }
}
