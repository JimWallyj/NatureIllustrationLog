Agent Build Specification
Nature Illustration Log and Locator

1. Overview
Purpose / problem statement:  The Nature Illustration Log and Locator app provides a simple tool for nature illustrators to capture a source photo and basic details in the field  on their device. The resulting repository should prove useful to the nature illustrator for their next illustration project.  The illustrator user will import their nature subject from the Photos app.  The file entries in this Nature Illustration Log & Locator app will include the photo, date taken, user field notes and initial notes and plans that support the user’s illustration  project.  The illustration project is not part of this SwiftUI program.  The SwiftUI program merely stores a picture of the nature subject and related user notes.
Target user: Nature illustrators
Success criteria (what "done" looks like):  An interface for storing nature subject photos and notes in files stored on the local device.

2. Platform & Environment
iOS version floor: 26.3
Devices supported (iPhone / iPad / Universal): iPhone 17, iPad 4th generation
Orientation support: Portrait or Landscape
Xcode / Swift version: 26.3
SwiftUI vs. UIKit interop needs:

3. Architecture
Pattern (e.g., MVVM):
Data flow (@Observable, Combine, async/await):
Persistence (SwiftData, Core Data, UserDefaults, none): SwiftData
Networking layer (REST/GraphQL, auth scheme), if any:
Third-party dependencies (SPM packages) — allowed / forbidden: Forbidden

4. Screens & Flows

Screen: Home View
Entry points (how user arrives here): Click on icon from the device.
Exit points (where user can go from here): File List Screen, Add File Screen, Edit Home Screen.
UI elements: 
a. Screen Background = Gradient graphic at the start which can be updated by the user with a nature photo from their photo app files.
b. Plus sign (+) in the top left corner to open Add File screen
c. Gear sign in the top right corner to open Edit Home Screen
d. Big button in the center to open File Screen. Button is named, “Illustration Projects”
States: empty / loading / error / populated
Data displayed & source:
User actions & resulting behavior: See ‘a’ through ‘d’, above

Screen: File List
Entry points (how user arrives here): Clicks the big button in the center of the Home Screen (labeled, “Illustration Projects”) to open File Screen
Exit points (where user can go from here): File Screen and Home Screen
UI elements:
a. A list of the files that have already been added. 
  i. File names listed in alphabetical order.
  ii. Thumbnail photo next to the file name that matches the photo for this nature subject. 
b. Plus sign in the top left corner to open Add File screen
c. Home button in the top right corner to return to the Home Screen
Data displayed & source:
a. A list of the files that have already been added. 
  i. File names listed in alphabetical order.
  ii. Thumbnail photo next to the file name that matches the photo for this nature subject.
User actions & resulting behavior:
a Click on a file name or thumbnail photo to open  File Screen
b. Ability to swipe on a file name to delete the file.
c. Click on the Home button to return to the Home Screen

Screen: File View
Entry points (how user arrives here): User clicks on a specific file name or thumbnail photo from the File List Screen
Exit points (where user can go from here): 
a. ‘<‘ sign in the top left corner to return to the previous screen. 
b. Home button in the top right corner to return to the Home Screen
c. Edit Location link takes the user to the Photo Location Selection screen.
UI elements: See ‘a’ through ‘c’, above 
Data displayed & source:
a. File Name = located top center
b. Date in which the photo was taken = located just below the File Name
c. Large photo of the photo the user selected for this nature subject
d. Location of photo pinned in Apple maps view 
e. Under location photo map view resides a link to Photo Location Selection Screen, named “Edit Location”
f.  Editable text box with user field notes 
g. Editable text box with initial notes and plans for the user’s  illustration  project.
User actions & resulting behavior: 
a. ‘<‘ sign in the top left corner to return to the File List Screen
b. Home button in the top right corner to return to the Home Screen
c. Ability to edit text fields and location.  Changes saved upon exit of this screen.

Screen: Add File
Entry points (how user arrives here): User clicks the plus sign in the Home Screen or in the File List Screen.
Exit points (where user can go from here):
a. Home Cancel button in the top right left corner to return to the Home previous Screen
b. Save button located top right to save the file
c. Link named, “Record Photo Location” which takes user to the Location Picker screen to select the photo for this file.
UI elements:
a. See ‘a’ through 'c’, above. 
b. Textbox for user to add the file name’. Label is “Subject File Name”
c. Photo Date field, “Date of Photo”
d. Textbox for user to add user field notes
e. Textbox for user to add initial notes and plans for the user’s  illustration  project
Data displayed & source:  See above
User actions & resulting behavior:  
a. Cancel button in the top left corner to return to the Home Screen
b. Text label located top center, named, “Add File”
c. Save button in the top right corner 
d. Record Photo Location link to take user to the map page
e. Once the user has saved the pinned location from the Photo Location Selection Screen the map and pinned location appears here in the Add File screen. And under this map view a link to Photo Location Selection Screen, named “Edit Location” (consistent with File Screen).
f. Textbox for user to add the file name, add a label, “Subject File Name”
g. Photo Date field, “Date of Photo”: user enters this date
h. Textbox for user to add user field notes, “Field Notes”
i. Textbox for user to add initial notes and plans for the user’s illustration  project, “Illustration Project Notes”

Screen: Edit Home
Entry points (how user arrives here): User clicks the gear sign in the top right corner of the Home screen
Exit points (where user can go from here): ‘<‘ icon in the top left corner to return to the previous screen
UI elements:  Large button in the center, named “Change Background”. This takes the user to the Photos app to select a background photo. Add the selected photo as a new background photo on the Home screen.
Data displayed & source:
User actions & resulting behavior: See above.

Screen: Photo Location Selection
Entry points (how user arrives here): Record Photo Location link from Add File screen or Edit Location link from the File Screen.
Exit points (where user can go from here):
a. Cancel button in the top left corner to return to the previous screen without saving the file
b. Done button in the top right corner to save file and return to the previous screen
UI elements:
Textbox, “Search for a place”
iOS map which enables the user to pin their photo location.
Map and Satellite buttons on the bottom to change the map view.
Data displayed & source: Map view from Apple iOS
User actions & resulting behavior: See above.
Search textbox: User enters a location.  Map changes to vicinity of searched location
Map and Satellite buttons change the map view

5. Data Model
- Core entities: Save files to local device
Properties per entity: 

name = Text, Required, The "Subject File Name"; must be unique (case-insensitive)
photo = Image, Required, Copied into the app's own storage at Add time
dateTaken = Date, Not Required, Entered by user
dateAdded = Date, Required, When the entry was created in the app (not shown on screen today)
latitude / longitude = Location, Not Required, Set by the user pinning a location on the map; absent until they do
locationDescription = Text, Not Required, A short place name (e.g. "Sedona, AZ") looked up from the pinned location
fieldNotes = Text, Not Required, Freeform notes from the field
illustrationNotes = Text, Not Required, Freeform notes and plans for the illustration project

Relationships between entities:  Not applicable — the app has a single entity with no relationships to other data.
Persistence across launches: All of the above is stored on-device and persists across app launches and restarts. (The Home screen's background photo is a separate, simpler piece of app-wide settings — not part of this entity — also stored on-device and persisting across launches.)

6. Feature Specs

Feature: Add a Subject File
Inputs: a photo chosen from the Photos app, a photo location chosen from iOS maps, a file name ("Subject File Name"), photo date, field notes, and initial notes and plans for the illustration project.
Expected behavior: the photo is copied into the app's own storage. The Save button stays disabled until both a photo and a file name are provided. After saving, the file appears in the File List in alphabetical order.
Edge cases:
  - Photo has no location: the file saves normally with no location.
  - Photo has no date: the file saves normally with no date.
  - Two files with the same name: currently allowed. Do not allow files with same name. Need to warn user File Exists and allow the user to input a unique file name.
  - User cancels: nothing is saved.
Error handling: if metadata can't be read, the file still saves with the photo and notes.

Feature: Photos Access Permission
Inputs: the user's response to the system Photos access prompt.
Expected behavior: the app asks for Photos access when it first opens. Without it, photos cannot be added.
Edge cases: the user taps "Don't Allow" or grants limited access.
Error handling: The app shows a short explanation when access is denied, with a link to Settings.

Feature: View a File and Edit Notes
Inputs: edits to Field Notes and Illustration Project Notes.
Expected behavior: the File Screen shows the file name, date taken, large photo, map location, and both notes. Note edits save automatically as the user types, so there is no Save button on this screen.
Edge cases: no location data shows the message "No location data available for this photo." No date hides the date line.
Error handling: if the place name can't be looked up, the map still shows the pin without a place name.

Feature: Delete a File
Inputs: a swipe on a file in the File List.
Expected behavior: the file and its stored photo are deleted from the device.
Edge cases: deleting the last file returns the list to its empty state ("No Files Yet").
Error handling: Confirmation before deleting. 

Feature: Change Home Background
Inputs: a photo chosen from the Photos app via "Change Background".
Expected behavior: the photo becomes the Home screen background, filling the area below the icon bar. The icon bar stays visible for any photo. The choice persists across launches.
Edge cases: photos with any size or aspect ratio, and rotation between portrait and landscape.
Error handling: if the saved image can't be loaded, the Home screen falls back to the default green/brown gradient. Previous background images are not deleted from storage when replaced. Old backgrounds are cleaned up automatically.

Feature: Manual Location Pin
Inputs: a location the user sets by hand on a map.
Expected behavior: the user clicks the pin location.
Edge cases: editing a location after the file is saved.
Error handling: *Undecided. Not built yet.*

7. Non-Functional Requirements
Performance expectations: File List scrolls smoothly with at least 100 entries; photo import and display stay responsive regardless of source camera's resolution (including large files from non-Apple cameras). The app launches quickly enough to feel instant on supported devices.
Offline behavior: Adding photos, writing notes, and viewing saved files all work fully offline, since they're stored locally. Two features need a connection: the place-name search on the Photo Location Selection Screen, and converting a dropped pin into a readable place name. A pin can still be dropped with no connection — it just won't show a place name until one is available. Map tiles are cached by the system and mostly tolerate brief connectivity gaps.
Accessibility (VoiceOver (screen reader), Dynamic Type (larger text sizes)): Pending decision in future enhancements.
Localization needs (language support): Pending decision in future enhancements.


8. Testing Expectations
Unit tests required for:
- Creating and saving a subject file stores the name, photo, notes, date, and location.
- Files with missing date or location save and reload correctly.
- File List sorts names alphabetically.
- Deleting a file removes it from the store.
- Home background save returns a filename and the image loads back from it.

Manual QA checklist

**Home screen**
- Plus and gear icons are visible and tappable on the default background.
- After changing the background, both icons and the icon bar are still visible and tappable.
- Changing the background several times in a row works each time.
- The layout holds in portrait and landscape.
- The background persists after fully quitting and reopening the app.

**Add File**
- Save is disabled until both a photo and a name are provided.
- Cancel discards everything entered.

**Location Picker**
- iOS Map characteristics work
a. pinch in or out to zoom in/out, slide to move direction
b. Search brings up correct location
c. Map and Satellite buttons change to the correct views
- Done button saves the pin placement as seen in the File screen
- Cancel button returns to the previous screen without saving

**File List and File Screen**
- Files appear in alphabetical order with the correct thumbnails.
- Swipe to delete removes the file.  Verification message appears before user confirms delete action.
- The File List button returns to the list, and the Home button returns to Home from both screens.
- Edited notes are still there after leaving the screen and after quitting the app. 

**Permissions**
- First launch shows the Photos access prompt.
- With access denied, adding a photo still works and nothing crashes.

**Devices**
- Run on an iPhone and a current iPad, in both orientations.

9. Constraints & Preferences
Design system / UI style: Per Apple, Inc. recommendations
Code style conventions: Utilize module XCode convention to allow ease of code review.
What the agent should ask about vs. decide independently:
a. Let me know if anything is unclear
b. Allow agent to make recommendations for better design.

