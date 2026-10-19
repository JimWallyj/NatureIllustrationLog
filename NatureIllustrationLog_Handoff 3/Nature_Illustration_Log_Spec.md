# Agent Build Specification
## Nature Illustration Log and Locator

### 1. Overview
**Purpose / problem statement:** The Nature Illustration Log and Locator app provides a simple tool for nature illustrators to capture a source photo and basic details in the field on their device. The resulting repository should prove useful to the nature illustrator for their next illustration project. The illustrator user will import their nature subject from the Photos app. The file entries in this Nature Illustration Log & Locator app will include one or more photos of the subject (with dates taken), user field notes, initial notes and plans that support the user's illustration project, and later, photos of the resulting illustration. The illustration project is not part of this app. The app merely stores a picture of the nature subject and related user notes.

**Target user:** Nature illustrators

**Success criteria (what "done" looks like):** An interface for storing nature subject photos and notes in files stored on the local device.

### 2. Platform & Environment
- **iOS version floor:** 27.0 (the version the app has been tested on; earlier versions are untested and not supported)
- **Devices supported:** iPhone 17, iPad (10th generation or later)
- **Orientation support:** Portrait or Landscape
- **Xcode / Swift version:** Xcode 27.0
- **Tested on:** iPhone 17 running iOS 27.0.1
- **SwiftUI vs. UIKit interop needs:** PHPickerViewController is wrapped via UIViewControllerRepresentable for photo selection with asset metadata access.

### 3. Architecture
- **Pattern:** MVVM-leaning, with @Observable for shared navigation state
- **Data flow:** @Observable, async/await
- **Persistence:** SwiftData
- **Networking layer:** None required for core app; MapKit's MKLocalSearch and reverse geocoding require network connectivity when used
- **Third-party dependencies (SPM packages):** Forbidden

### 4. Screens & Flows

#### Screen: Home View
- **Entry points:** Click on icon from the device.
- **Exit points:** File List Screen, Add File Screen, Edit Home Screen.
- **UI elements:**
  - a. Screen Background = Gradient graphic at the start, which can be updated by the user with a nature photo from their Photos app files.
  - b. Plus sign (+) in the top left corner to open Add File screen
  - c. Gear sign in the top right corner to open Edit Home Screen
  - d. Big button in the center to open File Screen. Button is named, "Illustration Projects"
- **States:** empty / loading / error / populated
- **User actions & resulting behavior:** See 'a' through 'd', above

#### Screen: File List
- **Entry points:** Clicks the big button in the center of the Home Screen (labeled "Illustration Projects") to open File Screen
- **Exit points:** File Screen and Home Screen
- **UI elements:**
  - a. A list of the files that have already been added.
    - i. File names listed in alphabetical order.
    - ii. Thumbnail of the first photo in the file's subject photo album, next to the file name.
  - b. Plus sign in the top left corner to open Add File screen
  - c. Home button in the top right corner to return to the Home Screen
- **User actions & resulting behavior:**
  - a. Click on a file name or thumbnail photo to open File Screen
  - b. Swipe on a file name to delete the file (confirmation required before the delete completes)
  - c. Click on the Home button to return to the Home Screen

#### Screen: File View
- **Entry points:** User clicks on a specific file name or thumbnail photo from the File List Screen
- **Exit points:**
  - a. '<' sign in the top left corner to return to the File List Screen
  - b. Home button in the top right corner to return to the Home Screen
  - c. Edit Location link takes the user to the Photo Location Selection screen
  - d. Tapping the first photo, or the "Photo Album" link under it, takes the user to the Photo Album screen (for the subject photos or the illustration photos)
  - e. Tapping the map takes the user to Full Map View
- **UI elements:** See 'a' through 'e', above
- **Data displayed & source:**
  - a. File Name = located top center
  - b. Date in which the first photo was taken = located just above left of photo. Tapping the date opens a calendar to change it. If no date is available, a date field appears here instead so the user can enter it by hand.
  - c. The first photo of the subject photo album, shown large (tappable — opens the Photo Album screen), with a "Photo Album (n)" link underneath showing how many photos the album holds. If the album is empty, an "Add Photos" button appears instead.
  - d. Location of photo pinned in Apple maps view (tappable — opens Full Map View)
  - e. Under the location map view resides a link to the Photo Location Selection Screen, named "Edit Location" (or "Record Photo Location" if no location has been set yet)
  - f. Editable text box with user field notes
  - g. Illustration Project Photos — a second photo album for the finished (or in-progress) illustration, located just above the Illustration Project Notes textbox and label. It shows the first illustration photo with its date and a "Photo Album (n)" link, the same as the subject photos. When there are none yet, an "Add Illustration Photos" button appears instead.
  - h. Editable text box with initial notes and plans for the user's illustration project
- **User actions & resulting behavior:**
  - a. '<' sign in the top left corner returns to the File List Screen
  - b. Home button in the top right corner returns to the Home Screen
  - c. Ability to edit text fields and location. Changes save automatically as the user types/edits — autosave is sufficient; no separate Save button is needed on this screen.
  - d. Tapping a photo or its "Photo Album" link opens that album; tapping the map opens Full Map View
  - e. Photos are added, deleted, and reordered in the Photo Album screen (this replaces the earlier "Replace Photo" link)

#### Screen: Photo Album
- **Entry points:** Tapping the first photo, or the "Photo Album" link, on the File Screen. The same screen is used for the subject photos (titled "Photos") and the illustration photos (titled "Illustration Photos").
- **Exit points:** '<' icon in the top left corner returns to the File Screen
- **UI elements:**
  - a. A list of the album's photos in order, each shown as a thumbnail with its date next to it. Tapping the date opens a calendar to change it. A photo with no date shows a date field so the user can enter it by hand.
  - b. Plus sign (+) in the top right corner to add photos
- **User actions & resulting behavior:**
  - a. Tapping a thumbnail opens Full Photo View at that photo
  - b. The plus sign opens the Photos app, where one or several photos can be chosen at once. They are added to the end of the album in the order chosen, with a progress indicator while they load.
  - c. Swiping a photo left deletes it, after a confirmation
  - d. Swiping a photo right ("Set as First") moves it to the front of the album, which makes it the photo shown on the File Screen (and, for the subject album, in the File List)
  - e. An empty album shows "No Photos Yet" with a prompt to tap the plus sign

#### Screen: Full Photo View
- **Entry points:** Tapping a photo in the Photo Album screen
- **Exit points:** '<' icon in the top left corner returns to the Photo Album screen
- **UI elements:** The photo, shown full screen. Swiping left or right moves through the album's other photos. Not editable from this screen.
- **User actions & resulting behavior:** See above.

#### Screen: Full Map View
- **Entry points:** Tapping the map on the File Screen
- **Exit points:** '<' icon in the top left corner returns to the previous screen
- **UI elements:**
  - Map and Satellite buttons on the bottom to change the map view
  - The pinned location, shown full screen. The pin is not editable from this screen.
- **User actions & resulting behavior:** Map and Satellite buttons change the map style. See above for exit.

#### Screen: Add File
- **Entry points:** User clicks the plus sign in the Home Screen or in the File List Screen.
- **Exit points:**
  - a. Cancel button in the top left corner returns to whichever screen Add File was opened from (Home or File List)
  - b. Save button located top right to save the file
  - c. "Record Photo Location" link which takes the user to the Location Picker screen
- **UI elements:**
  - a. See 'a' through 'c', above
  - b. Photos section: an "Add Photos" button (it reads "Add More Photos" once photos have been added) opens the Photos app, where one or several photos can be chosen at once. Chosen photos appear as small thumbnails, each with an x to remove it before saving. The first photo is the one shown first on the File Screen and in the File List.
  - c. Textbox for the file name. Textbox label is named "Subject File Name"
  - d. Photo Date field, "Date of Photo" — auto-filled from the first photo's metadata when available, once photos are selected. Each photo keeps its own date. If any photo has no date (denied Photos access, or a camera that doesn't record it), a date field appears (today's date by default), and the date shown there is used for those photos.
  - e. Textbox for user field notes with its title is named "Field Notes"
  - f. Textbox for initial notes and plans for the user's illustration project with its title named "Illustration Project Notes"
- **User actions & resulting behavior:**
  - a. Cancel button in the top left corner returns to whichever screen Add File was opened from
  - b. Text label located top center, named "Add File"
  - c. Save button in the top right corner saves the file. Disabled until at least one photo and a file name are provided.
  - d. "Add Photos" / "Add More Photos" button chooses photos; the x on a thumbnail removes that photo
  - e. "Record Photo Location" link takes the user to the map page
  - f. Once the user has saved a pinned location from the Photo Location Selection Screen, the map and pin appear here in the Add File screen, with an "Edit Location" link underneath to change it (consistent with File Screen)
  - g. Textbox for the file name, with label "Subject File Name"
  - h. Photo Date field, "Date of Photo" — auto-fills when available from Photos metadata; otherwise the user enters the date
  - i. Textbox for user field notes, with label "Field Notes"
  - j. Textbox for initial notes and plans for the user's illustration project, with label "Illustration Project Notes"

#### Screen: Edit Home
- **Entry points:** User clicks the gear sign in the top right corner of the Home screen
- **Exit points:** '<' icon in the top left corner returns to the previous screen
- **UI elements:** Large button in the center, named "Change Background." This takes the user to the Photos app to select a background photo, which becomes the new Home screen background. The previous background image is deleted from storage when replaced.
- **User actions & resulting behavior:** See above.

#### Screen: Photo Location Selection
- **Entry points:** "Record Photo Location" link from Add File screen, or "Edit Location" link from the File Screen
- **Exit points:**
  - a. Cancel button in the top left corner returns to the previous screen without saving
  - b. Done button in the top right corner saves the pin and returns to the previous screen
- **UI elements:**
  - Textbox, "Search for a place"
  - iOS map which enables the user to pin their photo location (pinch to zoom, drag to pan)
  - Map and Satellite buttons on the bottom to change the map view
- **User actions & resulting behavior:**
  - Search textbox: user enters a place name; the map moves to that vicinity (doesn't drop a pin — the user still taps to place it)
  - Tapping the map drops or moves the pin
  - Map and Satellite buttons change the map style

### 5. Data Model
- **Core entities:** Two entities, saved to local device storage: `SubjectFile` (one per file) and `AlbumPhoto` (one per photo in a file's albums).
- **Properties per entity:**

  *SubjectFile*

  | Property | Type | Required? | Notes |
  |---|---|---|---|
  | name | Text | Yes | The "Subject File Name"; must be unique (case-insensitive) |
  | dateAdded | Date | Yes | When the entry was created in the app (tracked internally; not shown on screen) |
  | latitude / longitude | Location | No | Set by the user pinning a location on the map; absent until they do |
  | locationDescription | Text | No | A short place name (e.g. "Sedona, AZ") looked up from the pinned location |
  | fieldNotes | Text | No | Freeform notes from the field |
  | illustrationNotes | Text | No | Freeform notes and plans for the illustration project |

  *AlbumPhoto*

  | Property | Type | Required? | Notes |
  |---|---|---|---|
  | image | Image | Yes | The full-size photo, copied into the app's own storage |
  | thumbnail | Image | Yes | A small copy (about 400 px) made when the photo is added, so lists scroll smoothly |
  | date | Date | No | Auto-read from the photo's metadata when available; entered manually as a fallback; can be changed later by tapping the date |
  | album | Text | Yes | Which album the photo belongs to: subject photos or illustration photos |
  | position | Number | Yes | The photo's order in its album; the lowest number is the first photo |

- **Relationships between entities:** One `SubjectFile` has many `AlbumPhoto` entries (both albums together). Deleting a file deletes all of its photos.
- **Persistence across launches:** All of the above is stored on-device and persists across app launches and restarts. (The Home screen's background photo is a separate, simpler piece of app-wide settings — not part of these entities — also stored on-device and persisting across launches.)

### 6. Feature Specs

**Feature: Add a Subject File**
- **Inputs:** one or more photos chosen from the Photos app, a photo location chosen from iOS maps, a file name ("Subject File Name"), photo date, field notes, and initial notes and plans for the illustration project.
- **Expected behavior:** the photos are copied into the app's own storage, and the first one becomes the file's first photo. The Save button stays disabled until at least one photo and a file name are provided. After saving, the file appears in the File List in alphabetical order.
- **Edge cases:**
  - Photo has no location: the file saves normally with no location.
  - A photo has no date: the date shown in the Photo Date field (today's date by default) is used for it.
  - Two files with the same name: not allowed. The user sees a "File Exists" warning and must enter a unique name.
  - User cancels: nothing is saved.
- **Error handling:** if metadata can't be read, the file still saves with the photo and notes.

**Feature: Photos Access Permission**
- **Inputs:** the user's response to the system Photos access prompt.
- **Expected behavior:** the app asks for Photos access when it first opens. With access, the date auto-fills from the photo. Without it, the user sees a short explanation of what they'll lose (auto-filled dates) with a link to Settings, and can still continue and add photos — entering the date by hand.
- **Edge cases:** the user taps "Don't Allow," grants limited access, or continues without access.
- **Error handling:** the app does not crash or block adding photos regardless of permission state.

**Feature: View a File and Edit Notes**
- **Inputs:** edits to Field Notes and Illustration Project Notes.
- **Expected behavior:** the File Screen shows the file name, date taken, large photo, map location, and both notes. Note edits save automatically as the user types, so there is no Save button on this screen.
- **Edge cases:** no location recorded shows the message "No location recorded for this photo." No date hides the date line.
- **Error handling:** if the place name can't be looked up, the map still shows the pin without a place name.

**Feature: Delete a File**
- **Inputs:** a swipe on a file in the File List.
- **Expected behavior:** the file and all of its photos are deleted from the device.
- **Edge cases:** deleting the last file returns the list to its empty state ("No Files Yet").
- **Error handling:** a confirmation dialog appears before the delete completes.

**Feature: Change Home Background**
- **Inputs:** a photo chosen from the Photos app via "Change Background."
- **Expected behavior:** the photo becomes the Home screen background, filling the area below the icon bar. The icon bar stays visible for any photo. The choice persists across launches.
- **Edge cases:** photos with any size or aspect ratio, and rotation between portrait and landscape.
- **Error handling:** if the saved image can't be loaded, the Home screen falls back to the default gradient. Old backgrounds are cleaned up automatically when replaced.

**Feature: Photo Albums**
- **Inputs:** one or several photos chosen from the Photos app, either when adding a file (subject photos) or from the File Screen or Photo Album screen (subject or illustration photos).
- **Expected behavior:** each file has two albums, one for subject photos and one for illustration photos. Photos are added to the end of an album in the order chosen and are copied into the app's own storage along with a small thumbnail. The first photo in an album is the one shown on the File Screen (and, for the subject album, in the File List). Each photo keeps its own date, which auto-fills from the photo's metadata when available or can be entered by hand, and can be changed later by tapping the date (in the Photo Album screen or on the File Screen). Photos can be deleted (with confirmation), and any photo can be moved to the front with "Set as First".
- **Edge cases:**
  - The first photo is deleted: the next photo becomes first.
  - The last subject photo is deleted: the File Screen shows "Add Photos" and the File List shows a blank thumbnail.
  - Photos picked without a date: a date field is shown for entry by hand. In Add File, the one date entered applies to all photos in that batch that have none.
  - Many large photos picked at once: they load one at a time, with a progress indicator.
- **Error handling:** if a picked photo can't be read, it is skipped and the rest are still added.

**Feature: Full Photo View and Full Map View**
- **Inputs:** tapping a photo in the Photo Album screen, or the map on the File Screen.
- **Expected behavior:** each opens a full-screen, read-only view with a '<' button to return. Full Photo View lets the user swipe through the album's photos. Full Map View includes the Map/Satellite toggle but the pin can't be moved from there.
- **Edge cases:** none.
- **Error handling:** none needed.

**Feature: Manual Location Pin**
- **Inputs:** a location the user sets by hand on a map.
- **Expected behavior:** the user taps the map to drop a pin at the photo's location; the pin can be moved or edited afterward from either the Add File or File screens.
- **Edge cases:** editing a location after the file is saved.
- **Error handling:** if reverse geocoding fails, the pin still saves — just without a place name.

### 7. Non-Functional Requirements
- **Performance expectations:** File List scrolls smoothly with at least 100 entries; photo import and display stay responsive regardless of source camera's resolution (including large files from non-Apple cameras). The app launches quickly enough to feel instant on supported devices.
- **Offline behavior:** Adding photos, writing notes, and viewing saved files all work fully offline, since they're stored locally. Two features need a connection: the place-name search on the Photo Location Selection Screen, and converting a dropped pin into a readable place name. A pin can still be dropped with no connection — it just won't show a place name until one is available. Map tiles are cached by the system and mostly tolerate brief connectivity gaps.
- **Accessibility (VoiceOver, Dynamic Type):** Pending decision in future enhancements.
- **Localization needs:** The app's own text (button labels, section headers, messages, alerts, and the permission prompts) is available in English and Spanish, and follows the iPhone/iPad's language setting: a device set to Spanish shows Spanish right away, and any other device language shows English. There is no in-app language picker. Dates format automatically for the device's language. User-entered content (file names, notes) is never translated and stays exactly as typed. Additional languages are a future enhancement.

### 8. Testing Expectations

**Unit tests required for:**
- Creating and saving a subject file stores the name, notes, location, and its photos with their dates.
- Files with missing date or location save and reload correctly.
- File List sorts names alphabetically.
- Deleting a file removes it, and its photos, from the store.
- An album returns its photos in order, and Set as First changes which photo is first.
- Home background save returns a filename and the image loads back from it.

**Manual QA checklist**

*Home screen*
- Plus and gear icons are visible and tappable on the default background.
- After changing the background, both icons and the icon bar are still visible and tappable.
- Changing the background several times in a row works each time.
- The layout holds in portrait and landscape.
- The background persists after fully quitting and reopening the app.

*Add File*
- Save is disabled until at least one photo and a name are provided.
- Several photos can be chosen at once; each shows as a thumbnail and can be removed with the x before saving.
- Cancel discards everything entered and returns to the screen Add File was opened from.
- Saving a duplicate name shows the "File Exists" warning.
- With Photos access denied, the date field allows manual entry and the file still saves.

*Location Picker*
- iOS Map characteristics work:
  - a. pinch in or out to zoom in/out, slide to move direction
  - b. Search brings up the correct location
  - c. Map and Satellite buttons change to the correct views
- Done button saves the pin placement as seen in the File screen
- Cancel button returns to the previous screen without saving

*File List and File Screen*
- Files appear in alphabetical order with the correct thumbnails.
- Swipe to delete removes the file. A confirmation message appears before the delete completes.
- The '<' button returns to File List, and the Home button returns to Home from both screens.
- Edited notes and location are still there after leaving the screen and after quitting the app.
- A photo (original or illustration) with no date shows a date field, and a manually entered date is still there after leaving the screen and after quitting the app.

*Photo Album*
- Tapping the first photo or the "Photo Album" link opens the album, and the count in the link matches the number of photos.
- The plus sign adds several photos at once, in the order chosen, with a progress indicator while they load.
- Tapping a thumbnail opens Full Photo View at that photo, and swiping left or right moves through the album's photos.
- Swiping left shows a confirmation before deleting. Deleting the first photo makes the next photo first.
- "Set as First" makes the chosen photo the one shown on the File Screen (and in the File List, for subject photos).
- Tapping a photo's date opens a calendar, and the chosen date is saved and shown on the File Screen as well.
- Photos and their dates are still there after quitting and reopening the app.
- The subject album and the illustration album behave the same way.

*Permissions*
- First launch shows the Photos access prompt.
- With access denied, adding a photo still works and nothing crashes.

*Language*
- With the device set to Spanish, all labels, alerts, messages, and permission prompts appear in Spanish, and dates appear in Spanish format.
- With the device set to English (or any language other than Spanish), they appear in English.
- File names and notes appear exactly as typed in either language.
- Spanish text fits on every screen without being cut off, in portrait and landscape.

*Devices*
- Run on an iPhone and a current iPad, in both orientations.

### 9. Constraints & Preferences
- **Design system / UI style:** Per Apple, Inc. recommendations
- **Code style conventions:** Utilize standard Xcode convention to allow ease of code review.
- **What the agent should ask about vs. decide independently:**
  - a. Let me know if anything is unclear
  - b. Allow agent to make recommendations for better design.
