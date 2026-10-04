# Corpus provenance and current blocker

No speech recordings, speaker permissions or audio licenses were supplied.
There are **no licensed-audio or accuracy claims** in this directory. The
manifest deliberately has null audio hashes/rights and a blocked status;
real corpus tests fail until these prerequisites are present. WER and
anglicism retention have not been measured.

The fifteen newly authored recording prompts in `speech-corpus.json` are
project test source under the repository's MIT license (`../../LICENSE`).
They are prospective references, not transcripts asserted from existing audio.
No existing macOS `Tests/Fixtures/output-corpus.json` expectation is changed.

Before measuring, obtain recordings of all fifteen prompts and silence, with
documented permission to redistribute each recording and the speaker's voice.
Use `rights` objects with nonempty `owner`, `license`, `source`, and
`permissionReference` fields. The permission reference must identify an actual
consent/license record; a synthetic placeholder is not evidence. Do not copy
unlicensed online samples or create speech through paid APIs.

Record PCM16 mono 16,000 Hz WAV files at the manifest paths. Declare each exact
file's SHA-256 and change status to `ready`. Commit audio, permission records,
references, normalization and annotations **before** the first engine run.
The integration test checks that all inputs match HEAD. Changing references
after listening to output requires a new corpus version and a fresh result;
it must not silently improve an earlier score.

On an authorized physical Windows host, build the pinned bundled CLI, acquire
the verified model, disable network adapters, and set
`RESENHA_CORPUS_INSTALL_DIRECTORY` to the directory containing
`native/whisper-cli.exe` and `RESENHA_CORPUS_MODEL` to the pinned model file.
Run the `WindowsIntegration` category without skips. The corpus test reports
per-language aggregate WER and PT/ES annotated occurrence retention; thresholds
are WER <= 0.20 for every language and retention >= 0.90 separately for PT/ES.
Keep those measured results with the source SHA, host inventory, CLI/model
hashes and release dossier. A macOS cross-build is not a native test result.

The native preset is used from `Windows/native/` with
`cmake --preset windows-x64-cpu` then `cmake --build --preset windows-x64-cpu`.
The build preset caps native workers at two. Its toolset family is locked;
the exact compiler/CMake/SDK inventory remains a release prerequisite in
`../toolchain-lock.json`. The wrapper rejects a changed/dirty upstream pin.
