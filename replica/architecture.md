# Architecture — Reelcraft (iOS 17+, SwiftUI)

## Principles

1. **Local first.** No account, no backend, no network calls. Projects, media and stats live in the app container.
2. **One source of truth for the timeline.** `VideoProject` is the document; the composition is derived from it, never edited directly.
3. **No borrowed assets.** Every image, icon and sound is generated in this repo (`tools/make_assets.py`, `tools/make_music.py`).
4. **Failure is a state, not a crash.** Import, build, captions and export all surface messages instead of trapping.

## Layers

```
Reelcraft/
  App/            ReelcraftApp, RootView (5 tabs), AppRouter
  Design/         Theme tokens + primitives (buttons, chips, empty states)
  Models/         VideoProject, Clip, TextOverlay, FilterPreset, TemplatePreset, Idea
  Store/          ProjectStore (JSON persistence), Paths (container layout)
  Media/          MediaImporter, CompositionBuilder, OverlayRenderer, Exporter
  Features/
    Projects/     Library grid, import, rename/duplicate/delete
    Editor/       EditorView, EditorViewModel, TimelineView, ToolPanels, ExportSheet, CaptionService
    Camera/       RecordView + CameraModel (AVCaptureSession, MovieFileOutput)
    Ideas/        Sticky board
    Discover/     Templates + sound packs
    Insights/     Local stats + Swift Charts
```

State: `ProjectStore` (`ObservableObject`) owns projects/ideas/exports; `AppRouter` owns tab selection and the editor presentation; `EditorViewModel` owns one editing session and its undo stack. Dependencies flow down through the environment; no singletons except the thumbnail cache.

## Persistence

| Data | Location | Format |
| --- | --- | --- |
| Projects | `Documents/projects.json` | Codable array, ISO-8601 dates |
| Ideas | `Documents/ideas.json` | Codable array |
| Export history | `Documents/exports.json` | Codable array, capped at 300 |
| Media | `Documents/Media/<uuid>.<ext>` | H.264/AAC in mp4 or mov |
| Poster frames | `Documents/Thumbs/<uuid>.jpg` | JPEG, 480 px max edge |

Writes are atomic. Projects are saved on every mutation from the editor's close path and when the editor disappears. `ProjectStore.update` refuses to roll back export counters from a stale snapshot.

Media is never duplicated except when a project is duplicated (deep copy of files and thumbnails, new IDs).

## Render pipeline (the load-bearing part)

`CompositionBuilder.build(project:renderSize:)` is synchronous in shape, async in fact — every asset property is loaded with `await`.

1. **Normalise on import.** `MediaImporter` reads `preferredTransform`. If it is not identity, it exports the clip once through an `AVMutableVideoComposition` that bakes the transform into pixels, producing a clean file with identity orientation. This removes orientation bugs from every later stage.
2. **Assemble.** One composition video track and (lazily) one clip-audio track. Each clip inserts `[trimStart, trimEnd]`, then `scaleTimeRange` applies speed. Cursor advances by the retimed duration so later clips land correctly.
3. **Mix audio.** `AVMutableAudioMixInputParameters` sets per-clip volume at each segment start, then a separate music track is looped to the total duration and faded out over 1.2 s. Empty audio tracks are removed before export — this was the cause of an export failure caught by the tests.
4. **Grade.** `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)` maps composition time to the active clip's `FilterPreset` and runs a small Core Image chain (public system filters only). The image is then aspect-filled and centre-cropped to the project frame.
5. **Text.** Overlays are rasterised once per build by `OverlayRenderer` into transparent `CIImage`s at render size, then composited inside the same handler when `time` falls within the overlay window. This keeps text and grade in one render pass and avoids the animation-tool restriction that applies to custom compositors.
6. **Export.** `AVAssetExportSession` with `AVAssetExportPresetHighestQuality`, the video composition, the audio mix and the best supported container. 4K doubles the render size (2160 × 3840 for 9:16). Output lands in `Documents/Renders`, then `PHPhotoLibrary` add-only saves it; the share sheet is always available as a fallback.

Preview uses the same `BuiltComposition`: an `AVPlayerItem` with `videoComposition` and `audioMix` attached, so what you see is what exports.

### Performance notes

- Composition rebuilds are debounced 320 ms; slider drags do not queue work per tick.
- Overlay rasterisation is per build, not per frame.
- The preview renders at project size (1080-class). Export renders at 1080 or 2160 depending on the quality choice.
- Timeline thumbnails are 480 px JPEGs cached in an `NSCache`, loaded off the main actor.

## Permissions and privacy

| Permission | When | Info.plist string |
| --- | --- | --- |
| Photo library (read) | Import | `NSPhotoLibraryUsageDescription` |
| Photo library (add) | Export save | `NSPhotoLibraryAddUsageDescription` |
| Camera | Record tab | `NSCameraUsageDescription` |
| Microphone | Record, voice capture | `NSMicrophoneUsageDescription` |
| Speech recognition | Generate captions | `NSSpeechRecognitionUsageDescription` |

No analytics SDK, no crash reporter, no network entitlement required by the app. `ITSAppUsesNonExemptEncryption` is false.

## Error handling

- Import: no video track, unreadable duration, export failure → alert with the reason.
- Build: empty project → "Add at least one clip"; no video tracks → "None of these clips have a video track".
- Captions: permission denied, recogniser unavailable, no speech → status line, never a crash.
- Export: preset unavailable, cancelled, Photos denied → export sheet message and share fallback.
- Camera: denied → Settings deep link; no device (simulator) → import fallback.

## Tests

`ReelcraftTests/RenderPipelineTests.swift` builds real media with `AVAssetWriter` and asserts:

1. Timeline duration honours trims and speed (1.75 s from 1.0 s + (2.0 − 0.5)/2).
2. Composition has one video track, a square render size and an audio mix.
3. Export writes a playable 1080 × 1080 file whose duration matches the edit.
4. 4× speed scales a 2 s clip to 0.5 s.
5. Projects round-trip through disk.

All five assertions pass on the iPhone 17 Pro simulator (iOS 26.2).

## Roadmap

Keyframes, cutouts/green screen (Vision person segmentation), voiceover recorder, project folders, camera resolution/FPS controls, sticker library, on-device beat detection. Each is a feature row marked `no` in `features.csv`.
