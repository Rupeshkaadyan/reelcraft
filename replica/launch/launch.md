# Launch plan

## Positioning

**Reelcraft — the short-form editor that stays on your phone.**

Three claims, all true in the build:
1. **A real timeline** — trim to the frame, split, retime, reorder. Not a template spinner.
2. **No watermark, no account** — export at 1080p or 4K and keep your footage private.
3. **On-device captions and stats** — the only network permission the app needs is none.

## Pricing

Ship **free** for v1.0. There is no paywall, no account and no subscription, which is the differentiator against editors that gate export quality.

Suggested v1.1 monetisation, when you have retention data:
- **Free forever:** 1080p export, all editing tools, 4 music beds, watermarked? No — never watermark.
- **Reelcraft Pro ($3.99/mo or $24.99/yr):** 4K export, extra grade packs, extra music packs, project folders, voiceover.
- Keep the "no account" promise by selling through StoreKit with a local receipt; no login screen.

Do not put a trial on v1: it suppresses the ratings you need in the first month.

## App Store listing

Copy is in `listing.json` and lints clean (`0 errors, 0 warnings`): title 23/30, subtitle 30/30, keywords 95/100 with no duplication against the title.

Title: **Reelcraft: Video Editor**
Subtitle: **Trim, caption and export in 4K**

Screenshot order (1320 × 2868, in `Marketing/appstore/`):
1. Every cut in one place
2. Frame-accurate timeline
3. Start from a look
4. Catch ideas early
5. Know your habits

## ASO keywords

`reels, short form, no watermark, clips, timeline, filter, creator, montage, music, voiceover, social`

Not used, on purpose: "editor", "video", "4k", "caption", "trim", "export" — already in the title or subtitle, so they would waste characters.

## Landing page copy

**Headline:** Edit like you mean it.
**Sub:** A phone editor with a real timeline. Trim to the frame, caption on device, export in 4K with no watermark. No account, no upload, no catch.
**CTA:** Download on the App Store.
**Sections:** Timeline · Grades · Captions · Export · Privacy · FAQ
**FAQ:**
- *Does it upload my footage?* No. Reelcraft has no server and no account.
- *Is there a watermark?* Never.
- *What does it cost?* Free at launch.
- *Which formats?* 9:16, 4:5, 1:1, 16:9 — 1080p or 4K.
- *Do captions need the internet?* No, they use on-device speech recognition.

## Launch checklist

- [x] App icon in the asset catalog, 1024 px, no alpha.
- [x] 5 App Store screenshots at 1320 × 2868.
- [x] Listing copy linted.
- [x] Brand sweep clean (`sweep.py` → 0 hits).
- [x] Parity scored: 74.7 / 100, 17 of 20 must-haves complete (3 partial, documented).
- [x] Privacy policy drafted (`PRIVACY.md`, `Marketing/privacy.html`).
- [ ] Apple Developer Program membership and Team ID (needs your account).
- [ ] Bundle ID registered as `com.reelcraft.app` (or your own).
- [ ] Archive + upload to App Store Connect.
- [ ] Privacy nutrition label: **Data not collected**.
- [ ] Age rating: 4+ (no user content, no ads, no purchases in v1).
- [ ] TestFlight pass on a physical device, especially camera and captions.
- [ ] Submit for review with the export flow described in the notes field.

## Honest risks

- **Review may ask about photo/camera usage strings.** Both are present and specific.
- **The 4K claim needs a device check.** The exporter renders at 2160-class sizes; long 4K exports on older phones will be slow. Say "up to 4K" in copy, which the listing does.
- **Auto captions can fail on a device without the speech model.** The UI degrades to a readable message, but a reviewer testing offline may see that message. Consider making the empty state say "Available after the speech model downloads."
