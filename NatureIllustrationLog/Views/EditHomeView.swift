import SwiftUI

struct EditHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeBackgroundFilename") private var backgroundFilename: String = ""
    @State private var isPickingPhoto = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Button {
                    isPickingPhoto = true
                } label: {
                    Text("Change Background")
                        .font(.title3.bold())
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .navigationTitle("Edit Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "house")
                    }
                }
            }
            .sheet(isPresented: $isPickingPhoto) {
                PhotoAssetPicker { photo in
                    isPickingPhoto = false
                    if let filename = HomeBackgroundStore.save(photo.image) {
                        backgroundFilename = filename
                    }
                }
            }
        }
    }
}
