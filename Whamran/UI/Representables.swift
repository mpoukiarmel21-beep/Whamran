import SwiftUI
import PhotosUI
import Photos

// MARK: - Pont PHPicker
enum PickedMedia {
    case image(Data)
    case video(URL)
}

struct MediaPicker: UIViewControllerRepresentable {
    let filter: PHPickerFilter
    let onPicked: (PickedMedia?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = filter
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (PickedMedia?) -> Void

        init(onPicked: @escaping (PickedMedia?) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first else { onPicked(nil); return }

            if item.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                item.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, _ in
                    guard let url else { self.onPicked(nil); return }
                    let copy = Self.copyToTemp(url)
                    self.onPicked(.video(copy))
                }
            } else {
                item.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, _ in
                    guard let url, let data = try? Data(contentsOf: url) else { self.onPicked(nil); return }
                    self.onPicked(.image(data))
                }
            }
        }

        static func copyToTemp(_ url: URL) -> URL {
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
            return dest
        }
    }
}

// MARK: - Sauvegarde dans Photos
enum PhotoSaver {
    static func save(urls: [URL]) {
        let ph = urls
        PHPhotoLibrary.shared().performChanges {
            for url in ph {
                let req = PHAssetCreationRequest.forAsset()
                if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                    req.addResource(with: .video, fileURL: url, options: nil)
                } else {
                    req.addResource(with: .photo, fileURL: url, options: nil)
                }
            }
        } completionHandler: { _, _ in }
    }
}
