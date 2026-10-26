import MapKit
import SwiftData
import SwiftUI

struct FileDetailView: View {
    @Bindable var file: SubjectFile
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var photoSpaceNeeded: Int64?
    @State private var isPickingFiles = false
    @State private var filesKind: AlbumKind = .subject
    @State private var isEditingLocation = false
    @State private var showingFullMap = false
    @State private var pickerTarget: AlbumKind?
    @State private var presentedAlbum: AlbumKind?
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if file.replacedDate != nil {
                    Label("Recently Replaced: an older version kept for 30 days. Use Restore or Delete Now at the bottom of the screen.", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if file.isReadOnly {
                    Label("Read-Only: shared with you. You can view this file but not change it.", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                subjectPhotoSection

                locationSection

                notesSection(title: "Field Notes", text: $file.fieldNotes)

                illustrationPhotoSection

                notesSection(title: "Illustration Project Notes", text: $file.illustrationNotes)
            }
            .padding()
            // On a wide Mac window: one centered column, so notes don't stretch.
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Not shown when viewing an older version from Recently Replaced (opened from Settings).
                if file.replacedDate == nil {
                    Button {
                        coordinator.goHome()
                    } label: {
                        Image(systemName: "house")
                    }
                }
            }
        }
        .locationPickerCover(isPresented: $isEditingLocation) {
            LocationPickerView(initialCoordinate: currentCoordinate) { newCoordinate in
                file.latitude = newCoordinate.latitude
                file.longitude = newCoordinate.longitude
                file.locationDescription = nil
                file.touch()
                Task {
                    let description = await reverseGeocode(
                        latitude: newCoordinate.latitude,
                        longitude: newCoordinate.longitude
                    )
                    if file.latitude == newCoordinate.latitude,
                       file.longitude == newCoordinate.longitude {
                        file.locationDescription = description
                    }
                }
            }
        }
        .sheet(item: $pickerTarget) { kind in
            PhotoAssetPicker(
                selectionLimit: 0,
                onSelectionDone: {
                    pickerTarget = nil
                    isImporting = true
                },
                onPick: { picked in
                    isImporting = false
                    if StorageCheck.hasRoom(forBytes: StorageCheck.bytes(of: picked)) {
                        file.appendPhotos(picked, kind: kind, in: modelContext)
                    } else {
                        photoSpaceNeeded = StorageCheck.bytes(of: picked)
                    }
                }
            )
        }
        .imageFileImporter(
            isPresented: $isPickingFiles,
            onLoading: { isImporting = true },
            onLoaded: { picked in
                isImporting = false
                if StorageCheck.hasRoom(forBytes: StorageCheck.bytes(of: picked)) {
                    file.appendPhotos(picked, kind: filesKind, in: modelContext)
                } else {
                    photoSpaceNeeded = StorageCheck.bytes(of: picked)
                }
            }
        )
        .notEnoughSpaceForPhotosAlert(bytesNeeded: $photoSpaceNeeded)
        .fullScreenCover(item: $presentedAlbum) { kind in
            AlbumView(file: file, kind: kind)
        }
        .overlay {
            if isImporting {
                ImportingOverlay()
            }
        }
        // Record when the notes last changed (used by transfers).
        .onChange(of: file.fieldNotes) { file.touch() }
        .onChange(of: file.illustrationNotes) { file.touch() }
        // Notes, location, dates, and photos save automatically as SwiftData
        // autosaves the model context — in practice this means changes are
        // saved well before the user exits the screen, satisfying "saved on exit."
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let latitude = file.latitude, let longitude = file.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Photo sections

    /// The first subject photo, with its date above it. Tap the photo (or the
    /// album link under it) to open the whole album.
    @ViewBuilder
    private var subjectPhotoSection: some View {
        if let cover = file.coverPhoto {
            VStack(alignment: .leading, spacing: 10) {
                PhotoDateRow(photo: cover, isEditable: !file.isLocked)

                CoverPhotoView(photo: cover)
                    .onTapGesture { presentedAlbum = .subject }

                albumLink(for: .subject)
            }
        } else if file.isLocked {
            Text("No photos")
                .foregroundStyle(.secondary)
        } else {
            AddPhotosMenu(
                onPhotosLibrary: { pickerTarget = .subject },
                onFiles: {
                    filesKind = .subject
                    isPickingFiles = true
                }
            ) {
                Label("Add Photos", systemImage: "camera")
            }
        }
    }

    /// The first illustration photo, just above the Illustration Project Notes.
    private var illustrationPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Illustration Project Photos").font(.headline)

            if let cover = file.illustrationCoverPhoto {
                CoverPhotoView(photo: cover)
                    .onTapGesture { presentedAlbum = .illustration }

                PhotoDateRow(photo: cover, isEditable: !file.isLocked)

                albumLink(for: .illustration)
            } else if file.isLocked {
                Text("No photos")
                    .foregroundStyle(.secondary)
            } else {
                AddPhotosMenu(
                    onPhotosLibrary: { pickerTarget = .illustration },
                    onFiles: {
                        filesKind = .illustration
                        isPickingFiles = true
                    }
                ) {
                    Label("Add Illustration Photos", systemImage: "paintpalette")
                }
            }
        }
    }

    private func albumLink(for kind: AlbumKind) -> some View {
        Button {
            presentedAlbum = kind
        } label: {
            Label("Photo Album (\(file.album(kind).count))", systemImage: "photo.on.rectangle")
        }
        .font(.footnote)
    }

    // MARK: - Location

    @ViewBuilder
    private var locationSection: some View {
        if let coordinate = currentCoordinate {
            Map(initialPosition: .region(
                MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            )) {
                Marker(file.name, coordinate: coordinate)
            }
            .id("\(coordinate.latitude),\(coordinate.longitude)")
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { showingFullMap = true }
            .fullScreenCover(isPresented: $showingFullMap) {
                FullMapView(coordinate: coordinate, title: file.name)
            }

            if let description = file.locationDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !file.isLocked {
                Button {
                    isEditingLocation = true
                } label: {
                    Label("Edit Location", systemImage: "mappin.and.ellipse")
                }
            }
        } else {
            Text("No location recorded for this photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !file.isLocked {
                Button {
                    isEditingLocation = true
                } label: {
                    Label("Record Photo Location", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    private func notesSection(title: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if file.isLocked {
                // Shown exactly as typed; can be selected and copied, not changed.
                Text(text.wrappedValue)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .padding(8)
                    .textSelection(.enabled)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            } else {
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
        }
    }
}
