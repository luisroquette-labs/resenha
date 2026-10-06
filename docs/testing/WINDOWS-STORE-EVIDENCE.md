# Windows Store — submission and physical evidence

Status: Submission 1 entered Microsoft certification on 2026-10-05. Certification
and a clean physical Store installation remain pending. Synthetic CI packages do
not fill physical-evidence rows.

## Product identity

| Evidence | Observed value |
| --- | --- |
| Partner Center identity name / publisher / display publisher | `CFGaussServiosLtda.Resenha` / `CN=423DACA4-6A0B-4E80-BFA4-9BF1E35E6AC1` / `CF Gauss` |
| Reserved product name / authorization reference / UTC | `Resenha` / Store ID `9P4M40MZH627` / observed 2026-10-05 |
| Source commit / version / exact candidate SHA-256 / byte length | `fd22aaf619297daf756dc23947407fa17f622a34` / `0.1.0.0` / `739507485d3c736e320af67e4d221e5a86c45dd64054d013f02f7a0aaa630961` / `82,796,563` bytes |
| MakeAppx version / package validation | Windows SDK `10.0.26100.0` / Partner Center `Validated` |

## Submission and certification

| Evidence | Observed value |
| --- | --- |
| Partner Center submission ID / package SHA-256 / UTC | `1152921505702046228` / `739507485d3c736e320af67e4d221e5a86c45dd64054d013f02f7a0aaa630961` / submitted `2026-10-05T14:43:46Z` |
| Restricted-capability declaration and privacy URL review | `runFullTrust` justification submitted; `https://luisroquette-labs.github.io/resenha/privacy/` saved |
| Certification result / report / terminal UTC | `In certification` → `Pre-processing` observed `2026-10-05T14:43:46Z`; terminal result pending |
| Public Microsoft Store product ID and immutable listing URL | reserved: `9P4M40MZH627` / `https://apps.microsoft.com/detail/9P4M40MZH627`; public resolution pending certification |

A successful upload acknowledgement is not certification. Certification is not
proof that dictation works on a physical machine.

## Store listing assets

Five 1920 × 1080 editorial composites are versioned under
`Windows/Store/Screenshots/pt-BR`. They are generated from the shipped WPF UI
contract and only describe implemented behavior. They are Store marketing
assets, not substitutes for the pending physical Windows evidence below.

## Clean physical Store install

| Evidence | Observed value |
| --- | --- |
| Device / Windows edition / full build / x64 / clean profile | pending |
| Store listing install / launch / update ownership | pending |
| SmartScreen warning absent on the Store path | pending |
| Model download / microphone / hotkey / transcription / cursor insertion | pending |
| Uninstall / owned-data cleanup / remaining files | pending |

Only after every row is observed against the certified package may the website
replace the unsigned Beta route with the Microsoft Store listing.
