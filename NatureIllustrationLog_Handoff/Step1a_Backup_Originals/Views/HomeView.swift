import SwiftUI
import SwiftData  // Jim added due to error in #Preview = 'modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)'is not available due to missing import of defining module 'SwiftData'

struct HomeView: View {
    @AppStorage("homeBackgroundFilename") private var backgroundFilename: String = ""
    @State private var coordinator = NavigationCoordinator()
    @State private var showingAddFile = false
    @State private var showingEditHome = false

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 0) {
                //backgroundView.ignoresSafeArea()
                //  Opaque icon band - never over laps the background photo

                    HStack {
                        iconButton("plus") { showingAddFile = true }
                        Spacer()
                        iconButton("gearshape") { showingEditHome = true }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                ZStack{
                    backgroundView
                    
                    VStack{
                        Spacer()
                        Button("Illustration Projects") {
                            coordinator.showFileList()
                        }
                        .font(.title2.bold())
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.primary)
                        
                        Spacer()
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .fileList:
                    FileListView()
                }
            }
            .navigationDestination(for: SubjectFile.self) { file in
                FileDetailView(file: file)
            }
            .sheet(isPresented: $showingAddFile) {
                AddFileView()
            }
            .sheet(isPresented: $showingEditHome) {
                EditHomeView()
            }
            .task {
                requestPhotoLibraryAccessIfNeeded()
            }
        }
        .environment(coordinator)
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
            // removed 9/27:
//                .foregroundStyle(.white)
//                .padding()
//                .background(.black.opacity(0.35), in: Circle())
        }
    }
    
//    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
//        Button(action: action) {
//            Image(systemName: systemName)
//                .font(.title2)
//                .padding()
//                .background(.ultraThinMaterial, in: Circle())
//        }
//        .foregroundStyle(.primary)
//    }

    @ViewBuilder
    private var backgroundView: some View {
        if !backgroundFilename.isEmpty,
           let data = try? Data(contentsOf: HomeBackgroundStore.url(for: backgroundFilename)),
           let uiImage = UIImage(data: data) {
            Color.clear
                .overlay{
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .allowsHitTesting(false)
        } else {
            // Default background until the user sets one via Edit Home.
            LinearGradient(
                colors: [.green.opacity(0.6), .brown.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: SubjectFile.self, inMemory: true)
}
