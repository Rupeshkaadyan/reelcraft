# Build log

Statuses: **done** (built and exercised), **partial** (built, limited by device or data), **roadmap**.

| Screen / area | Status | Evidence | Notes |
| --- | --- | --- | --- |
| S01 Projects library | done | `Marketing/screens-max/01-projects.png` | Grid, stats strip, sort, rename/duplicate/delete, empty state |
| S02 Editor shell | done | `Marketing/screens-max/02-editor.png` | Preview renders the real composition, transport, timeline, tool row, undo/redo |
| S03 Trim | done | build + `RenderPipelineTests.testBuildsCompositionWithFiltersOverlaysAndSpeed` | In/out sliders, split, duplicate, reorder, delete, reset |
| S04 Text | done | screenshot shows a headline overlay rendered into the frame | 4 styles, 3 positions, 5 colours, start/length sliders |
| S05 Filters | done | screenshot shows the Ember grade applied | 8 presets, apply-to-all, per-clip badge on the timeline |
| S06 Speed | done | `testClipSpeedScalesTimelineDuration` | 0.25×–3× with duration readout |
| S07 Audio | done | `testBuildsCompositionWithFiltersOverlaysAndSpeed` asserts an audio mix | Per-clip volume/mute, 4 music beds, music volume, loop + fade |
| S08 Captions | partial | `CaptionService` wired to on-device Speech | Needs a device with the speech model; the simulator path can fail cleanly |
| S09 Frame | done | screenshots cover 9:16, 4:5, 1:1 card | Four ratios, re-render on change |
| S10 Export | done | `testExportsPlayableFileAtProjectAspect` writes and re-reads a 1080×1080 mp4 | 1080p and 4K, Photos save, share sheet, progress |
| S11 Ideas | done | `Marketing/screens-max/04-ideas.png` | Colours, done filter, turn a note into a project |
| S12 Discover | done | `Marketing/screens-max/03-discover.png` | 6 templates, sound-pack previews |
| S13 Record | partial | screen captured; simulator has no camera | Session, 10-minute cap, flip, torch, recording → project. Needs a physical device to confirm capture |
| S14 Insights | done | `Marketing/screens-max/05-insights.png` | Fixed a minutes bug found in review (double division) |
| Media import | done | exercised by the tests and the seeded library | Orientation normalisation, thumbnail, duration, audio detection |

## What was harder than it looked

- **Orientation.** Baking `preferredTransform` into the pixels at import removed an entire class of rotated-preview bugs, at the cost of one re-encode per import.
- **Text plus filters in one pass.** `AVVideoCompositionCoreAnimationTool` cannot be combined with a custom compositor, so overlays are rasterised to `CIImage` and composited in the same handler instead. Faster and simpler.
- **Export failures with silent clips.** A composition with an empty audio track plus an audio mix fails at export with a bare "Operation Stopped". Fixed by creating the audio track lazily and dropping it when nothing was inserted; the test now guards it.
- **Speed and trims together.** `scaleTimeRange` has to run per inserted segment before the cursor advances, otherwise the timeline drifts.

## Bugs found and fixed during review

1. Insights reported "0.0 minutes" — minutes were divided by 60 twice. Found by reading the captured screenshot, fixed, re-captured.
2. Export failed with "Operation Stopped" for clips without audio. Found by the export test, fixed in the builder.
3. `border-input` failed WCAG AA in the token check (2.27:1). Raised to `#63636f` (3.34:1) and applied to text fields.

## Not built, on purpose

Instagram account features, saved reels/collections, discovery feed with licensed audio, account analytics, licensed stickers/fonts/GIFs. See `recon.md` → "What cannot be cloned".
