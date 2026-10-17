# Submitting Reelcraft to the App Store

Everything in this repo is ready. Three steps need your Apple account and there is no way around that: enrolling in the Developer Program, creating the App Store Connect record, and uploading the build.

Work through this document top to bottom. Steps 1, 3 and 9 are yours; everything else is already done and checked by `tools/preflight.sh`.

## 0. What is already done

| Item | State |
| --- | --- |
| App builds and runs, iPhone only, iOS 17+ | ✅ debug + Release |
| Render pipeline tests | ✅ 4 passing (`ReelcraftTests/RenderPipelineTests.swift`) |
| Release build compiles for a real iPhone | ✅ unsigned device archive |
| App icon | ✅ `Assets.xcassets/AppIcon.appiconset` (1024 px, no alpha) |
| Five App Store screenshots, 1320 × 2868 | ✅ `Marketing/appstore/` |
| Store copy within Apple's limits | ✅ `replica/launch/listing.json`, linted |
| Privacy policy | ✅ `PRIVACY.md` + `Marketing/privacy.html` (host it, see step 8) |
| No third-party SDKs, no tracking, no account | ✅ `ITSAppUsesNonExemptEncryption = false` |

## 1. One-time account setup (yours)

1. Enrol in the [Apple Developer Program](https://developer.apple.com/programs/) and note your **Team ID** (Membership details).
2. Decide the bundle identifier. The project ships as `com.reelcraft.app`. If you change it, register the new one under [Identifiers](https://developer.apple.com/account/resources/identifiers).
3. Put the Team ID into `project.yml`:

   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: "ABCDE12345"     # your Team ID
   ```

   and, only if you changed it, the bundle id:

   ```yaml
   targets:
     Reelcraft:
       settings:
         base:
           PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.reelcraft
   ```

4. Regenerate and sign in Xcode once:

   ```bash
   xcodegen generate
   open Reelcraft.xcodeproj      # Xcode → Settings → Accounts → add your Apple ID
   ```

## 2. Run the preflight

```bash
bash tools/preflight.sh
```

Four stages, each prints PASS or FAIL:

1. **Doc links and listing** — every local image and link in the README, policy and this file resolves; the listing is inside every App Store character limit and free of the original app's name.
2. **Xcode project** — `xcodegen generate` (skipped when XcodeGen is not installed).
3. **Tests** — the four render pipeline tests on a simulator. It resolves the device name to a UDID, because two installed runtimes can share a name.
4. **Archive** — signed and exported to `build/ipa/Reelcraft.ipa` when `DEVELOPMENT_TEAM` is set; otherwise an unsigned device archive that proves the Release build compiles.

Useful switches: `SIMULATOR="iPhone 16 Pro"`, `SKIP_TESTS=1`, `SKIP_ARCHIVE=1`. Logs land in `build/`.

## 3. Archive, export, upload

Preflight already does the archive and export. To do it by hand:

```bash
xcodebuild -project Reelcraft.xcodeproj -scheme Reelcraft \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Reelcraft.xcarchive -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath build/Reelcraft.xcarchive \
  -exportOptionsPlist tools/ExportOptions.plist -exportPath build/ipa \
  -allowProvisioningUpdates
```

That writes `build/ipa/Reelcraft.ipa`. To upload, pick one:

- **Xcode Organizer** — Window → Organizer → Archives → Distribute App → App Store Connect → Upload. Easiest, and it handles the account.
- **Transporter** — drag the IPA in. Fastest for repeat uploads.
- **Command line** — change `destination` from `export` to `upload` in [`tools/ExportOptions.plist`](tools/ExportOptions.plist) and run the export command again (needs the Mac signed into Xcode with an App Store Connect role).

Keep `manageAppVersionAndBuildNumber` on so App Store Connect never rejects a duplicate build number.

## 4. App Store Connect app record

My Apps → **+** → New App:

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | `Reelcraft: Video Editor` |
| Primary language | English (U.S.) |
| Bundle ID | the one from step 1 |
| SKU | `reelcraft-ios-1` |
| User access | Full Access |

Then set:

| Section | Value |
| --- | --- |
| Category | Photo & Video (secondary: Productivity) |
| Price | Free |
| Availability | All countries and regions |
| Version | 1.0.0 (build 1) |
| Copyright | your name or company, 2026 |
| Support URL | your site or the repo URL |
| Marketing URL | optional |

Print every listing field ready to copy:

```bash
python3 -c "import json; d=json.load(open('replica/launch/listing.json'))['app_store']; [print('--- %s ---\n%s\n' % (k, v)) for k, v in d.items()]"
```

That yields the name, subtitle, promotional text, description, keywords and what's new — all already linted by the preflight.

## 5. App Privacy

Answer **Data not collected**. There is no account, no analytics, no advertising SDK, no crash reporter and no server.

If App Store Connect asks for a privacy policy URL, host [`Marketing/privacy.html`](Marketing/privacy.html) (see step 8) and paste that URL. It is required for every app, even one that collects nothing.

Permission strings already in the build, and why:

| Permission | String shown to the user |
| --- | --- |
| Photo library (read) | Reelcraft imports videos you choose from your photo library. |
| Photo library (add) | Reelcraft saves your finished videos to your photo library. |
| Camera | Reelcraft uses the camera to record clips for your projects. |
| Microphone | Reelcraft records audio with your clips and voiceovers. |
| Speech recognition | Reelcraft transcribes your clips on device to create captions. |

The app uses no third-party SDKs and no required-reason APIs, so no `PrivacyInfo.xcprivacy` manifest is needed. If the upload warns about one anyway, add a manifest that declares nothing collected.

## 6. Age rating

4+. Every content category answers **None**: violence, mature themes, profanity, horror, medical, alcohol/tobacco/drugs, gambling, contests. No unrestricted web access, no user-generated content sharing, no ads, no in-app purchases.

## 7. Screenshots

Upload the five files in [`Marketing/appstore/`](Marketing/appstore) to the **6.9-inch** slot, in this order:

1. `01-projects.png` — Every cut in one place
2. `02-editor.png` — Frame-accurate timeline
3. `03-discover.png` — Start from a look
4. `04-ideas.png` — Catch ideas early
5. `05-insights.png` — Know your habits

All 1320 × 2868. The 6.5-inch and 5.5-inch slots are optional and can be skipped; App Store Connect only requires the 6.9-inch set for iPhone.

## 8. Host the privacy policy

Any static host works: GitHub Pages, Cloudflare Pages, Netlify, or your own domain.

```bash
# simplest, from the repo
cp Marketing/privacy.html ./index.html    # then serve that folder from any static host
```

Paste the resulting URL into App Store Connect → App Privacy → Privacy Policy URL.

## 9. Review notes (paste this)

> Reelcraft is a fully local video editor. There is no account, no sign-in, no server and no network calls.
>
> To reach the editor: tap Projects → + to create a project, then tap the film icon in the empty canvas and choose a video from Photos. The tool row (Trim, Text, Filters, Speed, Audio, Captions, Frame) edits the selected clip; the timeline supports split at playhead, reorder, duplicate and delete. Tap Export, choose 1080p, and the video renders on device and is saved to Photos.
>
> Testing notes:
> - Export asks for add-only photo library access. If that permission is denied, the file can still be shared with the system share sheet.
> - Automatic captions use Apple's Speech framework on device. On a device where the speech model is not installed, the Captions panel shows a message instead of caption rows; manual captions always work.
> - The in-app camera is only reachable on a device with a camera (Record tab).
> - 4K export is slower than 1080p on long timelines.
>
> No purchases, no ads, no user-generated content sharing.

## 10. TestFlight on a real iPhone

Three things cannot be proved in the simulator, so test them before you submit:

- [ ] **Camera** — Record tab → record a clip → it appears in Projects and plays back with audio.
- [ ] **Captions** — open a clip with speech, tap Captions → Generate, check the timing, then repeat in airplane mode.
- [ ] **4K** — export a 30–60 s project at 4K, time it, confirm it lands in Photos and plays.
- [ ] **Denied permission** — deny photo-library add, export, confirm the share sheet still works.
- [ ] **Long clip** — import a 4K clip longer than a minute; check orientation, trimming and memory.
- [ ] **Many clips** — a project with 8–10 clips: scrubbing, timeline scrolling, export.

## 11. Known risks

- **Camera capture is unverified on hardware.** It builds against AVFoundation and was exercised for session setup only; the simulator has no camera. The TestFlight pass above closes this.
- **Auto captions depend on Apple's speech model.** Offline or first-run devices may show the fallback message. Consider softening the empty state to "Available once the speech model downloads".
- **4K export is slow on older phones** for long timelines. Listing copy says "up to 4K".
- **The name Reelcraft is not trademark-cleared.** Run the checks in [`replica/brand.md`](replica/brand.md) (USPTO, domain, App Store name availability) before you sell anything.
- **Review may ask about the 4K claim or the photo/camera permissions.** The review notes above answer both; the permission strings are specific.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `No signing certificate "iOS Distribution" found` | Xcode → Settings → Accounts → add your Apple ID, then re-run step 1. |
| `No profiles for 'com.reelcraft.app' were found` | Register the bundle ID, confirm `DEVELOPMENT_TEAM`, keep `-allowProvisioningUpdates`. |
| `Ambiguous destination` or simulator not found | `SIMULATOR="iPhone 16 Pro" bash tools/preflight.sh` or install a runtime in Xcode. |
| Export fails with `The request contains an invalid parameter` | Usually a duplicate build number or missing App Store Connect role; check the Organizer log. |
| Upload warns about `PrivacyInfo.xcprivacy` | Only relevant for required-reason APIs or third-party SDKs; this app has neither, so add a manifest declaring nothing if the warning persists. |
