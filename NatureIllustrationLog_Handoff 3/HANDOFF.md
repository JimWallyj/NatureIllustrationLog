# Nature Illustration Log and Locator — Handoff

Written 2026-10-13 at the end of the first long conversation. Read this first, then the spec.

## What this is
An iPhone/iPad app (SwiftUI + SwiftData) for nature illustrators. Each "file" holds one or more photos of a nature subject, field notes, a pinned map location, notes for an illustration project, and (later) photos of the finished illustration. The illustration itself is made outside the app.

## Current state
- Everything in the spec is built and has been run and tested by the user on an iPhone 17 (iOS 27.0.1), Xcode 27.0, deployment target iOS 27.
- Claude has no Xcode in its environment, so none of this code was compiled by Claude. The user built it, ran it, and reported errors. The code compiled and ran cleanly at the end of the conversation.
- Spanish is built (String Catalogs). Accessibility (VoiceOver, Dynamic Type) is deliberately deferred.

## What is in this bundle
- `Nature_Illustration_Log_Spec.md` — the spec. It is the source of truth for behavior.
- `Source/` — the Swift files, grouped as Models, Services, Views, Resources.
- **Accuracy caveat:** three files (`Views/HomeView.swift`, `Services/LocationDescriber.swift`, `Services/NavigationCoordinator.swift`) were never delivered as downloads. They are rebuilt from the conversation and match what the user compiled, but **the user's own Xcode project is the source of truth**. If the project and this bundle differ, trust the project.
- Not included: the `.xcodeproj`, the asset catalog, and project settings. Claude never saw them.

## How the app is built
- Two SwiftData models: `SubjectFile` (name, notes, pinned location, dateAdded) and `AlbumPhoto` (full image, ~400 px thumbnail, date, which album, order). One file has many photos; both albums (subject and illustration) live in the same list, told apart by a `kind` value. Deleting a file deletes its photos.
- Full-size photos use `@Attribute(.externalStorage)`. Lists use the thumbnails.
- `NavigationCoordinator` holds the one NavigationStack path so Home buttons can pop to the root. Screens use their own '<' buttons with `.navigationBarBackButtonHidden(true)`.
- `PhotoAssetPicker` wraps PHPickerViewController (multi-select, ordered), reads each photo's date from its Photos asset, and builds the thumbnail.
- Map: SwiftUI MapKit. Place names use `MKReverseGeocodingRequest` (CLGeocoder is deprecated in iOS 26). Place search uses `MKLocalSearch`.
- The Home background is a JPEG in the Documents folder with its filename in `@AppStorage`. It is not part of SwiftData.
- Info.plist keys: `NSPhotoLibraryUsageDescription` and `NSLocationWhenInUseUsageDescription`. `InfoPlist.xcstrings` translates them.

## Decisions already made (don't re-ask)
- Photos are copied into the app's storage. No smaller stored copies of full photos for now (revisit with the Mac work). Thumbnails only.
- Location is a manual map pin, not read from the photo. Photo GPS was inaccurate (a beach photo landed inland), and many camera photos have none.
- Dates: auto-filled from the Photos asset when available, with manual entry as the fallback. Each photo keeps its own date, and the date is editable by tapping it.
- Duplicate file names are blocked ("File Exists"). Delete needs confirmation. Notes, dates, and location autosave.
- Photos access is optional: if denied, an explainer offers Settings or "Continue Anyway".
- Home screen has a fixed icon bar above the background photo.
- Language follows the device language (Spanish and English). There is no in-app picker. User-typed content is never translated.
- Albums: the File Screen and File List show the first photo; "Set as First" reorders.
- iOS floor 27.0. Test older versions only if the app is shared later.
- `dateAdded` stays internal (not shown).

## Next work: Mac transfer (not started)
Goals from the user:
1. Offload files from the iPhone/iPad to a Mac to save device storage.
2. A Mac version of the app, so the user can record reference photos and finished projects that live on the Mac, and view photos and maps larger.
3. Transfer both ways (device to Mac, Mac to device).
4. Sharing with other people is **read-only results**, not collaboration.

What was discussed and recommended:
- Build on **export/import packages** (one package per file: photos, notes, dates, location), moved by AirDrop, Files, Messages, Mail, or a shared iCloud Drive folder.
- iCloud sync (SwiftData + CloudKit) only syncs a person's own devices, needs a paid Apple Developer account, and per an Apple forum answer (undated; re-check for iOS 27) SwiftData has no sharing support. Live sharing would mean moving to Core Data.
- Other people can only install the app through TestFlight or the App Store, which needs the paid account. The user was hesitant about the cost and has not decided.
- Each file needs a hidden unique ID (currently files are told apart only by name), so imports can tell an updated copy from a different file with the same name. Do this before many real files exist.
- Likely iOS-only code to replace for macOS: the PHPicker wrapper, `UIImage`/`UIImage.preparingThumbnail`, `.topBarLeading/.topBarTrailing` toolbar placements, `fullScreenCover`, `UIApplication.openSettingsURLString`, `Color(.systemBackground)`, `navigationBarHidden`.
- Suggested phases: (1) package format plus export/import on iPhone, (2) Mac target, (3) offload with safety checks (delete from the device only after the export is confirmed saved).

Decisions still pending:
- After offloading, should the phone keep a placeholder (name, thumbnail, notes) or remove the file entirely?
- Rule when an imported file matches one already on the device: replace, keep both, or skip.
- Which copy wins if the same file is edited in two places without sync.
- Should shared copies import as read-only? (A flag in the package is one idea; confirm with the user.)
- Paid Apple Developer account: yes or no, and when.

## Open items
- Have a fluent Spanish speaker review `Localizable.xcstrings` and `InfoPlist.xcstrings` before sharing the app.
- More languages later (the user earlier mentioned French, German, Japanese).
- Verify: iPad (10th generation or later) compatibility with iOS 27; that free-account builds expire after about 7 days; any new Xcode 27 warnings.
- Accessibility (VoiceOver labels on icon buttons, Dynamic Type layout pass) is deferred, not rejected.
- Unit tests listed in the spec's Section 8 are not written yet.

## Gotchas that cost time
- Odd errors (including "Cannot find 'X' in scope") were usually stale builds. Fix: delete the app from the Simulator and run Clean Build Folder (Shift-Cmd-K).
- After any SwiftData model change, delete the app from the test device first.
- `scaledToFill()` on an image widens its layout and can push other views off-screen. Use `Color.clear.overlay { image }` plus `.clipped()`.
- Custom '<' buttons need `.navigationBarBackButtonHidden(true)`, or a second back arrow appears.
- The Photos key must be exactly `NSPhotoLibraryUsageDescription`. A similar key name caused a crash once.
- Replacing a String Catalog: delete the old file from disk (Show in Finder) or Xcode names the new one "Localizable 2" and Spanish stops working.
- Map labels and system buttons follow the device language, not the Xcode scheme's App Language. Test by changing the device language.
- Dismiss the photo picker through SwiftUI state, not `picker.dismiss`, or sheets and picker state fall out of sync.

## How the user likes to work
- Not an Xcode expert: give complete replacement files, say which folder each goes in, and give step-by-step Xcode instructions.
- Ask before changing behavior or guessing at something unclear. Give a short recommendation with the tradeoff.
- Keep the spec updated alongside code changes. The user reviews the full spec and makes their own edits. They often send it back as PDF or Markdown (Pages files can't be read).
- Say plainly that code is not compiled, so the user knows to report errors.
- Keep the conversation in English (only the app's labels are Spanish).

## Suggested first message in the new conversation
"I'm continuing work on the Nature Illustration Log and Locator app. I've attached the handoff bundle. Please read HANDOFF.md and the spec first, then walk me through the pending Mac-transfer decisions one at a time before writing any code."
