import UIKit

/// Mac only: "Save to a Folder…" — shows the standard Mac panel for choosing a
/// folder (any folder, including iCloud Drive) and saves copies of the transfer
/// files there. The Mac share menu has no "Save to Files", so this fills that gap.
@MainActor
enum FolderExporter {
    /// Kept alive while the panel is open (the picker holds its delegate weakly).
    private static var activeDelegate: Delegate?

    /// Presents the folder panel. `onFinish(true)` when the files were saved,
    /// `onFinish(false)` when the user cancelled or nothing could be shown.
    static func present(urls: [URL], onFinish: @escaping (Bool) -> Void) {
        guard let presenter = topViewController() else {
            onFinish(false)
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        let delegate = Delegate { saved in
            activeDelegate = nil
            onFinish(saved)
        }
        activeDelegate = delegate
        picker.delegate = delegate
        presenter.present(picker, animated: true)
    }

    /// The front-most view controller of the active window.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first,
              var top = window.rootViewController else { return nil }
        while let next = top.presentedViewController {
            top = next
        }
        return top
    }

    private final class Delegate: NSObject, UIDocumentPickerDelegate {
        let finish: (Bool) -> Void
        init(finish: @escaping (Bool) -> Void) { self.finish = finish }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(false)
        }
    }
}
