import CoreLocation
import SwiftData
import SwiftUI

struct AddFileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var fieldNotes = ""
    @State private var illustrationNotes = ""
    @State private var pickedPhoto: PickedPhoto?
    @State private var photoCoordinate: CLLocationCoordinate2D?
    @State private var locationDescription: String?
    @State private var isPickingPhoto = false
    @State private var isPickingLocation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        isPickingPhoto = true
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

                Section("Photo Location") {
                    Button {
                        isPickingLocation = true
                    } label: {
                        Label("Record Photo Location", systemImage: "mappin.and.ellipse")
                    }

                    if let coordinate = photoCoordinate {
                        Text(locationDescription
                             ?? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                    Button("Save") { save() }
                        .disabled(name.isEmpty || pickedPhoto == nil)
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
                        // Ignore the result if the user has since moved the pin.
                        if photoCoordinate?.latitude == coordinate.latitude,
                           photoCoordinate?.longitude == coordinate.longitude {
                            locationDescription = description
                        }
                    }
                }
            }
        }
    }

    private func save() {
        guard let photo = pickedPhoto,
              let data = photo.image.jpegData(compressionQuality: 0.9) else { return }

        let file = SubjectFile(
            name: name,
            photoData: data,
            dateTaken: photo.dateTaken,
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
