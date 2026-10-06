# Resenha architecture

Status: macOS direct-distribution architecture implemented; Windows architecture accepted, implementation and physical acceptance pending

## macOS runtime flow

```text
configured global shortcut → listen-only CGEvent tap
        │ press                         │ release
        ▼                               ▼
capture target app → AVAudioRecorder → embedded whisper.cpp
                                            │
                                            ▼
                                  general pasteboard
                                            │
                           reactivate target + Command-V
```

## macOS distribution shape

One XcodeGen application target (`WhisperKey`, product name `Resenha`) and one unit-test target produce bundle `br.com.luisroquette.Resenha`. The arm64 macOS 14 app uses Hardened Runtime and direct distribution without App Sandbox. It embeds `whisper.xcframework`; no Homebrew, Python, shell, cloud transcription or API key is required.

## macOS components

| Component | Responsibility | Boundary |
|---|---|---|
| `HotkeyMonitor` | observe the exact user-selected press/release | listen-only; never suppresses events |
| `ShortcutCaptureController` | record and persist a shortcut inside Settings | local events only while recording |
| `AudioRecorder` | capture one temporary 16 kHz mono WAV | deletes stale/current audio |
| `WhisperTranscriber` | serialized embedded inference | local model and Metal/Accelerate |
| `TextInjector` | stage text, restore target focus and post `Command-V` | target, permission and clipboard guards |
| `DictationCoordinator` | own state, cancellation and cleanup | one active attempt; fail closed |
| `TranscriptHistory` | retain up to ten successful texts when enabled | local only; no audio or sync |

## macOS permissions

- Microphone captures speech only while the shortcut is held.
- Input Monitoring powers the global listen-only event tap.
- Accessibility reactivates the captured application and posts one paste command.

The app requests permissions only after explicit user action and exposes separate recovery destinations. It does not inspect another app's accessibility tree.

## macOS data lifecycle

- Audio: unique temporary file, deleted after success, failure or cancellation.
- Transcript: kept on the general pasteboard and optionally in a bounded local history.
- Model: persistent local file accepted only after exact size and SHA-256 verification.
- Preferences: local `UserDefaults`; no account or sync.
- Diagnostics: no raw audio or transcript content in logs.

## macOS validation boundary

Unit tests prove shortcut serialization/matching, permission combinations, clipboard staging and target identity. A signed app with real TCC grants must still prove physical TextEdit insertion, then browser and terminal compatibility. The legacy sandboxed Service design remains documented in SPEC-017 but is not registered in the direct bundle.

## Windows architecture — implementation available, Store acceptance pending

[SPEC-023](specs/23-windows-mvp.md) is the versioned Windows behavior contract;
[physical evidence](testing/WINDOWS-MVP-EVIDENCE.md) and
[release evidence](testing/WINDOWS-RELEASE-EVIDENCE.md) define its independent gates.
The accepted stack is C# 14/WPF, SDK 10.0.401, self-contained Desktop Runtime
10.0.12, win-x64 and a bundled pinned whisper.cpp CLI, with portable net10.0 Core
and MSTest.Sdk 4.4.0. The Windows TFM is net10.0-windows10.0.19041.0; actual
product guards require Home/Pro Windows 10 22H2 10.0.19045 or Windows 11 25H2
minimum 10.0.26200. Windows 10 physical compatibility is distinct from vendor
support. CPU readiness requires AVX2, FMA, F16C, SSE4.2, OS-enabled AVX state,
8 GiB RAM and free space of 1 GiB beyond the installed payload.

```text
passive keyboard edges → serialized coordinator → WASAPI shared microphone
  → bounded owned PCM16 mono 16 kHz WAV → verified model + child CLI job
  → deterministic text policy → STA Unicode clipboard commit/readback
  → isolated MTA target broker recheck → at most one SendInput Ctrl+V
```

WH_KEYBOARD_LL owns hold edges; the default is Left Ctrl + Left Alt + Space,
preserving ABNT2/AltGr. WH_MOUSE_LL observes button activity without coordinates
or history. TargetBroker uses local metadata-only IPC, no transcript access;
target changes permanently invalidate automatic insertion for the attempt.
No focus activation or field-value replacement is allowed. Nonactivating status
UI and one-instance ownership preserve editor focus and prevent concurrent capture.

Clipboard write failure keeps completed text in RAM with Copy again and no paste.
Unknown/protected/elevated targets use manual recovery. Dispatched input does
not prove editor acceptance; UIA/SendInput retain a last-instant focus race.
Windows stores no disk transcript history, audio/text logs, account or telemetry.
Only preferences and a hash-verified multilingual model persist; owned session
files are removed on every terminal path and next startup. Model download/import
is explicit; established dictation works offline. See [privacy](PRIVACY.md).

Consumer distribution uses a full-trust x64 MSIX through Microsoft Store, with
the exact identity copied from Partner Center. Microsoft signs an accepted Store
package. Synthetic CI MSIX files are unpacked for structural validation, remain
ephemeral and can never be submitted. The current public Inno Setup EXE is an
explicitly unsigned physical-test Beta and may trigger SmartScreen; it is not the
final channel. Store certification, a clean physical Store install and exact
package evidence precede replacing that Beta route on the website. See
[SPEC-024](specs/24-windows-store-msix.md) and
[Store evidence](testing/WINDOWS-STORE-EVIDENCE.md).

New implementation belongs to Windows/ and Scripts/windows/. Protected Swift,
macOS tests/project/config/framework/media/release scripts, existing output
fixtures and the whisper.cpp submodule pin remain outside the Windows edits.
Mac checks use mac-gate; Windows work uses a host mutex and two native workers.
Latest actual provider/PR checks are required, never an invented successful build.
