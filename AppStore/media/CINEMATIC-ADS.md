# Resenha — cinematic ad system

Status: generation-ready; paid Google Veo call not started

Canonical prompts live in `prompts/`. `Scripts/generate-veo-plates.sh` performs a no-cost dry run by default, reads a rotated key only from macOS Keychain and refuses paid execution unless the exact US$ 9.60 ceiling is supplied after owner approval. It performs one request per plate and never retries automatically.

## Production rule

Veo generates only the cinematic plate: people, light, environment, camera and ambience. It must not invent the Resenha interface, logo or readable screen text. Real SwiftUI renders, the approved mark and final typography are composited afterward. This keeps the product truthful and prevents warped UI.

## Deliverables

| Cut | Purpose | Generated plate | Final edit |
|---|---|---|---|
| A — Thought | homepage hero | 8s, 16:9, 1080p | 18s with real HUD and line `Sua voz, em qualquer campo.` |
| B — Anywhere | social/product demo | 8s, 16:9, 1080p | 18s with real insertion flow and three host contexts |
| C — Local | privacy proof | 8s, 16:9, 1080p | 18s with `100% local` and sandbox/model proof |

Vertical 9:16 derivatives are reframed from protected center composition after the landscape masters pass.

## A — Thought outruns fingers

Slow cinematic push-in, 8 seconds. A calm Brazilian creative professional at a warm, minimal desk at first light, viewed in a tight three-quarter profile. Their hands stop above the keyboard as they begin speaking naturally; breathing and subtle jaw movement are visible. Soft sage-green daylight moves across paper and brushed aluminum while extremely delicate concentric sound ripples travel through dust in the air, physical and understated rather than holographic. The computer screen remains outside frame and no device logo or readable text is visible. Premium 35mm lens, shallow depth of field, restrained film grain, tactile materials, realistic skin, quiet room tone and one subtle confirmation chime. No dialogue, no captions, no logos, no interface, no floating typography, no red or purple light, no sci-fi HUD. Stable anatomy, one person, one keyboard, one laptop. Camera motion stays slow and straight.

## B — Anywhere you write

One elegant continuous tracking shot, 8 seconds, landscape. Begin macro-close on a fingertip resting on a keyboard shortcut, then pull back slowly to reveal a focused professional speaking while working in a bright contemporary home office. The laptop screen is deliberately soft and unreadable, held in a stable frontal plane for later screen replacement. Natural morning light, paper-white and muted sage palette, subtle acoustic movement in a nearby glass of water responding to the voice. Premium commercial realism, 40mm lens, controlled depth of field, soft practical sound of key press and room ambience. No dialogue, no captions, no logos, no invented UI, no distorted keyboard, no extra hands, no aggressive camera move. The laptop and screen geometry remain rigid throughout.

## C — Local means local

Locked-camera cinematic tabletop shot, 8 seconds, landscape. A closed-loop visual metaphor for private on-device speech: a gentle translucent sage sound pulse enters a slim unbranded laptop through the microphone edge, becomes a warm line of light contained inside the aluminum body, and never leaves the computer. The surrounding room falls quiet while distant cloud-like reflections pass outside a window but do not touch the device. Refined practical VFX, physically plausible reflections, dark graphite and warm paper palette, premium macro photography, subtle low-frequency ambience and one soft resolving bell. No text, no logo, no cloud icon, no data streams leaving the device, no neon, no purple, no red, no fantasy morphing. Device geometry remains rigid.

## Post-production

1. Select stable first/middle/last frames; reject anatomy, device or lighting drift.
2. Cut generated plate against real `resenha-flow.mp4` and native settings renders.
3. Add approved V2 mark as a locked graphic; never ask the model to redraw it.
4. Master H.264 website/App Store preview plus 9:16 social cut, captions baked only in final edit.
5. Keep generated-video disclosure and source prompt in internal release evidence.

## Secure generation

After revoking the key exposed in chat, store a newly created key without echoing it:

```sh
read -s "key?Nova chave Google AI: "; echo
security add-generic-password -U -a "$USER" -s br.com.luisroquette.Resenha.google-veo -w "$key"
unset key
```

Dry run, with zero network calls:

```sh
Scripts/generate-veo-plates.sh --dry-run
```

Paid execution is deliberately gated and must only be run after explicit approval:

```sh
RESENHA_VEO_APPROVED_USD=9.60 Scripts/generate-veo-plates.sh --execute
```

## Mac App Store master

- 1920 × 1080 landscape, H.264 High Profile up to level 4.0.
- 30 fps maximum; target 10–12 Mbps.
- 18 seconds per cut, inside Apple's 15–30 second requirement.
- Stereo AAC at 256 kbps and 48 kHz; no dialogue required.
- Maximum three previews per localization; each cut remains understandable without audio.
- Source: [App preview specifications — Apple Developer](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).
