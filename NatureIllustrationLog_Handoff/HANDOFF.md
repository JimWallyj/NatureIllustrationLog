# Nature Illustration Log and Locator — Handoff

Last updated 2026-10-18, at the end of the second conversation (Mac-transfer decisions and Phase 1). Read this first, then the spec. The first conversation's handoff is kept as `HANDOFF_2026-10-13_original.md`.

## What this is
An iPhone/iPad app (SwiftUI + SwiftData) for nature illustrators. Each "file" holds one or more photos of a nature subject, field notes, a pinned map location, notes for an illustration project, and photos of the finished illustration. The illustration itself is made outside the app. A Mac version is being added so files can move between the user's devices.

## Where things are (user's Mac)
- **Live Xcode project:** `~/Desktop/NatureIllustrationLog/` — `NatureIllustrationLog.xcodeproj`, source in `NatureIllustrationLog/` (Models, Services, Views), `Localizable.xcstrings` and `InfoPlist.xcstrings` at the top level, `NatureIllustrationLog/Info.plist` (document type settings). Under Git; the user commits to GitHub.
- **"Jims Source Files - NatureIllustrationLog app"** is an older *copy* of the project — not the live one. Don't edit it.
- **Handoff folder:** `~/Desktop/NatureIllustrationLog/NatureIllustrationLog_Handoff/` — this file, specs, and per-step folders (`StepXX_Files` = what was installed, `StepXX_Backup_Originals` = what it replaced).
- **Specs:** `Nature_Illustration_Log_Spec.md` (original, untouched) and **`Nature_Illustration_Log_Spec_MacTransfer.md` (current source of truth)**. A copy of the current spec is also in the claude.ai Project.
- The project folder uses Xcode's synchronized folders: a new .swift file placed in `NatureIllustrationLog/…` is picked up automatically.

## Working method (keep doing this)
- Claude has direct access to the live project through the linked Mac: installs files directly, saves the replaced files to a `StepXX_Backup_Originals` folder first, and adds Spanish to `Localizable.xcstrings` by editing the JSON in place (never by replacing the file).
- Claude can't compile. Say so; the user builds (Cmd-B) and reports errors. A "Cannot find X in scope" shown *before* building is usually Xcode lagging — building clears it.
- After any SwiftData stored-property change, the user must delete the app from the device first.
- Copying files back to the Mac with the "commit files" tool once silently wrote an older cached version. Prefer writing on the Mac directly with the shell, and verify.

## Current state (all built, run, and tested by the user on iPhone 17, iOS 27.0.1, Xcode 27.0)
Everything from the first conversation, plus Phase 1 of the Mac-transfer work:
- **Step 1a:** hidden fields on SubjectFile (`uniqueID`, `lastChanged`, `isReadOnly`, `isPlaceholder`, `replacedDate`; computed `isLocked`); `touch()` updates `lastChanged` on note/location/photo/date/album edits. Gear screen renamed **Settings** ("Ajustes"); file/struct still `EditHomeView`. Shared `RaisedButtonStyle` (gradient, top highlight, shadow, press-in): Home's "Illustration Projects" in Apple standard blue, Settings buttons in forest green.
- **Step 1b:** File List **Select** mode (Apple circles, Select All/Deselect All, Cancel) and **Share** icon → "Send to My Devices" / "Share Read-Only" → system share sheet. Transfer file = one `.natlog` per file (`FilePackage.swift`: 8-byte "NATLOG01" marker, manifest JSON length, manifest, then photo bytes).
- **Step 1c:** import — open a `.natlog` from AirDrop/Messages/Mail (from the Files app: preview → Share → app icon. "Supports opening documents in place" is left **out** of the project — iOS treats that as NO; macOS rejects NO, and on the Mac double-clicking a .natlog in Finder opens and imports it), or Settings → **Import Files** (multi-select). `ImportManager.swift` + `ImportOverlay.swift` (overlay cards: progress, Name Conflict, Not Enough Space, summary). Read-only files: lock icon, "Read-Only" line, nothing editable. Storage space check before importing. Exported type `com.walejko.NatureIllustrationLog.file` (extension natlog) and document type (Owner) registered in Info.plist.
- **Step 1d:** File List uses a **large title**; **trash icon** in Select mode deletes several files (with confirmation). **Update This File** in the Name Conflict card (same hidden ID, own device; "Update Anyway?" if the device copy is newer). **Recently Replaced** (Settings button with count → list with hint bar, swipe Restore/Delete Now, tap to view with Restore/Delete Now buttons; auto-delete after 30 days at launch). Space check when adding photos (Add File, File Screen, albums).

## Decisions made in the second conversation (don't re-ask)
- No paid Apple Developer account for now; revisit when submitting to the App Store.
- Transfers use export/import `.natlog` packages (no sync). Two kinds: "Send to My Devices" (editable) and "Share Read-Only" (to other people).
- Name conflicts: Use suggested name "Name (2)", Enter a new name (checked, asks again if taken), Skip This File, Cancel Transfer (files already imported stay). "Do this for all remaining conflicts" covers suggested name and Skip. **Never a plain replace.**
- Update (safe replace) only for the same hidden ID from the user's own device; older version → Recently Replaced for 30 days; warn if the device copy is newer. Read-only copies never get Update.
- Read-only recipients: view and delete only; can't edit or pass on; lock icon. "Read-only" is enforced by the app, not real security.
- Offloading (Phase 3): keep a read-only **placeholder** (name, notes, dates, location, thumbnails) with an "On Mac" badge; after sending, ask **"Has this file arrived on your Mac?"** (Yes / Not Yet) before removing full photos. Deleting a placeholder only removes it from the device.
- No general "storage almost full" warning and no storage-use display; only a space check before big operations.
- Export/Share and Select live on the File List; Import Files and Recently Replaced live on Settings.
- Swipe delete (iPhone) and a Remove button / Delete key / right-click (Mac) always confirm.
- The Mac version should work and look as much like the iPhone/iPad version as practicable.

## Phase 2 progress (2026-10-22)
- Built and tested on the Mac (Mac Catalyst, macOS 27): window size/minimum, File menu (⌘N New File, ⌘I Import Files…), Photos permission, Photo Location with its own solid top bar and full-window map on the Mac, album Select + trash and right-click menus, File List right-click menus and Delete key, export fix for Mac AirDrop/Mail.
- Step 2b (installed 2026-10-22, testing): Add Photos / album + offer Photos Library or Files; `ImageFileLoader.swift` reads EXIF dates and converts RAW to JPEG.
- Step 2b tested; dates now use `DateChoiceSheet` (Done accepts today; Save waits for a date in Add File).
- **Phase 2 complete (tested 2026-10-25 on Mac and iPhone).**
- Step 2c: zoom in Full Photo View (`ZoomableImageView`, UIScrollView-based); File Screen max width 820 on wide windows; Select mode toggles each row independently (custom `SelectionCircle`, no List selection/editMode) in File List and albums — replaces Command/Shift-click.
- **Phase 3 (offload) complete — tested 2026-10-26 on iPhone and Mac:** `AlbumPhoto.imageData` is now optional; offload = export (ownDevices) + "Has this file arrived on your Mac?" → Yes removes full photos and sets `isPlaceholder`; `OnMacBadge` / `OnMacNote`; Update from the Mac deletes the placeholder and inserts the full file (`restoredFromMac` in the summary). Offload is hidden on Mac Catalyst (`FileListView.canOffload`).
- Then the User Manual (notes in the Project's User_Manual_Notes.md).

## Next work
- **Phase 2: Mac version.** Decisions to walk through one at a time: (1) how to add the Mac (Mac Catalyst vs native macOS vs "Designed for iPad"), (2) macOS floor (user tests on macOS 27; Claude suggested 27 to match the iOS rule), (3) Mac photo sources (Photos library, Finder files, drag and drop), (4) Mac layout details.
- **Phase 3: Offload** ("Send to Mac and Free Up Space", placeholders, "On Mac" badge, image becomes optional on AlbumPhoto).
- Decided 2026-10-26: "Do this for all remaining conflicts" also covers Update (only where offered; still asks when the device copy is newer).

## Open items (carried over)
- Fluent Spanish review of both String Catalogs before sharing the app. More languages later (French, German, Japanese mentioned).
- Verify iPad (10th gen or later) on iOS 27; free-account builds expire after about 7 days; new Xcode 27 warnings.
- Accessibility (VoiceOver labels, Dynamic Type) deferred, not rejected.
- Unit tests in spec Section 8 not written yet.
- Smaller stored copies of full photos: revisit with offloading.
- Display Name is "Nature Illustration Log" (set 2026-10-27). The user likes the iPhone icon label without spaces ("NatureIllustration…"); to make that permanent, set an iPhone-only `INFOPLIST_KEY_CFBundleDisplayName[sdk=iphoneos*]` (with Xcode quit) — not done yet.
- App icon is still the blank placeholder; design one before sharing the app.
- (Superseded) On hold: a display name "Nature Illustration Log" instead of "NatureIllustrationLog" in the Mac title bar/menu and under the icon (may be shortened on the iPhone home screen).
- System permission prompts (Photos, Location) are drawn by iOS/macOS; their button order can't be changed by the app.

## Gotchas that cost time
- Stale builds cause odd errors: delete the app from the Simulator/device and Clean Build Folder (Shift-Cmd-K).
- `scaledToFill()` widens layout; use `Color.clear.overlay { image }` plus `.clipped()`.
- Custom '<' buttons need `.navigationBarBackButtonHidden(true)`.
- The Photos key must be exactly `NSPhotoLibraryUsageDescription`.
- Replacing a String Catalog file makes "Localizable 2"; edit the existing catalog instead.
- Map labels and system buttons follow the device language, not the scheme language.
- Dismiss the photo picker through SwiftUI state, not `picker.dismiss`.
- Files app shows a preview (not the app) for `.natlog` because opening-in-place is off — import via Share → app icon.
- Setting `LSSupportsOpeningDocumentsInPlace = NO` breaks the Mac Catalyst build ("not supported on macOS"); per-SDK conditions didn't take effect while Xcode was open. Fix used: remove the setting entirely. After editing project.pbxproj outside Xcode, quit and reopen Xcode.
- Mac Photos access: the Signing & Capabilities "Photo Library" section did not add the Mac sandbox permission; macOS silently denied access until `ENABLE_RESOURCE_ACCESS_PHOTO_LIBRARY = YES` was added to the build settings (with Xcode quit). On the Mac, "Open Settings" goes to System Settings → Privacy & Security → Photos (`SystemSettingsLink`).
- Compact (pop-up) DatePicker problems: it can't accept the already-highlighted date (today), and on the Mac its pop-up can stay open so `dismiss()` closes the pop-up instead of the sheet (Save didn't close Add File). Photo dates now use `DateChoiceSheet` (graphical calendar + Cancel/Done) in PhotoComponents.swift.
- iOS share sheet: AirDrop does not reliably report "completed" to the app (and the sheet can close before the result arrives). The offload therefore always asks "Has this file arrived on your Mac?" when the share window closes.
- Swipe actions are hard to discover; pair them with visible buttons or a hint.
- Temporary export (.natlog) files must NOT be deleted when the share window closes: on the Mac, AirDrop and Mail read the file after the window closes (Mac → iPhone AirDrop silently did nothing). Now cleared when older than an hour (`FilePackage.removeOldExportFolders`, at launch and before each export).
- Harmless build warning about not declaring LSSupportsOpeningDocumentsInPlace: expected, since the key is deliberately left out. Optional later: retry `[sdk=iphoneos*]`/`[sdk=iphonesimulator*]` = NO with Xcode fully quit.
- Mac Catalyst top-bar buttons don't refresh their enabled/disabled state or label when selection changes (only after a window resize). Fix: give such toolbar buttons an `.id(...)` tied to the state (used in AlbumView and FileListView).
- On the Mac, glass toolbars ignore `toolbarBackground`; the Photo Location screen hides the navigation bar and draws its own solid top bar instead.

## How the user likes to work
- Not an Xcode expert: complete files, which folder, step-by-step Xcode instructions.
- Walk through decisions one at a time with options, a recommendation, and the tradeoff; ask before changing behavior.
- Keep the spec updated with each change. Say plainly that code is not compiled.
- Follow Apple conventions where they exist.
- Conversation in English; only the app's labels are Spanish.
