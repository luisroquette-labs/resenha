# Windows MVP — physical protocol and blank evidence

Status: pending. No physical Windows run or host possession is established.
Contract: [SPEC-023](../specs/23-windows-mvp.md).
Release identity: [release evidence](WINDOWS-RELEASE-EVIDENCE.md).

Use one separate completed copy per physical OS run, retaining this blank template.
VMs/mocks/cross-compiles supplement, never replace physical hardware. Every
observed value, result and attachment starts pending; replace it only with actual
observations. Blocked/skipped/unrun cases cannot count as passed. Use owned test
speech and synthetic form data; keep personal identifiers and private speech out
of published reports. Each attachment needs path, SHA-256 and UTC capture time.

## Run identity and prerequisites

| Field | Observed value |
| --- | --- |
| Run ID / UTC / verifier / host permission | pending |
| Physical hardware evidence / anonymized host ID / dual-boot identity | pending |
| Windows edition / release / complete version including revision / x64 | pending |
| OS predicate (10 Home/Pro 22H2 10.0.19045 or 11 Home/Pro 25H2 ≥10.0.26200) | pending |
| Security update state / Media Feature Pack if Windows N | pending |
| CPU model / AVX2 / FMA / F16C / SSE4.2 / OS-enabled AVX state probe report | pending |
| Installed RAM GiB / logical processors / free disk beyond payload | pending |
| Standard-user integrity / no preinstalled .NET or compiler tools | pending |
| Microphone endpoint / driver / actual mix format / ABNT2 keyboard | pending |
| Chrome version / Notepad version / display configuration | pending |
| Native candidate source SHA / current PR SHA / unchanged-input comparison | pending |
| App version / package filename / exact final installer size and SHA-256 | pending |
| Model name / measured bytes / SHA-256 / explicit download or import | pending |
| whisper.cpp commit / CLI hash / SDK / runtime / full toolchain report hash | pending |
| Windows preflight command / exit / log path / SHA-256 / skipped tests | pending |
| Licensed corpus manifest / reference commit / audio hashes | pending |
| Host, certificate, model or fixture blocker / owner / required action | pending |

Before running, compare installer/model to the release dossier using
`Get-FileHash -Algorithm SHA256 <resolved-path>`. Record `dotnet --info` from
`Windows/` on the build host; do not require an SDK on the clean test profile.
The proposed collector `pwsh -NoProfile -File Scripts/windows/collect-physical-evidence.ps1`
may collect metadata, but a successful exit cannot fill human observations.

## Notepad and Chrome insertion protocol

1. Install the exact candidate as a standard user; open Notepad with synthetic
   prefix/suffix text and the caret between them. Choose PT-BR and the microphone.
   Hold Left Ctrl + Left Alt + Space, speak, release, and observe state/mic/clipboard
   ordering and a single insertion. Record intended speech, actual output and
   caret placement; distinguish dispatched input from editor acceptance.
2. Repeat with selected existing text; record whether one normal paste replaced
   only that selection. Repeat in Chrome `input`, `textarea` and `contenteditable`
   fields, including PT-BR accents. Record browser/provider versions and each result.
3. Change shortcut; test invalid/occupied chords, auto-repeat, busy press and
   each required-key release order. On ABNT2 type AltGr characters before/after
   dictation and during a canceled attempt; Right Alt/AltGr must not start it.
4. Change app, switch two Chrome fields sharing a HWND, move caret/selection,
   type a non-shortcut key and click during transcription; return to the original
   field. Each invalidates automatic insertion; manually paste the clipboard.
   Test a last-instant focus change immediately before dispatch and record any
   residual race rather than claiming an atomic focus/paste guarantee.
5. Exercise a normal-user attempt into elevated/protected/password/read-only
   fields and an unidentifiable UIA provider. Observe actionable manual recovery,
   no privilege escalation, no forced focus and no automatic paste retry. Start
   another valid attempt and confirm the app operates again.

| Case / expected observation | Actual text / clipboard / caret / dispatch count / attachment / result |
| --- | --- |
| Notepad caret, accents and selected text | pending |
| Chrome input, textarea and contenteditable, separate field identities | pending |
| ABNT2 / AltGr unchanged, shortcut configuration/conflicts/repeat | pending |
| Focus loss/return, caret/selection change, typing, mouse activity | pending |
| Last-instant focus race, target disappearance/PID or HWND reuse | pending |
| Elevated/protected/password/read-only/unknown provider manual fallback | pending |
| Clipboard before one paste; partial SendInput and accepted-but-rejected input | pending |

## Failure and lifecycle matrix

For each row induce the named condition at its producer boundary, record the
visible code/action, resources before/after, cleanup deadline and one subsequent
successful session. Restore the device/model/permission manually. No failed
session may silently retry, paste partial text or queue a recording.

| Case | Required observation/action | Actual / next session / attachment / result |
| --- | --- | --- |
| Microphone permission denied | MicrophoneDenied; open ms-settings:privacy-microphone; no capture | pending |
| Missing/disabled endpoint | MicrophoneUnavailable; Choose microphone | pending |
| Disconnect during startup/capture | MicrophoneDisconnected; Reconnect then retry; partial audio removed | pending |
| Unsupported audio/Media Foundation unavailable | Actionable format/Media Feature Pack setup error | pending |
| Discontinuous/uncertain timestamps | Discard uncertain audio, no inference/paste | pending |
| Missing model | Download/import again; recording disabled | pending |
| Corrupt/wrong-size/hash model | Reject before inference; preserve valid prior model on replacement failure | pending |
| Download interrupted/stalled/import failure | .partial cleanup, bounded deadline, explicit manual retry | pending |
| Unsupported CPU or OS AVX state | Readiness error before launching CLI | pending |
| CLI crash/nonzero/missing/malformed/oversized output | Typed inference error; no text/paste; job and files closed | pending |
| Inference timeout | Kill job; bounded exit/cleanup; manual retry only | pending |
| Clipboard contention through 500 ms | CopyRequired; retain completed text in RAM; no paste | pending |
| External clipboard replacement after commit | Do not overwrite newer clipboard or paste; Copy again explicit | pending |
| Blocked/partial/ambiguous SendInput | ManualPaste; useful copied output; no automatic retry | pending |
| TargetBroker timeout / mouse observer failure | Unknown target; clipboard-only recovery | pending |
| Escape/tray cancel/open settings | Invalidate attempt before cleanup; no stale completion | pending |
| Release during async microphone start | Late start canceled; no post-release capture | pending |
| Lost release/extra modifier/120-second maximum | Watchdog cancel/discard; all keys up before rearm | pending |
| Lock/suspend/desktop change/resume | Cancel; no stuck mic/hook; reinitialize before rearm | pending |
| Exit during recording/inference / second app launch | Children/hooks exit; one instance; no second recorder | pending |
| Audio stop acknowledgment missing | Fail closed/reopen; never falsely idle with active microphone | pending |
| Forced termination/next launch | Remove only abandoned owned sessions before ready | pending |
| Cleanup failure/reparse-point traversal | Visible blocker; no unsafe deletion or silent retention | pending |
| Stale completion after cancellation/new attempt | No copy/paste/UI reset/deletion of new attempt | pending |

## Ten cycles per OS

After fault recovery, dictate ten consecutive real utterances on each physical OS
with the same final installer hash. Alternate Notepad and Chrome. For every cycle
record one recording, clipboard outcome, insertion count, idle/cleanup and latency.
Do not collapse these observations to a single checkbox.

| Cycle | Windows 10 speech/output/target/clipboard/insertion/idle/cleanup/seconds/result | Windows 11 speech/output/target/clipboard/insertion/idle/cleanup/seconds/result |
| --- | --- | --- |
| 01 | pending | pending |
| 02 | pending | pending |
| 03 | pending | pending |
| 04 | pending | pending |
| 05 | pending | pending |
| 06 | pending | pending |
| 07 | pending | pending |
| 08 | pending | pending |
| 09 | pending | pending |
| 10 | pending | pending |

## Offline corpus and multilingual quality

1. Commit owned/licensed audio, reference transcripts and anglicism annotations
   before inference. At least five utterances per language must cover accents,
   names, punctuation and mixed vocabulary. Record license/manifest/audio hashes.
2. Download/import and verify the model explicitly, disconnect networking, and
   run the real bundled CLI and physical dictation with explicit PT-BR/EN/ES.
   Record selection persistence after restart and network/process traces.
3. Compute WER `(substitutions + deletions + insertions) / reference words`
   per language. Document Unicode/case/punctuation/whitespace normalization
   applied identically to references/results; do not remove substantive words
   or anglicisms, translate or rewrite to improve the metric. Require ≤20% WER.
4. Count preserved annotated anglicism occurrences/reference occurrences in
   PT-BR and ES; require ≥90%. Retain actual output and counts for each fixture.
   Run silence, empty and <300 ms inputs: no generated text, copy or paste.
5. Observe WAV/result deletion after success/error/cancel/exit and next-start
   forced-termination cleanup. Inspect logs for audio/text retention and record
   cold/warm timing, duration, CPU/RAM/model/hardware; no unmeasured speed claim.

| Fixture group | Reference/audio hashes / actual results / word S-D-I-N counts / anglicism preserved-total / result |
| --- | --- |
| PT-BR 01–05 minimum | pending |
| EN 01–05 minimum | pending |
| ES 01–05 minimum | pending |
| Silence / empty / short input | pending |
| PT-BR WER ≤20% / anglicism retention ≥90% | pending |
| EN WER ≤20% | pending |
| ES WER ≤20% / anglicism retention ≥90% | pending |
| Offline trace / no audio or transcript logs / preferences survive restart | pending |
| Success/error/cancel/exit/next-start owned-file snapshots | pending |
| Cold/warm seconds / recording duration / peak CPU / RAM | pending |

## Installation and owned-data removal

Use a clean standard-user profile with spaces and non-ASCII path components, no
preinstalled .NET/SDK/compiler. Install, choose microphone/model, run offline,
exit and uninstall the same exact signed package on both OS targets. Verify no
orphan app/CLI/broker processes, hooks, service, startup entry, scheduled task,
driver or owned session files. The default **Remove model and settings** option
must remove only canonical app-owned data; a second trial explicitly retains
them and records the paths. Preserve original imported model, unrelated sentinel
files, documents and clipboard; cleanup does not promise forensic secure erasure.

| Observation | Windows 10 value/result | Windows 11 value/result |
| --- | --- | --- |
| Clean install, normal user, self-contained runtime, final package hash | pending | pending |
| Spaces/non-ASCII install and removal paths | pending | pending |
| Exit/uninstall: no processes/hooks/startup or owned sessions remain | pending | pending |
| Default model/settings removal and explicit retention trial | pending | pending |
| Imported source/document/unrelated sentinel/clipboard preserved | pending | pending |

## Acceptance ledger and blockers

CK/HR mapping and producers are defined in [SPEC-023](../specs/23-windows-mvp.md).
Attach each result to a run/source/installer/model/report hash. This physical
dossier supplies CK-1 through CK-7 and HR-1/2/3; CK-8/9/10 additionally require
the signature/scan/hosting/form records in the release dossier.

| Gate | Result / evidence references / reviewer |
| --- | --- |
| CK-1 | pending |
| CK-2 | pending |
| CK-3 | pending |
| CK-4 | pending |
| CK-5 | pending |
| CK-6 | pending |
| CK-7 | pending |
| CK-8 | pending |
| CK-9 | pending |
| CK-10 | pending |
| HR-1 | pending |
| HR-2 | pending |
| HR-3 | pending |
| Missing physical host / owner / provisioning action | pending |
| Missing certificate / owner / approved signing action | pending |
| Missing form/hosting/toolchain/fixtures / owner / action | pending |
| Final physical acceptance and Windows availability | pending |
