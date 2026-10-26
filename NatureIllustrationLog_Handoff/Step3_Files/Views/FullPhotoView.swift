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
            if photo.imageData == nil, let image {
                ZoomableImageView(image: image)
                    .overlay(alignment: .bottom) {
                        OnMacNote()
                            .padding(.bottom, 40)
                    }
            } else if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            if image == nil {
                // Placeholder (offloaded to the Mac): only the thumbnail is here.
                image = photo.imageData.flatMap { UIImage(data: $0) }
                    ?? UIImage(data: photo.thumbnailData)
            }
        }
        .onDisappear {
            image = nil
        }
    }
}

/// A photo that can be zoomed — pinch (trackpad or touch screen) or
/// double-tap / double-click — and dragged around while zoomed. Double-tap /
/// double-click again to return to the whole photo. Built on a scroll view,
/// like Apple's Photos app, so swiping to the next photo still works when the
/// photo isn't zoomed in.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView(image: image)
    }

    func updateUIView(_ uiView: ZoomingScrollView, context: Context) {
        if uiView.imageView.image !== image {
            uiView.imageView.image = image
            uiView.setZoomScale(1, animated: false)
        }
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()

    init(image: UIImage) {
        super.init(frame: .zero)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 6
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // When not zoomed, the photo fills the screen (or window) and follows
        // its size as the Mac window is resized or the iPhone is rotated.
        if zoomScale == 1 {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1 {
            setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let scale: CGFloat = 3
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            let area = CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            zoom(to: area, animated: true)
        }
    }
}
