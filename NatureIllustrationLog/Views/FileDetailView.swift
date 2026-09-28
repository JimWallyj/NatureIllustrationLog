import MapKit
import SwiftUI

struct FileDetailView: View {
    @Bindable var file: SubjectFile
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let uiImage = UIImage(data: file.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let date = file.dateTaken {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }

                locationSection

                notesSection(title: "Field Notes", text: $file.fieldNotes)
                notesSection(title: "Illustration Project Notes", text: $file.illustrationNotes)
            }
            .padding()
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button("File List") {
                    if !coordinator.path.isEmpty {
                        coordinator.path.removeLast()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.goHome()
                } label: {
                    Image(systemName: "house")
                }
            }
        }
        // Field/illustration notes save automatically as the user types —
        // SwiftData autosaves changes to the model context, so no separate
        // Save button is needed on this screen.
    }

    @ViewBuilder
    private var locationSection: some View {
        if let latitude = file.latitude, let longitude = file.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            Map(initialPosition: .region(
                MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            )) {
                Marker(file.name, coordinate: coordinate)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let description = file.locationDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No location data available for this photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func notesSection(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            TextEditor(text: text)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }
}
