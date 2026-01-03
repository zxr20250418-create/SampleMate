import Combine
import PhotosUI
import SwiftUI
import UIKit

final class LocalLibraryStore: ObservableObject {
    struct LocalLibraryItem: Identifiable, Codable, Equatable {
        let id: String
        let photoPath: String
        let thumbPath: String
        let createdAt: Date
    }

    struct SampleSet: Codable, Identifiable, Equatable {
        let id: String
        var title: String
        var photoIDsOrdered: [String]
        var mainPhotoID: String
        let createdAt: Date
    }

    typealias Item = LocalLibraryItem

    nonisolated let objectWillChange = ObservableObjectPublisher()
    @Published private(set) var items: [LocalLibraryItem] = []
    @Published private(set) var sets: [SampleSet] = []

    private let fileManager = FileManager.default
    private let photosFolderName = "Photos"
    private let thumbsFolderName = "Thumbs"
    private let catalogFileName = "catalog.json"
    private let setsFileName = "sets.json"

    init() {
        Task {
            await loadCatalog()
            await loadSets()
        }
    }

    func importItems(_ selections: [PhotosPickerItem]) async {
        var newItems: [LocalLibraryItem] = []
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

            newItems.append(LocalLibraryItem(id: id,
                                             photoPath: photoURL.path,
                                             thumbPath: thumbURL.path,
                                             createdAt: Date()))
        }

        if !newItems.isEmpty {
            await MainActor.run {
                items.append(contentsOf: newItems)
            }
            await MainActor.run {
                persistCatalog()
            }
        }
    }

    func createSet(title: String, photoIDs: [String]) -> SampleSet {
        let normalized = photoIDs.filter { id in items.contains { $0.id == id } }
        let mainID = normalized.first ?? ""
        let set = SampleSet(id: UUID().uuidString,
                            title: title,
                            photoIDsOrdered: normalized,
                            mainPhotoID: mainID,
                            createdAt: Date())
        Task {
            await MainActor.run {
                sets.append(set)
            }
            await MainActor.run {
                persistSets()
            }
        }
        return set
    }

    func setMainPhoto(setID: String, photoID: String) {
        Task {
            await MainActor.run {
                guard let idx = sets.firstIndex(where: { $0.id == setID }) else { return }
                sets[idx].mainPhotoID = photoID
            }
            await MainActor.run {
                persistSets()
            }
        }
    }

    func deleteSet(setID: String) {
        Task {
            await MainActor.run {
                sets.removeAll { $0.id == setID }
            }
            await MainActor.run {
                persistSets()
            }
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

    private func setsURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(setsFileName)
    }

    private func loadCatalog() async {
        let url = catalogURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LocalLibraryItem].self, from: data) else {
            await MainActor.run {
                items = []
            }
            return
        }
        let filtered = decoded.filter { fileManager.fileExists(atPath: $0.photoPath) }
        await MainActor.run {
            items = filtered
        }
    }

    private func loadSets() async {
        let url = setsURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SampleSet].self, from: data) else {
            await MainActor.run {
                sets = []
            }
            return
        }
        await MainActor.run {
            sets = decoded
        }
    }

    private func persistCatalog() {
        let url = catalogURL()
        let data = try? JSONEncoder().encode(items)
        try? data?.write(to: url, options: .atomic)
    }

    private func persistSets() {
        let url = setsURL()
        let data = try? JSONEncoder().encode(sets)
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
