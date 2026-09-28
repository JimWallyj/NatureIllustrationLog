import SwiftData
import SwiftUI

struct AddFileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var fieldNotes = ""
    @State private var illustrationNotes = ""
    @State private var pickedPhoto: PickedPhoto?
    @State private var locationDescription: String?
    @State private var isPickingPhoto = false

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
                    if let lat = photo.latitude, let lon = photo.longitude {
                        Task {
                            locationDescription = await reverseGeocode(latitude: lat, longitude: lon)
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
            latitude: photo.latitude,
            longitude: photo.longitude,
            locationDescription: locationDescription,
            fieldNotes: fieldNotes,
            illustrationNotes: illustrationNotes
        )
        modelContext.insert(file)
        dismiss()
    }
}
