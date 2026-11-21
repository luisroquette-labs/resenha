# Dictation privacy and input boundaries

Status: accepted

Transcript-history persistence is best effort. If its private, atomically written file cannot be saved, the clipboard remains the user's recovery path; transcript content is not written to logs. Transcription consumes its captured WAV, so a caller needing a fixture afterward must supply a copy.

After embedded whisper inference returns, cancellation is checked before interpreting its status because whisper.cpp uses the same negative status codes for encode/decode failure and abort. Completion after staged insertion checks the active attempt identity again after suspension, preventing an older completion from claiming a newer attempt.

Correction fields are bounded by UTF-8 bytes before character count because one grapheme may contain many combining scalars. Newlines and `=` are rejected before whitespace trimming, so pasted trailing input cannot change the correction grammar. Conflict detection examines raw lines even when a parser would ignore or truncate them; an invalid existing mapping must remain visible.
