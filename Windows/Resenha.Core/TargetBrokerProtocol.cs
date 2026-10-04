using System.Collections.Immutable;

namespace Resenha.Core;

public sealed record TargetBrokerResponse(
    int SchemaVersion, string Nonce, Guid Attempt, uint BrokerProcessId,
    ulong ForegroundWindow, ulong RootWindow, ulong FocusedChildWindow,
    uint ProcessId, long ProcessCreationFileTime, uint SessionId, string DesktopIdentity,
    TargetIntegrity Integrity, ImmutableArray<int> AutomationRuntimeId, int ControlType,
    bool IsPassword, bool IsEditable, bool IsReadOnly, string? SelectionToken,
    bool HasCaret, bool HasSelection, string Status);
