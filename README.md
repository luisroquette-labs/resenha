# Resenha

Local macOS push-to-talk dictation using Swift, AVFoundation, Accessibility, and whisper.cpp.

## Run

```sh
xcodegen generate
~/.local/bin/mac-gate xcodebuild -project WhisperKey.xcodeproj -scheme WhisperKey -destination 'platform=macOS' -derivedDataPath build test
open build/Build/Products/Debug/Resenha.app
```

Xcode uses automatic Apple Development signing. Contributors can select their own team in Xcode or override `DEVELOPMENT_TEAM` without changing source files.

Click the Resenha symbol in the menu bar, choose **Enable permissions**, grant Microphone, Accessibility, and Input Monitoring, then hold **Right Option** while speaking.

The preferred development model path is:

```text
~/Library/Application Support/WhisperKey/Models/ggml-large-v3-turbo-q5_0.bin
```

Audio is deleted after every attempt. The last 10 successful transcripts are stored locally with user-only permissions by default; this can be disabled and cleared in **Ajustes → Geral**.

## Interface and recovery

WhisperKey stays in the menu bar with no persistent main window. Its passive, click-through HUD shows Listening, Transcribing, Inserting or a concise failure. Idle is hidden; ready/failure feedback lasts approximately two seconds. The menu reports live activity and permission blockers.

While recording, a compact mist-green HUD shows elapsed time and 48 rounded bars driven by the real microphone level. Reduce Motion uses a stationary level display. No audio/level history is saved.

Open **Permissions** when access is missing, then choose the named **Open Microphone / Accessibility / Input Monitoring Settings** action. Only **Enable permissions** requests access; **Check permissions** refreshes it. If macOS still reports missing access after granting it, quit and reopen the same bundle. Polling never opens Settings automatically.

For a runtime/model or dictation failure, open **Status details** for safe cause and recovery guidance. No transcript, audio or subprocess stderr appears there. Hotkey presses during menu interaction or permission requests are ignored; release and press again after closing the menu.

## Validation status

The automated suite covers state transitions, permissions, hotkeys, local history, sounds, output processing and native-view fixtures. Actual microphone responsiveness, cross-app caret preservation, menu/VoiceOver and Spaces/display checks still require physical validation.

See [M0 evidence](docs/testing/M0-EVIDENCE.md) and [interface evidence](docs/testing/UI-REFINEMENT-EVIDENCE.md) for the tested revision, limitations and the 60-second phrase check.

## Resenha local sales/download site

Resenha is the public-facing product name; WhisperKey remains the internal native project/bundle name. The pt-BR site is one static document with a directly addressable `#download` section, not an installer or browser transcription app. It has no framework, build step, backend, visitor collection or shipped npm dependencies. Use Node.js; the recorded checks used Node v26.5.0 on macOS arm64.

From the repository root, start the loopback preview:

```sh
node Scripts/site.mjs --serve --port 4173 --prefix /
```

Open `http://127.0.0.1:4173/` or `http://127.0.0.1:4173/#download`. Stop this preview with Ctrl-C before using the same port for the repository-subpath preview:

```sh
node Scripts/site.mjs --serve --port 4173 --prefix /resenha/
```

Open `http://127.0.0.1:4173/resenha/#download`. Both mounts serve the same relative HTML/CSS/module files. Nothing is compiled or published. If port 4173 is already in use, stop only your own preview or choose another port.

Run the standard-library gate through the shared queue:

```sh
~/.local/bin/mac-gate node --test Scripts/site.test.mjs
```

Browser tools are isolated development dependencies, pinned in `Tools/site-audit/package-lock.json`. Install them and the Chromium/WebKit audit engines:

```sh
~/.local/bin/mac-gate npm ci --prefix Tools/site-audit
~/.local/bin/mac-gate Tools/site-audit/node_modules/.bin/playwright install chromium webkit
```

Setup downloads packages/browser engines; it does not call an AI provider. Run audits serially; each starts and closes its own loopback server and browser, so no separate preview process is required:

```sh
~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --browser
~/.local/bin/mac-gate node Tools/site-audit/audit.mjs --lighthouse
```

Success means exit 0 and zero failures in ignored `build/site-audit/{browser,lighthouse}/summary.json`. Missing packages or engines block the audit: repeat the locked setup, never count a skipped check as passing. Lighthouse measures three local mobile lab runs, not production visitors. See [Resenha site evidence](docs/testing/RESENHA-SITE-EVIDENCE.md) for hashes, all cases, zoom/accessibility observations and measured medians.

`site/release.mjs` exports the sole `releaseState`, `resolveDestination(channel, record)` and `applyReleaseState(root, state)` owners; `Scripts/site.mjs` exports `createPreviewServer({root, prefix, port})` with a close handle. Download/GitHub/App Store slots currently stay inactive with visible explanations. Synthetic test records do not establish public availability. Public GitHub/license publication, verified release packaging and App Store submission are separate later tasks; no remote, deployment or store destination is created here. The site does not close pending native CORE-001 acceptance or authorize native roadmap work.
