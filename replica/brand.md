# Brand — Reelcraft

## Name

**Reelcraft** — "reel" names the output, "craft" names the promise: deliberate cutting rather than one-tap slop.

Why it works for App Store search: the word *reel* is what people type when they want a short-form editor, and *craft* separates it from template-only apps. The App Store title carries the category keywords after the colon: **Reelcraft: Video Editor**.

### Checks to run before you ship (not done here — these need your accounts)

- [ ] USPTO/TMview search for "Reelcraft" in class 9/42, and your local registry.
- [ ] App Store and Play Store search for an app already using the name.
- [ ] `reelcraft.app`, `reelcraft.com`, `getreelcraft.com` availability, plus the matching social handles.
- [ ] If any conflicts: fallbacks that keep the same shape — **Cutwise**, **Reelmark**, **Framecraft**, **Cutroom**.

Nothing in the codebase needs renaming if you switch names: the display name lives in `project.yml` (`CFBundleDisplayName`), the bundle identifier in one line of the same file, and the marketing copy in `replica/launch/listing.json`.

## Positioning

**For** people who cut short-form video on a phone **who** are tired of two extremes (auto-templates with no control, or desktop-grade apps with no speed) **Reelcraft is** the editor that keeps a real timeline and a real export **because** the whole app is local, fast and honest: no account, no watermark, no upload.

Anti-positioning, on purpose:
- Not a social network. No feed, no follows, no metrics you cannot compute yourself.
- Not a template mill. Templates are a starting point, not the product.

## Palette

| Role | Hex | Use |
| --- | --- | --- |
| Background | `#0A0A0C` | App canvas, editor surround |
| Surface | `#141419` | Cards, panels, tab bar |
| Surface raised | `#1D1D24` | Chips, secondary buttons, tool tiles |
| Border | `#2A2A33` | Hairlines, card strokes |
| Border (input) | `#63636F` | Text fields — 3.34:1, WCAG AA |
| Text | `#F7F7F5` | Primary text |
| Text muted | `#9A9AA5` | Secondary text |
| Text faint | `#6B6B76` | Metadata |
| Accent (ember) | `#FF5C38` | Actions, playhead, selection, export |
| Accent gradient | `#FF7A4D → #FF5C38` | Primary buttons |
| Mint | `#7CFFB2` | Success, sound, "no watermark" trust marks |
| Amber | `#FFC93C` | Speed badges, warnings |
| Danger | `#FF5D5D` | Destructive actions |

Contrast check: `python3 /tmp/replica-skill/replica-design/contrast.py replica/design/tokens.json` → 11 pairs, 0 failing AA.

Deliberately different from the studied app's dark-neutral look: Reelcraft leads with warm ember on near-black, so side-by-side screenshots never read as the same product.

## Typography

- Display/headlines: SF Pro Rounded, bold — friendly, unmistakably iOS.
- Body: SF Pro.
- Timecode and metrics: SF Mono, so digits never shift width while scrubbing.

## Logo

A film frame with sprocket notches, an ember play wedge in the middle and a mint tick = "the cut". Generated at 1024 px by `tools/make_assets.py` (also the alternate dark appearance and the 180/512 px marketing sizes). Legible down to 40 px, no text in the mark, no gradients that break on light home-screen walls.

Variants shipped:
- `Assets.xcassets/AppIcon.appiconset/AppIcon.png` — 1024 px app icon.
- `Marketing/icon-512.png`, `Marketing/icon-180.png`.
- `Marketing/wallpaper-1290x2796.png` — launch/feature graphic with the lockup and the tagline.

## Voice

Plain, concrete, a bit dry. Sentences short. No exclamation marks, no "unleash your creativity".

- Do: "Trim to the frame. Export clean." / "Nothing is uploaded. There is no account."
- Don't: "Revolutionary AI-powered editing experience!" / "Instantly go viral".

Empty states always say what to do next ("Add a clip to begin"), errors always say what happened and what to try, and nothing promises a number we cannot measure.
