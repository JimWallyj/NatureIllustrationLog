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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .sheet(isPresented: $isPickingPhoto) {
                PhotoAssetPicker(
                    selectionLimit: 1,
                    onSelectionDone: {
                        isPickingPhoto = false
                    },
                    onPick: { picked in
                        guard let photo = picked.first else { return }
                        if let filename = HomeBackgroundStore.replace(photo.data, previousFilename: backgroundFilename) {
                            backgroundFilename = filename
                        }
                    }
                )
            }
        }
    }
}
