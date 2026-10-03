# SPEC-020 — Privacy, review and release operations

## Privacy declaration

- App Privacy answer: Data Not Collected, provided the final binary has no analytics, network transcription, account, crash SDK or remote logging.
- Microphone audio is processed on-device and deleted after each attempt.
- Transcript history is local, optional, limited and clearable.
- Privacy policy explains microphone, Input Monitoring, clipboard recovery, local storage and model delivery.
- A valid `PrivacyInfo.xcprivacy` ships in `Contents/Resources`; required-reason APIs are audited on the archived binary.

## Review package

- Review notes explain the hold-to-talk flow, exact shortcut, permission sequence, model availability and offline test.
- Provide a short review video only if the workflow cannot be understood immediately from written steps.
- No demo account is required because the app has no login.
- Export-compliance answers reflect the final linked binary; do not guess.
- Age-rating questionnaire answers reflect no user-generated/network content.

## Release operations

- Archive with Release configuration and Store entitlements.
- Validate/upload, then verify build processing and TestFlight install before submission.
- Show the owner the exact binary build, locales, price, territories, privacy answers, review notes and release mode before the final Submit for Review action.
- Prefer manual release after approval for version 1.0, allowing one final product-page verification.
- Monitor processing, review and release until terminal state; record every rejection/resolution.

## Acceptance

- `PRIVACY-001`: static scan and runtime observation find no network request during dictation.
- `PRIVACY-002`: privacy manifest validates and appears in the archive.
- `REVIEW-001`: TestFlight build reproduces `STORE-001` on a clean account/device state.
- `RELEASE-001`: App Store public URL resolves to the approved version and installation succeeds.
