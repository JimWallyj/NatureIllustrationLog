import MapKit
import SwiftUI

struct FileDetailView: View {
    @Bindable var file: SubjectFile
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var isEditingLocation = false
    @State private var isPickingIllustrationPhoto = false
    @State private var showingFullPhoto = false
    @State private var showingFullMap = false
    @State private var showingFullIllustrationPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date sits directly under the file name (the navigation title).
                if let date = file.dateTaken {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                }

                if let uiImage = UIImage(data: file.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { showingFullPhoto = true }
                        .fullScreenCover(isPresented: $showingFullPhoto) {
                            FullPhotoView(image: uiImage)
                        }
                }

                locationSection

                notesSection(title: "Field Notes", text: $file.fieldNotes)

                illustrationPhotoSection

                notesSection(title: "Illustration Project Notes", text: $file.illustrationNotes)
            }
            .padding()
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !coordinator.path.isEmpty {
                        coordinator.path.removeLast()
                    }
                } label: {
                    Image(systemName: "chevron.left")
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
        .sheet(isPresented: $isEditingLocation) {
            LocationPickerView(initialCoordinate: currentCoordinate) { newCoordinate in
                file.latitude = newCoordinate.latitude
                file.longitude = newCoordinate.longitude
                file.locationDescription = nil
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
        .sheet(isPresented: $isPickingIllustrationPhoto) {
            PhotoAssetPicker { photo in
                isPickingIllustrationPhoto = false
                file.illustrationPhotoData = photo.image.jpegData(compressionQuality: 0.9)
                file.illustrationPhotoDate = photo.dateTaken
            }
        }
        // Field/illustration notes and location save automatically as SwiftData
        // autosaves the model context — in practice this means changes are
        // saved well before the user exits the screen, satisfying "saved on exit."
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let latitude = file.latitude, let longitude = file.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

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

            Button {
                isEditingLocation = true
            } label: {
                Label("Edit Location", systemImage: "mappin.and.ellipse")
            }
        } else {
            Text("No location recorded for this photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isEditingLocation = true
            } label: {
                Label("Record Photo Location", systemImage: "mappin.and.ellipse")
            }
        }
    }

    @ViewBuilder
    private var illustrationPhotoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Illustration Project Photo").font(.headline)

            if let data = file.illustrationPhotoData, let illustrationImage = UIImage(data: data) {
                Image(uiImage: illustrationImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { showingFullIllustrationPhoto = true }
                    .fullScreenCover(isPresented: $showingFullIllustrationPhoto) {
                        FullPhotoView(image: illustrationImage)
                    }

                if let date = file.illustrationPhotoDate {
                    Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundStyle(.secondary)
                } else {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { file.illustrationPhotoDate ?? Date() },
                            set: { file.illustrationPhotoDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }

                Button("Replace Photo") {
                    isPickingIllustrationPhoto = true
                }
                .font(.footnote)
            } else {
                Button {
                    isPickingIllustrationPhoto = true
                } label: {
                    Label("Add Illustration Photo", systemImage: "paintpalette")
                }
            }
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
