import SwiftUI

/// Tells a full-screen cover which photo in an album to open first.
struct ViewerItem: Identifiable {
    let id: Int
}

/// Full-screen, read-only viewer for an album's photos. Swipe left or right to
/// move between photos. No editing controls — just the photos and a way back.
struct FullPhotoView: View {
    let photos: [AlbumPhoto]
    @State private var selection: Int
    @Environment(\.dismiss) private var dismiss

    init(photos: [AlbumPhoto], startIndex: Int) {
        self.photos = photos
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    FullPhotoPage(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(Color.black.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

/// One page of the viewer. The full-size photo is only loaded while the page
/// is on screen, so large albums don't fill memory.
private struct FullPhotoPage: View {
    let photo: AlbumPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            if image == nil {
                image = UIImage(data: photo.imageData)
            }
        }
        .onDisappear {
            image = nil
        }
    }
}
