# Nature Illustration Log and Locator — Draft Sections 6 and 8

> Drafted from the current build. Items marked *Decision needed* are places where the app currently does something by default and you may want a different behavior.

## 6. Feature Specs

### Feature: Add a Subject File
- **Inputs:** a photo chosen from the Photos app, a file name ("Subject File Name"), field notes, and initial notes and plans for the illustration project.
- **Expected behavior:** the photo is copied into the app's own storage. The photo's date taken and location are read automatically from its metadata. The Save button stays disabled until both a photo and a file name are provided. After saving, the file appears in the File List in alphabetical order.
- **Edge cases:**
  - Photo has no location data (for example, photos from a standalone camera): the file saves normally with no location.
  - Photo has no date: the file saves normally with no date.
  - Two files with the same name: currently allowed. *Decision needed: allow duplicates, warn, or block?*
  - User cancels: nothing is saved.
- **Error handling:** if metadata can't be read, the file still saves with the photo and notes.

### Feature: Photos Access Permission
- **Inputs:** the user's response to the system Photos access prompt.
- **Expected behavior:** the app asks for Photos access when it first opens. With access, date and location are read from photos. Without it, photos can still be added but without date and location.
- **Edge cases:** the user taps "Don't Allow" or grants limited access.
- **Error handling:** the app does not crash or block adding photos. *Decision needed: should the app show a short explanation when access is denied, with a link to Settings?*

### Feature: View a File and Edit Notes
- **Inputs:** edits to Field Notes and Illustration Project Notes.
- **Expected behavior:** the File Screen shows the file name, date taken, large photo, map location, and both notes. Note edits save automatically as the user types, so there is no Save button on this screen.
- **Edge cases:** no location data shows the message "No location data available for this photo." No date hides the date line.
- **Error handling:** if the place name can't be looked up, the map still shows the pin without a place name.

### Feature: Delete a File
- **Inputs:** a swipe on a file in the File List.
- **Expected behavior:** the file and its stored photo are deleted from the device.
- **Edge cases:** deleting the last file returns the list to its empty state ("No Files Yet").
- **Error handling:** none needed. *Decision needed: currently there is no confirmation before deleting. Add one?*

### Feature: Change Home Background
- **Inputs:** a photo chosen from the Photos app via "Change Background".
- **Expected behavior:** the photo becomes the Home screen background, filling the area below the icon bar. The icon bar stays visible for any photo. The choice persists across launches.
- **Edge cases:** photos with any size or aspect ratio, and rotation between portrait and landscape.
- **Error handling:** if the saved image can't be loaded, the Home screen falls back to the default green/brown gradient. Previous background images are not deleted from storage when replaced. *Decision needed: clean up old backgrounds automatically?*

### Feature: Manual Location Pin (possible future enhancement)
- **Inputs:** a location the user sets by hand on a map.
- **Expected behavior:** for files with no location metadata, the user can drop a pin. Metadata location is used when present, and the user can override it.
- **Edge cases:** editing a location after the file is saved.
- **Error handling:** *Undecided. Not built yet.*

## 8. Testing Expectations

### Unit tests required for
- Creating and saving a subject file stores the name, photo, notes, date, and location.
- Files with missing date or location save and reload correctly.
- File List sorts names alphabetically.
- Deleting a file removes it from the store.
- Home background save returns a filename and the image loads back from it.

### Manual QA checklist
**Home screen**
- Plus and gear icons are visible and tappable on the default background.
- After changing the background, both icons and the icon bar are still visible and tappable.
- Changing the background several times in a row works each time.
- The layout holds in portrait and landscape.
- The background persists after fully quitting and reopening the app.

**Add File**
- Save is disabled until both a photo and a name are provided.
- A photo with location data shows the correct pin and place name on the File Screen.
- A photo without location data shows the no-location message.
- Cancel discards everything entered.

**File List and File Screen**
- Files appear in alphabetical order with the correct thumbnails.
- Swipe to delete removes the file.
- The File List button returns to the list, and the Home button returns to Home from both screens.
- Edited notes are still there after leaving the screen and after quitting the app.

**Permissions**
- First launch shows the Photos access prompt.
- With access denied, adding a photo still works and nothing crashes.

**Devices**
- Run on an iPhone and a current iPad, in both orientations.
