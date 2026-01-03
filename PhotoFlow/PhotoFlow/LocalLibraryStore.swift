import PhotosUI
import SwiftUI
import UIKit

final class LocalLibraryStore: ObservableObject {
    struct Item: Identifiable, Codable, Equatable {
        let id: String
        let photoPath: String
        let thumbPath: String
        let createdAt: Date
    }

    @Published private(set) var items: [Item] = []

    private let fileManager = FileManager.default
    private let photosFolderName = "Photos"
    private let thumbsFolderName = "Thumbs"
    private let catalogFileName = "catalog.json"

    init() {
        loadCatalog()
    }

    func importItems(_ selections: [PhotosPickerItem]) async {
        var newItems: [Item] = []
        for selection in selections {
            guard let data = try? await selection.loadTransferable(type: Data.self) else { continue }
            guard let image = UIImage(data: data) else { continue }

            let id = UUID().uuidString
            let photoURL = photosDirectory().appendingPathComponent("\(id).jpg")
            let thumbURL = thumbsDirectory().appendingPathComponent("\(id).jpg")

            guard let photoData = image.jpegData(compressionQuality: 0.92) else { continue }
            do {
                try photoData.write(to: photoURL, options: .atomic)
            } catch {
                continue
            }

            if let thumbImage = makeThumbnail(from: image, targetSize: CGSize(width: 160, height: 240)),
               let thumbData = thumbImage.jpegData(compressionQuality: 0.86) {
                try? thumbData.write(to: thumbURL, options: .atomic)
            }

            newItems.append(Item(id: id,
                                 photoPath: photoURL.path,
                                 thumbPath: thumbURL.path,
                                 createdAt: Date()))
        }

        if !newItems.isEmpty {
            items.append(contentsOf: newItems)
            persistCatalog()
        }
    }

    func image(at path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    func thumbnail(at path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    private func applicationSupportDirectory() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("SampleMate", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func photosDirectory() -> URL {
        let url = applicationSupportDirectory().appendingPathComponent(photosFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func thumbsDirectory() -> URL {
        let url = applicationSupportDirectory().appendingPathComponent(thumbsFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func catalogURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(catalogFileName)
    }

    private func loadCatalog() {
        let url = catalogURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Item].self, from: data) else {
            items = []
            return
        }
        items = decoded.filter { fileManager.fileExists(atPath: $0.photoPath) }
    }

    private func persistCatalog() {
        let url = catalogURL()
        let data = try? JSONEncoder().encode(items)
        try? data?.write(to: url, options: .atomic)
    }

    private func makeThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage? {
        let ratio = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
