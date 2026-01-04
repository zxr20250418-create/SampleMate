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
        var coverPhotoID: String?
        var categoryId: String?
        var sortIndex: Int
        let createdAt: Date

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case photoIDsOrdered
            case mainPhotoID
            case coverPhotoID
            case categoryId
            case sortIndex
            case createdAt
        }

        init(id: String,
             title: String,
             photoIDsOrdered: [String],
             mainPhotoID: String,
             coverPhotoID: String?,
             categoryId: String?,
             sortIndex: Int,
             createdAt: Date) {
            self.id = id
            self.title = title
            self.photoIDsOrdered = photoIDsOrdered
            self.mainPhotoID = mainPhotoID
            self.coverPhotoID = coverPhotoID
            self.categoryId = categoryId
            self.sortIndex = sortIndex
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            photoIDsOrdered = try container.decodeIfPresent([String].self, forKey: .photoIDsOrdered) ?? []
            mainPhotoID = try container.decodeIfPresent(String.self, forKey: .mainPhotoID) ?? ""
            coverPhotoID = try container.decodeIfPresent(String.self, forKey: .coverPhotoID)
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? -1
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
            if coverPhotoID == nil {
                if !mainPhotoID.isEmpty {
                    coverPhotoID = mainPhotoID
                } else {
                    coverPhotoID = photoIDsOrdered.first
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(photoIDsOrdered, forKey: .photoIDsOrdered)
            try container.encode(mainPhotoID, forKey: .mainPhotoID)
            try container.encodeIfPresent(coverPhotoID, forKey: .coverPhotoID)
            try container.encodeIfPresent(categoryId, forKey: .categoryId)
            try container.encode(sortIndex, forKey: .sortIndex)
            try container.encode(createdAt, forKey: .createdAt)
        }
    }

    struct DisplayCategory: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var sortIndex: Int
        let createdAt: Date
    }

    struct Tag: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var sortIndex: Int
        let createdAt: Date
    }

    struct SetTagLink: Codable, Equatable {
        let setId: String
        let tagId: String
    }

    typealias Item = LocalLibraryItem

    nonisolated let objectWillChange = ObservableObjectPublisher()
    @Published private(set) var items: [LocalLibraryItem] = []
    @Published private(set) var sets: [SampleSet] = []
    @Published private(set) var categories: [DisplayCategory] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var setTagLinks: [SetTagLink] = []

    private let fileManager = FileManager.default
    private let photosFolderName = "Photos"
    private let thumbsFolderName = "Thumbs"
    private let catalogFileName = "catalog.json"
    private let setsFileName = "sets.json"
    private let categoriesFileName = "categories.json"
    private let tagsFileName = "tags.json"
    private let setTagLinksFileName = "set_tag_links.json"

    init() {
        Task {
            await loadCatalog()
            await loadSets()
            await loadCategories()
            await loadTags()
            await loadSetTagLinks()
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
        let coverID: String? = mainID.isEmpty ? nil : mainID
        let nextIndex = (sets.filter { $0.categoryId == nil }.map { $0.sortIndex }.max() ?? -1) + 1
        let set = SampleSet(id: UUID().uuidString,
                            title: title,
                            photoIDsOrdered: normalized,
                            mainPhotoID: mainID,
                            coverPhotoID: coverID,
                            categoryId: nil,
                            sortIndex: nextIndex,
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

    func createCategory(name: String) -> DisplayCategory {
        let category = DisplayCategory(id: UUID().uuidString,
                                       name: name,
                                       sortIndex: categories.count,
                                       createdAt: Date())
        Task {
            await MainActor.run {
                categories.append(category)
            }
            await MainActor.run {
                persistCategories()
            }
        }
        return category
    }

    func renameCategory(categoryID: String, name: String) {
        Task {
            await MainActor.run {
                guard let idx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
                categories[idx].name = name
            }
            await MainActor.run {
                persistCategories()
            }
        }
    }

    func deleteCategory(categoryID: String) {
        Task {
            await MainActor.run {
                categories.removeAll { $0.id == categoryID }
                for idx in categories.indices {
                    categories[idx].sortIndex = idx
                }
                for idx in sets.indices where sets[idx].categoryId == categoryID {
                    sets[idx].categoryId = nil
                }
            }
            await MainActor.run {
                persistCategories()
                persistSets()
            }
        }
    }

    func moveCategory(fromOffsets: IndexSet, toOffset: Int) {
        Task {
            await MainActor.run {
                categories = _reorderArray(categories, fromOffsets: fromOffsets, toOffset: toOffset)
                for idx in categories.indices {
                    categories[idx].sortIndex = idx
                }
            }
            await MainActor.run {
                persistCategories()
            }
        }
    }

    func assignSetToCategory(setID: String, categoryID: String?) {
        Task {
            await MainActor.run {
                guard let idx = sets.firstIndex(where: { $0.id == setID }) else { return }
                sets[idx].categoryId = categoryID
                let nextIndex = (sets.filter { $0.categoryId == categoryID }.map { $0.sortIndex }.max() ?? -1) + 1
                sets[idx].sortIndex = nextIndex
            }
            await MainActor.run {
                persistSets()
            }
        }
    }

    func createTag(name: String) -> Tag {
        let nextIndex = (tags.map { $0.sortIndex }.max() ?? -1) + 1
        let tag = Tag(id: UUID().uuidString,
                      name: name,
                      sortIndex: nextIndex,
                      createdAt: Date())
        Task {
            await MainActor.run {
                tags.append(tag)
            }
            await MainActor.run {
                persistTags()
            }
        }
        return tag
    }

    func renameTag(tagID: String, name: String) {
        Task {
            await MainActor.run {
                guard let idx = tags.firstIndex(where: { $0.id == tagID }) else { return }
                tags[idx].name = name
            }
            await MainActor.run {
                persistTags()
            }
        }
    }

    func deleteTag(tagID: String) {
        Task {
            await MainActor.run {
                tags.removeAll { $0.id == tagID }
                for idx in tags.indices {
                    tags[idx].sortIndex = idx
                }
                setTagLinks.removeAll { $0.tagId == tagID }
            }
            await MainActor.run {
                persistTags()
                persistSetTagLinks()
            }
        }
    }

    func assignTagToSet(setID: String, tagID: String) {
        Task {
            await MainActor.run {
                guard !setTagLinks.contains(where: { $0.setId == setID && $0.tagId == tagID }) else { return }
                setTagLinks.append(SetTagLink(setId: setID, tagId: tagID))
            }
            await MainActor.run {
                persistSetTagLinks()
            }
        }
    }

    func unassignTagFromSet(setID: String, tagID: String) {
        Task {
            await MainActor.run {
                setTagLinks.removeAll { $0.setId == setID && $0.tagId == tagID }
            }
            await MainActor.run {
                persistSetTagLinks()
            }
        }
    }

    func tagsForSet(setID: String) -> [Tag] {
        let tagIDs = Set(setTagLinks.filter { $0.setId == setID }.map { $0.tagId })
        return tags.filter { tagIDs.contains($0.id) }.sorted { $0.sortIndex < $1.sortIndex }
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

    @MainActor
    func renameSet(setId: String, title: String) {
        guard let idx = sets.firstIndex(where: { $0.id == setId }) else { return }
        var updated = sets[idx]
        updated.title = title
        sets[idx] = updated
        persistSets()
    }

    @MainActor
    func setCoverPhoto(setId: String, photoId: String) {
        guard let idx = sets.firstIndex(where: { $0.id == setId }) else { return }
        var updated = sets[idx]
        updated.coverPhotoID = photoId
        sets[idx] = updated
        persistSets()
    }

    @MainActor
    func reorderSets(categoryId: String?, fromOffsets: IndexSet, toOffset: Int) {
        let grouped = sets.filter { $0.categoryId == categoryId }.sorted { $0.sortIndex < $1.sortIndex }
        guard !grouped.isEmpty else { return }
        let reorderedGroup = _reorderArray(grouped, fromOffsets: fromOffsets, toOffset: toOffset)
        var updatedGroup: [SampleSet] = []
        updatedGroup.reserveCapacity(reorderedGroup.count)
        for (idx, set) in reorderedGroup.enumerated() {
            var updated = set
            updated.sortIndex = idx
            updatedGroup.append(updated)
        }
        for updated in updatedGroup {
            if let index = sets.firstIndex(where: { $0.id == updated.id }) {
                sets[index] = updated
            }
        }
        persistSets()
    }

    @MainActor
    func reorderPhotosInSet(setId: String, fromOffsets: IndexSet, toOffset: Int) {
        guard let idx = sets.firstIndex(where: { $0.id == setId }) else { return }
        var updated = sets[idx]
        updated.photoIDsOrdered = _reorderArray(updated.photoIDsOrdered, fromOffsets: fromOffsets, toOffset: toOffset)
        sets[idx] = updated
        persistSets()
    }

    @MainActor
    func addPhotosToSet(setId: String, photoIds: [String]) {
        guard let idx = sets.firstIndex(where: { $0.id == setId }) else { return }
        let validIds = photoIds.filter { id in items.contains { $0.id == id } }
        var updated = sets[idx]
        var ordered = updated.photoIDsOrdered
        for id in validIds where !ordered.contains(id) {
            ordered.append(id)
        }
        updated.photoIDsOrdered = ordered
        if updated.mainPhotoID.isEmpty || !ordered.contains(updated.mainPhotoID) {
            updated.mainPhotoID = ordered.first ?? ""
        }
        sets[idx] = updated
        persistSets()
    }

    @MainActor
    func removePhotoFromSet(setId: String, photoId: String) {
        guard let idx = sets.firstIndex(where: { $0.id == setId }) else { return }
        var updated = sets[idx]
        updated.photoIDsOrdered.removeAll { $0 == photoId }
        if updated.mainPhotoID == photoId || !updated.photoIDsOrdered.contains(updated.mainPhotoID) {
            updated.mainPhotoID = updated.photoIDsOrdered.first ?? ""
        }
        if updated.coverPhotoID == photoId {
            if let first = updated.photoIDsOrdered.first {
                updated.coverPhotoID = first
            } else {
                updated.coverPhotoID = nil
            }
        }
        sets[idx] = updated
        persistSets()
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

    private func categoriesURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(categoriesFileName)
    }

    private func tagsURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(tagsFileName)
    }

    private func setTagLinksURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(setTagLinksFileName)
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
        let normalized = normalizeSetSortIndex(decoded)
        await MainActor.run {
            sets = normalized
        }
    }

    private func _reorderArray<T>(_ array: [T], fromOffsets: IndexSet, toOffset: Int) -> [T] {
        guard !fromOffsets.isEmpty else { return array }
        let moving = fromOffsets.sorted().map { array[$0] }
        var result = array
        for idx in fromOffsets.sorted(by: >) {
            result.remove(at: idx)
        }
        let removedBefore = fromOffsets.filter { $0 < toOffset }.count
        var destination = toOffset - removedBefore
        if destination < 0 { destination = 0 }
        if destination > result.count { destination = result.count }
        result.insert(contentsOf: moving, at: destination)
        return result
    }

    private func normalizeSetSortIndex(_ input: [SampleSet]) -> [SampleSet] {
        var output = input
        let grouped = Dictionary(grouping: output, by: { $0.categoryId })
        var updatedIDs: [String: Int] = [:]
        for (_, group) in grouped {
            if group.allSatisfy({ $0.sortIndex >= 0 }) {
                continue
            }
            let ordered = group.sorted { $0.createdAt < $1.createdAt }
            for (idx, set) in ordered.enumerated() {
                updatedIDs[set.id] = idx
            }
        }
        guard !updatedIDs.isEmpty else { return output }
        for idx in output.indices {
            if let newIndex = updatedIDs[output[idx].id] {
                output[idx].sortIndex = newIndex
            }
        }
        return output
    }

    private func loadCategories() async {
        let url = categoriesURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DisplayCategory].self, from: data) else {
            await MainActor.run {
                categories = []
            }
            return
        }
        let sorted = decoded.sorted { $0.sortIndex < $1.sortIndex }
        await MainActor.run {
            categories = sorted
        }
    }

    private func loadTags() async {
        let url = tagsURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Tag].self, from: data) else {
            await MainActor.run {
                tags = []
            }
            return
        }
        let sorted = decoded.sorted { $0.sortIndex < $1.sortIndex }
        await MainActor.run {
            tags = sorted
        }
    }

    private func loadSetTagLinks() async {
        let url = setTagLinksURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SetTagLink].self, from: data) else {
            await MainActor.run {
                setTagLinks = []
            }
            return
        }
        await MainActor.run {
            setTagLinks = decoded
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

    private func persistCategories() {
        let url = categoriesURL()
        let data = try? JSONEncoder().encode(categories)
        try? data?.write(to: url, options: .atomic)
    }

    private func persistTags() {
        let url = tagsURL()
        let data = try? JSONEncoder().encode(tags)
        try? data?.write(to: url, options: .atomic)
    }

    private func persistSetTagLinks() {
        let url = setTagLinksURL()
        let data = try? JSONEncoder().encode(setTagLinks)
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
