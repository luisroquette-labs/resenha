# SPEC-020 — Privacy, review and release operations

## Privacy declaration

- App Privacy answer: optional Other User Content, linked to the user's provider account, not used for tracking, for App Functionality; audio remains local.
- Microphone audio is processed on-device and deleted after each attempt.
- Transcript history is local, optional, limited and clearable.
- Privacy policy explains microphone, Input Monitoring, clipboard recovery, local storage and model delivery.
- A valid `PrivacyInfo.xcprivacy` ships in `Contents/Resources`; required-reason APIs are audited on the archived binary.

### Continuous context release decision (2026-10-22)

- Release decision: `personalRemoteAvailable`. The owner authorized recurring OpenRouter/JEV calls with transcribed text only; audio remains prohibited.
- Fresh installs default off. Personal transport requires separate consent, a distinct Keychain credential, healthy local examples and current policy/store generations. Synthetic diagnostic consent cannot authorize it.
- `Config/PrivacyInfo.xcprivacy` declares Other User Content for App Functionality, linked because the personal provider key authenticates an OpenRouter account, and not used for tracking. No tracking domain or new required-reason API was added.

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
