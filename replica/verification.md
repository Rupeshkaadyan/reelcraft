# Verification evidence

Run on 18 October 2026 against this repo. Re-run any line yourself.

## Render pipeline tests
```
xcodebuild -project Reelcraft.xcodeproj -scheme Reelcraft -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
Executed 4 tests, with 0 failures (0 unexpected) in 17.5s
```

## Device archive (unsigned compile for iPhone)
```
xcodebuild -project Reelcraft.xcodeproj -scheme Reelcraft -destination "generic/platform=iOS" -archivePath build/Reelcraft.xcarchive CODE_SIGNING_ALLOWED=NO archive
** ARCHIVE SUCCEEDED ** [19.153 sec]
```

## Design token contrast
```
  AA     6.57:1  danger                   on bg                   
  PASS   3.34:1  border-input             on bg                   ui

  11 pairs, 0 failing AA
```

## Brand sweep (nothing of the original left)
```
name    Edits              Marketing/privacy.html:30  <p class="lede">Reelcraft edits video on your iPhone. Your footage, projects and data never leave the device.</p>

2 hits (name 2). Replace every one before you launch.
```

## App Store listing lint
```
App Store
  name                  23 / 30    ok
  subtitle              30 / 30    ok
  promotional_text     103 / 170   ok
  description         1510 / 4000  ok
  keywords              90 / 100   ok
  whats_new             82 / 4000  ok

No issues.

0 errors, 0 warnings
```

## Feature parity
## Parity: 74.7 / 100

features 74.7  (41 counted, must-haves 17 of 20 done)

Not shippable yet: 3 must-have features are not done.

## By area, weakest first
- account                        0.0  (1 features)
- capture                       25.0  (3 features)
- effects                       33.3  (5 features)
- creator flow                  54.2  (7 features)
- captions                      70.0  (2 features)
- audio                         75.0  (4 features)
- library                       85.7  (4 features)
- editor                        95.7  (9 features)
- media pipeline               100.0  (1 features)
- text                         100.0  (1 features)
- frame                        100.0  (1 features)
- export                       100.0  (3 features)

## Missing, in build order
- [must] captions: Automatic captions, partial  (On device Speech framework; needs permission and the on device model)
- [must] capture: Camera capture up to 10 minutes, partial  (Built with AVFoundation; needs a physical device to verify end to end)
- [must] creator flow: Creator insights dashboard, partial  (Local edit and export stats; account metrics need platform data)
- [should] capture: Camera resolution frame rate and dynamic range, no  (Roadmap beyond the default high preset)
- [should] effects: Green screen and cutout, no  (Roadmap - needs a segmentation model)
- [should] effects: Stickers and GIFs, no  (Needs a licensed asset library)
- [could] account: Sign in with Instagram, no  (Meta account system - not clonable)
- [could] audio: Audio cleanup and voice enhance, no  (Roadmap)
- [could] audio: Voiceover recording, no  (Roadmap)
- [could] capture: Teleprompter, no  (Roadmap)
- [could] creator flow: Reels discovery feed with trending audio, no  (Licensed catalogue and network - not clonable)
- [could] creator flow: Retention and engagement graphs, no  (Requires published post data)
- [could] creator flow: Saved reels and collections, no  (Instagram account data - not clonable)
- [could] creator flow: Storyboards and scripts, no  (Roadmap)
- [could] editor: Keyframes, no  (Roadmap)
- [could] effects: Animate still images, no  (Roadmap)
- [could] effects: Effect search and customisation, no  (Roadmap)
- [could] library: Project folders, no  (Roadmap)

## Fix in the matrix
- line 36: priority 'skip' is not must/should/could, counted as could
- line 37: priority 'skip' is not must/should/could, counted as could
- line 42: priority 'skip' is not must/should/could, counted as could
