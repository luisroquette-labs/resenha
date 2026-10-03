---
name: open-source-dictation-site
description: Research, write, and validate a truthful sales/download site for an open-source native dictation app, with evidence-based capability labels and release-aware CTAs.
---

# Open-source dictation sales and download sites

## When to use

Use when translating a native dictation prototype into a product website or updating its download page. Inspect implementation and release evidence before writing availability claims. This research was checked on 2026-10-02; recheck third-party product details before publishing comparisons.

## Workflow

1. Inventory each product capability as verified in the current app, implemented but unverified, planned, or excluded. Attach repository/runtime evidence; an approved spec is not implementation evidence.
2. Inspect current public repository visibility, real release assets, supported hardware/OS, and store listing availability. Select CTA labels from the state table below.
3. Write original benefit-led copy and demonstrate the real capture → transcript → insertion flow. Identify conceptual illustrations as demonstrations, with no browser microphone access implied.
4. Implement the smallest static page compatible with the repository. Prefer HTML/CSS, native links and `details`/`summary`, local SVG assets, system fonts, and minimal optional JavaScript. Avoid a framework/CMS/backend merely for one landing page.
5. Verify mobile/desktop appearance, keyboard and reduced-motion behavior, all destinations, and claim accuracy. Run local automated gates through `mac-gate`; keep screenshots and explicit NOT RUN notes for checks unavailable in the environment.

## Competitor benchmark: transferable structure

Willow's [home page][1] uses a prominent product promise and repeated download action, a three-step workflow, use-case demonstrations, capability cards, social proof, and a final CTA. Its [download page][2] separates desktop downloads by platform and distinguishes available mobile distribution from an upcoming platform. These are useful information-design patterns. They are not proof of Resenha capabilities.

For a pre-release open-source product, replace testimonial/metric sections with verifiable evidence: actual interface, local processing explanation, explicit release status, and source/license links when public. A sales page should still communicate the experience confidently; roadmap labels belong immediately alongside the relevant feature, not in a distant footnote.

Create original text, typography, composition, illustration and brand assets. Do not import Willow's logos, testimonials, customer marks, code, videos, or numerical performance claims. Avoid affiliation implications. This is an editorial boundary, not a trademark-clearance opinion.

## Features/configurations to evaluate

| Capability observed in official Willow material | Product question to document before claiming parity |
|---|---|
| Configurable single-key/chord bindings; up to four dictation hotkeys; dedicated hands-free action; double-tap option [3] | Which bindings/modes are implemented and validated on each OS? Conflict reporting must not promise exhaustive system-wide detection. |
| Persistent microphone selection [4] | Can the app retain its chosen input through Bluetooth changes, and does it show a real input level? |
| Preferred language or automatic detection [5] | Which language modes are implemented and tested? Mixed-language recognition is not translation. |
| Personal dictionary and reusable voice snippets [6] | Are these recognition hints, deterministic replacements, or generated text? Do not imply learning without evidence. |
| Style presets by application context [7] | Is app-context access implemented, consented, and optional? |
| Formatting/voice editing [8] and intent-driven Scribe including selected-text translation [9] | These require separate product scope and evidence; ordinary transcription does not establish them. |
| Local history/retry and context/privacy controls [10] | What is retained, where, for how long, and how does deletion work? Cloud privacy is not offline processing. |

The [pricing page documentation][11] describes offline dictation as a paid feature and lists plan-specific functionality. Its free-plan prose and comparison table contain potentially inconsistent limits. Do not reproduce prices, limits, speed claims, or plan comparisons without resolving the current source of truth.

## Release-aware links

| Evidence state | Honest presentation | Behavior |
|---|---|---|
| No public repository or release | “Conheça o projeto” / “Veja o que já funciona”; “Download em preparação” | Working local section anchors; no fabricated GitHub or download URL. |
| Public source exists, no installer | “Ver código no GitHub” | Exact verified repository; separately explain that source is not an installer. |
| Verified downloadable prerelease | “Baixar beta para macOS” | Exact release/asset; show version, architecture, minimum OS and beta status. |
| Verified stable release | “Baixar para macOS” | Published release asset; signing/notarization only if actually verified. |
| Store planned or under review | Plain “Mac App Store: planejado” or evidenced review state | Non-actionable status text, no store badge or fabricated link. |
| Store published | Official localized Mac App Store badge [12] | Exact product listing, original official badge artwork. |
| Windows not delivered | “Windows no roadmap” | No download action or launch date without a commitment. |

[GitHub releases][13] package versioned software and files for users. A source archive or repository page must not be passed off as a signed native installer. A local `.app` working on the developer's machine is insufficient release evidence.

Keep source and release availability independent. One small release configuration/data object is sufficient if multiple CTAs need shared state; avoid a provider abstraction or remote fetch for static links. Missing URL must render honest static content before JavaScript executes. Do not use `href="#"` as a fake download.

## Accessibility and performance

Use the [WCAG 2.2 reference][14] to verify semantic headings/landmarks, `lang="pt-BR"`, accessible names, visible unobscured focus, full keyboard operation, descriptive link text, decorative artwork hidden from accessibility APIs, and text alternatives for meaningful visuals. Verify normal text contrast at 4.5:1, large text and essential control visuals at 3:1. Check 320 CSS-pixel reflow and 200% zoom. Target 44px controls where practical. Provide pause/stop for nonessential repeating motion; reduced-motion users get a static equivalent. No autoplay audio or unexpected permission prompt. Show unavailable downloads as readable status, not only low-contrast disabled controls.

Keep core content usable without JavaScript. Supply image dimensions to prevent shifts; lazy-load below-fold media, not the hero. Prefer local optimized SVG/WebP and no third-party embed for an ornamental waveform. Avoid font/network waterfalls and heavy animation libraries. [Core Web Vitals][15] targets are LCP ≤2.5s, INP ≤200ms, CLS ≤0.1 at the 75th percentile. Local Lighthouse results are lab evidence, not field proof. Do not claim a field pass for an unpublished page.

## Search and content integrity

[Google's guidance][16] supports descriptive original titles, succinct relevant descriptions, crawlable links, useful text and meaningful image alternatives. Set an honest page title and meta description; use one clear primary heading as an editorial convention. Avoid fake reviews, ratings or download counts in visible content or structured data. Add canonical and social URLs only once the real public origin is known; do not ship localhost/example domains as canonical identity. A local preview can remain unindexed. Plain readable content is more useful than speculative rich-result markup.

## Product-specific application: Resenha

The approved direction is local-first, no required account, macOS first, Windows later, open source with Apache 2.0, and optional user-key OpenAI transcription. Treat these as decisions until implementation/license/release evidence confirms each one. Never invoke a paid API during website development. “Offline” applies to installed local-model transcription; optional cloud mode requires internet and incurs the provider's charges. The webpage must not ask visitors for their API keys.

Customizable hotkeys are required product scope but may still be planned in the present build. Keep this status separate from the existing right-Option dictation demonstration. Output intelligence, history, team features, and translation are benchmark research rather than permission to implement them in this website task.

## References

[1]: https://willowvoice.com/
[2]: https://willowvoice.com/download
[3]: https://help.willowvoice.com/en/articles/10876257-hotkey-settings
[4]: https://help.willowvoice.com/en/articles/10876169-microphone-settings
[5]: https://help.willowvoice.com/en/articles/13668452-dictation-appears-in-the-wrong-language
[6]: https://help.willowvoice.com/en/articles/13183918-using-personal-dictionary-and-shortcuts
[7]: https://help.willowvoice.com/en/articles/12864746-personalization-and-style-matching
[8]: https://help.willowvoice.com/en/articles/13183983-voice-commands-and-automatic-formatting-guide
[9]: https://help.willowvoice.com/en/articles/15043797-introduction-to-scribe-in-willow
[10]: https://help.willowvoice.com/en/articles/12854269-how-willow-protects-your-data-and-privacy
[11]: https://help.willowvoice.com/en/articles/12854184-willow-pricing-plans-overview
[12]: https://developer.apple.com/app-store/marketing/guidelines/
[13]: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
[14]: https://www.w3.org/WAI/WCAG22/quickref/
[15]: https://web.dev/articles/vitals
[16]: https://developers.google.com/search/docs/fundamentals/seo-starter-guide
