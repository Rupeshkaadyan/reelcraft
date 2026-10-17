# Recon map — short-form video editor (App Store id6738967378)

**Target studied:** "Edits: Video Editor" on the App Store (iOS, free, Meta).
**Rebuilt as:** Reelcraft, an original SwiftUI app that shares the workflow, not the assets.
**Method:** public sources only. No binary was decompiled, no bundle was read, no account was used.

## Sources

| Source | What it gave |
| --- | --- |
| [App Store listing](https://apps.apple.com/in/app/edits-video-editor/id6738967378) | Feature claims: 4K export without watermark, 10-minute capture, frame-accurate editing, camera controls, AI cutouts, fonts/sound/effects, auto captions, ideas, insights |
| [Meta announcement](https://about.fb.com/news/2025/04/introducing-edits-streamlined-video-creation-app/) | Positioning, the creator workflow, later templates and title cards |
| [TechCrunch guide](https://techcrunch.com/2025/08/12/a-guide-to-using-edits-metas-new-capcut-rival-for-short-form-video-editing/) | Five main sections, tool row, keyframes and beat markers in later builds |
| [Buffer hands-on](https://buffer.com/resources/how-to-use-instagram-edits/) | Timeline behaviour, per-clip actions, speed, green screen, voice effects, undo |
| [MakeUseOf review](https://www.makeuseof.com/instagrams-edits-app-review/) | Ideas (stickies, saved, collections), project sorting, insights metrics, screenshots |
| [App Store reviews](https://apps.apple.com/us/app/edits-video-editor/id6738967378?see-all=reviews) | Reported friction: crashes, export issues, lost edits, missing landscape/keyframes at launch |

Colour values and exact control positions are **not** documented publicly, so the palette and layout here are Reelcraft's own decisions informed by the hierarchy described in those sources — not measured copies.

## What the app is for

The core loop is a creator's loop, not a generic editor's:

1. Catch an idea before it is lost.
2. Import or record clips.
3. Cut them to the frame with text and sound.
4. Export clean, at high quality, with no watermark.
5. Learn what worked.

The five-tab shell exists to serve that loop. Reelcraft keeps the same loop and drops the parts that depend on a social network.

## Screen inventory

| ID | Screen | How you get there | Purpose | Key components | States |
| --- | --- | --- | --- | --- | --- |
| S01 | Projects | Tab | Library of drafts and finished cuts | Header, stats strip, sort menu, 2-col card grid, empty state | empty, filled, importing, long names |
| S02 | Editor | Any project card, template, camera save | Cut one project | Preview, transport, timeline, tool row, inspector | empty, building, playing, paused, error |
| S03 | Trim inspector | Tool row → Trim | In/out, split, reorder | Two sliders, five action tiles | clip selected, no clip |
| S04 | Text inspector | Tool row → Text | Titles and captions | Overlay chips, text field, style/position/colour, timing | no overlays, many overlays |
| S05 | Filters | Tool row → Filters | Look of the cut | 8-swatch grid, apply-to-all | selected, none selected |
| S06 | Speed | Tool row → Speed | Retime a clip | Big readout, 6 presets | selected, no clip |
| S07 | Audio | Tool row → Audio | Clip levels and music | Volume slider, mute, 5 music tiles, music volume | music off, music on |
| S08 | Captions | Tool row → Captions | Speech to timed text | Generate button, status, manual add, caption list | idle, transcribing, error, filled |
| S09 | Frame | Tool row → Frame | Aspect ratio | Four ratio cards | selected |
| S10 | Export | Editor → Export | Render and save | Quality choice, progress, success, share | idle, exporting, done, save failed |
| S11 | Ideas | Tab | Sticky-note board | Intake sheet, colour picker, 2-col board | empty, filled, done filter |
| S12 | Discover | Tab | Templates and sound packs | Template gallery, template sheet, sound list | idle, previewing |
| S13 | Record | Tab | In-app capture | Preview layer, timer, record button, flip, torch | permission, no camera, recording, processing |
| S14 | Insights | Tab | Local editing stats | Four stat cards, weekly bar chart, palette habits | empty, filled |

## Flows

**F01 Start from the library** — S01 → import sheet → preparing → S02, 1 tap to editing.
Edges: unreadable file, no video track, very long clip, permission denied.

**F02 Cut a clip** — S02 → select clip → Trim → drag in/out → split at playhead → play.
Edges: split too close to a boundary (blocked), delete the last clip (empty canvas), undo after split.

**F03 Add text and captions** — S02 → Text → add → type → style/position/timing → play.
Edges: no overlays yet, overlay longer than the cut (clamped), keyboard covering the inspector.

**F04 From idea to cut** — S11 → note → "Start a project" → S02.
Edges: empty note disabled, note already linked to a project.

**F05 Template to export** — S12 → template sheet → use → S02 → add clips → export → Photos.
Edges: template chosen before any clip exists, export with no clips (disabled).

**F06 Record and edit** — S13 → record → processing → S02, camera clips land in Projects.
Edges: camera permission denied, simulator with no camera, max 10-minute cap, interrupted recording.

## Components

Buttons (primary ember pill, secondary surface, ghost capsule, icon circle), chips, section headers, empty states, stat cards, project card, template card, timeline segment with badges, playhead, tool tile, inspector sheet, slider row, text field, colour swatches, photo picker, export progress, toasts/alerts. All implemented as SwiftUI primitives in `Reelcraft/Design/Theme.swift`, `Features/Projects`, `Features/Editor`.

## Inferred data model

| Entity | Fields | Evidence | Confidence |
| --- | --- | --- | --- |
| Project | id, name, created/updated, aspect, clips[], overlays[], music, musicVolume, exportCount, lastExportAt | Project hub + editor + export + insights | high |
| Clip | id, file, sourceDuration, trimStart/End, speed, volume, muted, filter, hasAudio, thumbnail, source size | Timeline, trim, speed, audio, filters | high |
| TextOverlay | id, text, start, duration, position, style, colour, isCaption | Text and caption tools | high |
| Idea | id, text, colour, createdAt, done, projectID | Ideas board and "make a cut" | medium (project link is our addition) |
| ExportRecord | id, project, date, duration, resolution | Insights dashboard | medium (derived from local exports) |

## What cannot be cloned, and is skipped on purpose

- **The account system** (Instagram sign-in). It is Meta's identity system.
- **Saved reels, collections and the discovery feed with trending audio.** Those are licensed catalogues plus a social graph, not features.
- **Account and Reel analytics.** Reelcraft measures local editing instead, which is honest and private.
- **Fonts, stickers, GIFs and sound libraries from the original.** Reelcraft ships its own four synthesised music beds and system fonts.

## Sizing

14 screens, 6 core flows, 5 entities, one heavy subsystem (the render pipeline).
Verdict: **M** — the UI is a few weeks; the composition/export pipeline is the part that decides whether it feels real.
