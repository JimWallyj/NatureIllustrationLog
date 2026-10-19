import CoreLocation
import MapKit
import Photos
import SwiftData
import SwiftUI

struct AddFileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SubjectFile.name) private var existingFiles: [SubjectFile]

    @State private var name = ""
    @State private var fieldNotes = ""
    @State private var illustrationNotes = ""
    @State private var photos: [PickedPhoto] = []
    @State private var manualDate = Date()
    @State private var photoCoordinate: CLLocationCoordinate2D?
    @State private var locationDescription: String?
    @State private var isPickingPhotos = false
    @State private var isImporting = false
    @State private var isPickingLocation = false
    @State private var showingDuplicateNameAlert = false
    @State private var showingPhotoAccessExplainer = false

    var body: some View {
        NavigationStack {
            Form {
                photosSection
                dateSection
                locationSection

                Section("Subject File Name") {
                    TextField("Name", text: $name)
                }

                Section("Field Notes") {
                    TextEditor(text: $fieldNotes).frame(minHeight: 80)
                }

                Section("Illustration Project Notes") {
                    TextEditor(text: $illustrationNotes).frame(minHeight: 80)
                }
            }
            .navigationTitle("Add File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { attemptSave() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photos.isEmpty)
                }
            }
            .overlay {
                if isImporting {
                    ImportingOverlay()
                }
            }
            .sheet(isPresented: $isPickingPhotos) {
                PhotoAssetPicker(
                    selectionLimit: 0,
                    onSelectionDone: {
                        isPickingPhotos = false
                        isImporting = true
                    },
                    onPick: { picked in
                        photos.append(contentsOf: picked)
                        isImporting = false
                    }
                )
            }
            .sheet(isPresented: $isPickingLocation) {
                LocationPickerView(initialCoordinate: photoCoordinate) { coordinate in
                    photoCoordinate = coordinate
                    locationDescription = nil
                    Task {
                        let description = await reverseGeocode(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                        if photoCoordinate?.latitude == coordinate.latitude,
                           photoCoordinate?.longitude == coordinate.longitude {
                            locationDescription = description
                        }
                    }
                }
            }
            .alert("File Exists", isPresented: $showingDuplicateNameAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A file named \"\(name.trimmingCharacters(in: .whitespacesAndNewlines))\" already exists. Please choose a unique name.")
            }
            .alert("Photo Access Not Available", isPresented: $showingPhotoAccessExplainer) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Continue Anyway") {
                    isPickingPhotos = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Without Photos access, the date taken can't be filled in automatically — you can still add a photo and enter the date by hand.")
            }
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
        Section("Photos") {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            thumbnail(for: photo)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                openPhotoPicker()
            } label: {
                if photos.isEmpty {
                    Label("Add Photos", systemImage: "camera")
                } else {
                    Label("Add More Photos", systemImage: "camera")
                }
            }
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        if let first = photos.first {
            Section("Photo Date") {
                if let date = first.dateTaken {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }

                // Photos with no date of their own (denied Photos access, or a
                // source that doesn't record one) get the date entered here.
                if photos.contains(where: { $0.dateTaken == nil }) {
                    DatePicker("Date Taken", selection: $manualDate, displayedComponents: .date)
                    Text("Photos without a date use this date.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Photo Location") {
            if let coordinate = photoCoordinate {
                Map(initialPosition: .region(
                    MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                )) {
                    Marker("Photo Location", coordinate: coordinate)
                }
                .id("\(coordinate.latitude),\(coordinate.longitude)")
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)
                .padding(.top, 4)

                if let locationDescription {
                    Text(locationDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isPickingLocation = true
                } label: {
                    Label("Edit Location", systemImage: "mappin.and.ellipse")
                }
            } else {
                Button {
                    isPickingLocation = true
                } label: {
                    Label("Record Photo Location", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    private func thumbnail(for photo: PickedPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: photo.thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                photos.removeAll { $0.id == photo.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .padding(4)
        }
    }

    // MARK: - Actions

    private func openPhotoPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .denied || status == .restricted {
            showingPhotoAccessExplainer = true
        } else {
            isPickingPhotos = true
        }
    }

    private func attemptSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDuplicate = existingFiles.contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
        if isDuplicate {
            showingDuplicateNameAlert = true
            return
        }
        save(trimmedName: trimmedName)
    }

    private func save(trimmedName: String) {
        guard !photos.isEmpty else { return }

        let file = SubjectFile(
            name: trimmedName,
            latitude: photoCoordinate?.latitude,
            longitude: photoCoordinate?.longitude,
            locationDescription: locationDescription,
            fieldNotes: fieldNotes,
            illustrationNotes: illustrationNotes
        )
        modelContext.insert(file)

        for (index, photo) in photos.enumerated() {
            let albumPhoto = AlbumPhoto(
                imageData: photo.data,
                thumbnailData: photo.thumbnailData,
                date: photo.dateTaken ?? manualDate,
                kind: .subject,
                sortIndex: index
            )
            modelContext.insert(albumPhoto)
            albumPhoto.file = file
        }

        dismiss()
    }
}
