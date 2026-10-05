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
    @State private var pickedPhoto: PickedPhoto?
    @State private var manualDate = Date()
    @State private var photoCoordinate: CLLocationCoordinate2D?
    @State private var locationDescription: String?
    @State private var isPickingPhoto = false
    @State private var isPickingLocation = false
    @State private var showingDuplicateNameAlert = false
    @State private var showingPhotoAccessExplainer = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        openPhotoPicker()
                    } label: {
                        if let uiImage = pickedPhoto?.image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                        } else {
                            Label("Add Photo", systemImage: "camera")
                        }
                    }
                }

                if pickedPhoto != nil {
                    Section("Photo Date") {
                        if let date = pickedPhoto?.dateTaken {
                            Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .foregroundStyle(.secondary)
                        } else {
                            DatePicker("Date Taken", selection: $manualDate, displayedComponents: .date)
                            Text("Photos access isn't available, so enter the date by hand.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

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
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pickedPhoto == nil)
                }
            }
            .sheet(isPresented: $isPickingPhoto) {
                PhotoAssetPicker { photo in
                    pickedPhoto = photo
                    isPickingPhoto = false
                }
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
                    isPickingPhoto = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Without Photos access, the date taken can't be filled in automatically — you can still add a photo and enter the date by hand.")
            }
        }
    }

    private func openPhotoPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .denied || status == .restricted {
            showingPhotoAccessExplainer = true
        } else {
            isPickingPhoto = true
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
        guard let photo = pickedPhoto,
              let data = photo.image.jpegData(compressionQuality: 0.9) else { return }

        let file = SubjectFile(
            name: trimmedName,
            photoData: data,
            dateTaken: photo.dateTaken ?? manualDate,
            latitude: photoCoordinate?.latitude,
            longitude: photoCoordinate?.longitude,
            locationDescription: locationDescription,
            fieldNotes: fieldNotes,
            illustrationNotes: illustrationNotes
        )
        modelContext.insert(file)
        dismiss()
    }
}
