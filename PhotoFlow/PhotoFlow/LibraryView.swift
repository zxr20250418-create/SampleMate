import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var store = LocalLibraryStore()
    @State private var selections: [PhotosPickerItem] = []
    @State private var selectedPhotoIDs: [String] = []
    @State private var setTitle: String = ""
    @State private var showNewSetPrompt = false
    @State private var showNewCategoryPrompt = false
    @State private var newCategoryName: String = ""
    @State private var showRenameCategoryPrompt = false
    @State private var renameCategoryID: String?
    @State private var renameCategoryName: String = ""
    @State private var showNewTagPrompt = false
    @State private var newTagName: String = ""
    @State private var path: [String] = []
    @State private var showBackupExporter = false
    @State private var backupDocument = SampleMateBackupDocument()
    @State private var showBackupImporter = false
    @State private var pendingRestoreDocument: SampleMateBackupDocument?
    @State private var showRestoreConfirm = false
    @State private var isRestoringBackup = false
    @State private var showRestoreSuccess = false
    @State private var showRestoreError = false
    @State private var restoreErrorMessage: String = ""

    init(store: LocalLibraryStore = LocalLibraryStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selections, matching: .images) {
                            Label("Import photos", systemImage: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(.white.opacity(0.95), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selections) { _, newValue in
                            guard !newValue.isEmpty else { return }
                            Task {
                                await store.importItems(newValue)
                                selections = []
                            }
                        }

                        Button {
                            setTitle = defaultSetTitle()
                            showNewSetPrompt = true
                        } label: {
                            Label("New Set", systemImage: "rectangle.stack.badge.plus")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(.white.opacity(0.95), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedPhotoIDs.isEmpty)
                    }
                }

                Section("Categories") {
                    HStack {
                        Spacer()
                        Button {
                            newCategoryName = "新分类"
                            showNewCategoryPrompt = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(categoriesSorted()) { category in
                        HStack(spacing: 12) {
                            Text(category.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Spacer()
                            Button {
                                renameCategoryID = category.id
                                renameCategoryName = category.name
                                showRenameCategoryPrompt = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                store.deleteCategory(categoryID: category.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)

                            Button {
                                moveCategory(category: category, direction: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(isFirstCategory(category))

                            Button {
                                moveCategory(category: category, direction: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(isLastCategory(category))
                        }
                        .padding(12)
                        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                Section("Tags") {
                    HStack {
                        Spacer()
                        Button {
                            newTagName = "新标签"
                            showNewTagPrompt = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(tagsSorted()) { tag in
                        HStack(spacing: 12) {
                            Text(tag.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Spacer()
                        }
                        .padding(12)
                        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                Section("备份/恢复") {
                    Button {
                        do {
                            backupDocument = try store.makeBackupDocument()
                            showBackupExporter = true
                        } catch {
                            restoreErrorMessage = "导出失败"
                            showRestoreError = true
                        }
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showBackupImporter = true
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(setGroups()) { group in
                    Section("Sets · \(group.title)") {
                        ForEach(group.sets) { set in
                            Button {
                                path.append(set.id)
                            } label: {
                                HStack(spacing: 12) {
                                    setThumbnailView(set: set)
                                        .frame(width: 56, height: 84)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(set.title)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        Text("\(set.photoIDsOrdered.count) photos")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text("标签 \(store.tagsForSet(setID: set.id).count)")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Picker("Category", selection: Binding(
                                            get: { set.categoryId ?? "" },
                                            set: { value in
                                                let categoryID = value.isEmpty ? nil : value
                                                store.assignSetToCategory(setID: set.id, categoryID: categoryID)
                                            }
                                        )) {
                                            Text("未分类").tag("")
                                            ForEach(categoriesSorted()) { category in
                                                Text(category.name).tag(category.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        .onMove { indices, newOffset in
                            store.reorderSets(categoryId: group.categoryId, fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                }

                Section("Photos") {
                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.items) { item in
                            photoCell(item: item)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected(item.id) ? Color.primary.opacity(0.9) : .clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    toggleSelection(for: item.id)
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: String.self) { setID in
                SetDetailView(store: store, setID: setID)
            }
            .alert("New Set", isPresented: $showNewSetPrompt) {
                TextField("Title", text: $setTitle)
                Button("Create") {
                    let ids = selectedPhotoIDsOrdered()
                    guard !ids.isEmpty else { return }
                    let created = store.createSet(title: setTitle, photoIDs: ids)
                    selectedPhotoIDs = []
                    setTitle = ""
                    path.append(created.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Create a new sample set from selected photos.")
            }
            .alert("New Category", isPresented: $showNewCategoryPrompt) {
                TextField("Name", text: $newCategoryName)
                Button("Create") {
                    store.createCategory(name: newCategoryName)
                    newCategoryName = ""
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename Category", isPresented: $showRenameCategoryPrompt) {
                TextField("Name", text: $renameCategoryName)
                Button("Save") {
                    if let id = renameCategoryID {
                        store.renameCategory(categoryID: id, name: renameCategoryName)
                    }
                    renameCategoryID = nil
                    renameCategoryName = ""
                }
                Button("Cancel", role: .cancel) {
                    renameCategoryID = nil
                    renameCategoryName = ""
                }
            }
            .alert("New Tag", isPresented: $showNewTagPrompt) {
                TextField("Name", text: $newTagName)
                Button("Create") {
                    store.createTag(name: newTagName)
                    newTagName = ""
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("恢复备份", isPresented: $showRestoreConfirm) {
                Button("恢复", role: .destructive) {
                    guard let document = pendingRestoreDocument else { return }
                    isRestoringBackup = true
                    Task {
                        do {
                            try await store.restore(from: document)
                            showRestoreSuccess = true
                        } catch {
                            restoreErrorMessage = "恢复失败"
                            showRestoreError = true
                        }
                        isRestoringBackup = false
                        pendingRestoreDocument = nil
                    }
                }
                Button("取消", role: .cancel) {
                    pendingRestoreDocument = nil
                }
            } message: {
                Text("将覆盖当前本地数据。")
            }
            .alert("恢复完成", isPresented: $showRestoreSuccess) {
                Button("OK") {}
            }
            .alert("操作失败", isPresented: $showRestoreError) {
                Button("OK") {}
            } message: {
                Text(restoreErrorMessage)
            }
            .fileExporter(isPresented: $showBackupExporter,
                          document: backupDocument,
                          contentType: UTType.sampleMateBackup,
                          defaultFilename: "SampleMateBackup") { result in
                if case .failure = result {
                    restoreErrorMessage = "导出失败"
                    showRestoreError = true
                }
            }
            .fileImporter(isPresented: $showBackupImporter,
                          allowedContentTypes: [UTType.sampleMateBackup]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer {
                        if access {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        let wrapper = try FileWrapper(url: url, options: .immediate)
                        pendingRestoreDocument = SampleMateBackupDocument(rootFileWrapper: wrapper)
                        showRestoreConfirm = true
                    } catch {
                        restoreErrorMessage = "导入失败"
                        showRestoreError = true
                    }
                case .failure:
                    restoreErrorMessage = "导入失败"
                    showRestoreError = true
                }
            }
            .overlay {
                if isRestoringBackup {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("正在恢复…")
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func defaultSetTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd HH:mm"
        return "套图 \(formatter.string(from: Date()))"
    }

    private func categoriesSorted() -> [LocalLibraryStore.DisplayCategory] {
        store.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func tagsSorted() -> [LocalLibraryStore.Tag] {
        store.tags.sorted { $0.sortIndex < $1.sortIndex }
    }

    private struct SetGroup: Identifiable {
        let id: String
        let title: String
        let categoryId: String?
        let sets: [LocalLibraryStore.SampleSet]
    }

    private func setGroups() -> [SetGroup] {
        var groups: [SetGroup] = []
        let uncategorized = store.sets.filter { $0.categoryId == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
        if !uncategorized.isEmpty {
            groups.append(SetGroup(id: "uncategorized", title: "未分类", categoryId: nil, sets: uncategorized))
        }
        for category in categoriesSorted() {
            let sets = store.sets.filter { $0.categoryId == category.id }
                .sorted { $0.sortIndex < $1.sortIndex }
            if !sets.isEmpty {
                groups.append(SetGroup(id: category.id, title: category.name, categoryId: category.id, sets: sets))
            }
        }
        return groups
    }

    private func moveCategory(category: LocalLibraryStore.DisplayCategory, direction: Int) {
        let categories = categoriesSorted()
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let target = index + direction
        guard target >= 0 && target < categories.count else { return }
        let offset = direction > 0 ? index + 2 : index
        store.moveCategory(fromOffsets: IndexSet(integer: index), toOffset: offset)
    }

    private func isFirstCategory(_ category: LocalLibraryStore.DisplayCategory) -> Bool {
        categoriesSorted().first?.id == category.id
    }

    private func isLastCategory(_ category: LocalLibraryStore.DisplayCategory) -> Bool {
        categoriesSorted().last?.id == category.id
    }

    private func selectedPhotoIDsOrdered() -> [String] {
        selectedPhotoIDs.filter { id in store.items.contains { $0.id == id } }
    }

    private func toggleSelection(for id: String) {
        if let index = selectedPhotoIDs.firstIndex(of: id) {
            selectedPhotoIDs.remove(at: index)
        } else {
            selectedPhotoIDs.append(id)
        }
    }

    private func isSelected(_ id: String) -> Bool {
        selectedPhotoIDs.contains(id)
    }

    private func photoCell(item: LocalLibraryStore.LocalLibraryItem) -> some View {
        if let image = store.thumbnail(at: item.thumbPath) ?? store.image(at: item.photoPath) {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            )
        }
        return AnyView(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
        )
    }

    private func setThumbnailView(set: LocalLibraryStore.SampleSet) -> some View {
        let preferredID = set.coverPhotoID
            ?? (set.mainPhotoID.isEmpty ? set.photoIDsOrdered.first : set.mainPhotoID)
        if let preferredID,
           let item = store.items.first(where: { $0.id == preferredID }),
           let image = store.thumbnail(at: item.thumbPath) ?? store.image(at: item.photoPath) {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
        return AnyView(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.12))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
        )
    }
}

private struct SetDetailView: View {
    @ObservedObject var store: LocalLibraryStore
    let setID: String
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPhotos = false
    @State private var selectedAddPhotoIDs: Set<String> = []
    @State private var showRenameSetPrompt = false
    @State private var renameSetTitle: String = ""

    var body: some View {
        let set = store.sets.first(where: { $0.id == setID })
        List {
            if let set {
                let tags = tagsSorted()
                if !tags.isEmpty {
                    Section("Tags") {
                        ForEach(tags) { tag in
                            Button {
                                toggleTag(setID: set.id, tagID: tag.id)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                    Spacer()
                                    if isTagAssigned(setID: set.id, tagID: tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.primary)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                let items = set.photoIDsOrdered.compactMap { id in
                    store.items.first(where: { $0.id == id })
                }
                Section("Photos") {
                    ForEach(items) { item in
                        SetPhotoRow(store: store,
                                    item: item,
                                    isMain: item.id == set.mainPhotoID,
                                    isCover: item.id == set.coverPhotoID,
                                    onSetMain: {
                                        store.setMainPhoto(setID: set.id, photoID: item.id)
                                    },
                                    onSetCover: {
                                        store.setCoverPhoto(setId: set.id, photoId: item.id)
                                    })
                        .swipeActions(edge: .trailing) {
                            Button("移出套图", role: .destructive) {
                                store.removePhotoFromSet(setId: set.id, photoId: item.id)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        store.reorderPhotosInSet(setId: set.id, fromOffsets: indices, toOffset: newOffset)
                    }
                }
            } else {
                Text("Set not found")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }
        }
        .navigationTitle(store.sets.first(where: { $0.id == setID })?.title ?? "Set")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit Title") {
                    renameSetTitle = store.sets.first(where: { $0.id == setID })?.title ?? ""
                    showRenameSetPrompt = true
                }
                Button("Add Photos") {
                    selectedAddPhotoIDs.removeAll()
                    showAddPhotos = true
                }
                Button("Delete Set", role: .destructive) {
                    store.deleteSet(setID: setID)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showAddPhotos) {
            NavigationStack {
                let set = store.sets.first(where: { $0.id == setID })
                let existingIDs = Set(set?.photoIDsOrdered ?? [])
                List {
                    ForEach(store.items) { item in
                        let isExisting = existingIDs.contains(item.id)
                        let isSelected = selectedAddPhotoIDs.contains(item.id)
                        Button {
                            if isSelected {
                                selectedAddPhotoIDs.remove(item.id)
                            } else {
                                selectedAddPhotoIDs.insert(item.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                addPhotoRowThumbnail(item)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Photo \(item.id.prefix(6))")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                    if isExisting {
                                        Text("已在套图")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isExisting)
                    }
                }
                .navigationTitle("Add Photos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            store.addPhotosToSet(setId: setID, photoIds: Array(selectedAddPhotoIDs))
                            showAddPhotos = false
                        }
                        .disabled(selectedAddPhotoIDs.isEmpty)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showAddPhotos = false
                        }
                    }
                }
            }
        }
        .alert("Edit Title", isPresented: $showRenameSetPrompt) {
            TextField("Title", text: $renameSetTitle)
            Button("Save") {
                store.renameSet(setId: setID, title: renameSetTitle)
            }
            Button("Cancel", role: .cancel) {}
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }

    private func tagsSorted() -> [LocalLibraryStore.Tag] {
        store.tags.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func isTagAssigned(setID: String, tagID: String) -> Bool {
        store.setTagLinks.contains { $0.setId == setID && $0.tagId == tagID }
    }

    private func toggleTag(setID: String, tagID: String) {
        if isTagAssigned(setID: setID, tagID: tagID) {
            store.unassignTagFromSet(setID: setID, tagID: tagID)
        } else {
            store.assignTagToSet(setID: setID, tagID: tagID)
        }
    }

    @ViewBuilder
    private func addPhotoRowThumbnail(_ item: LocalLibraryStore.LocalLibraryItem) -> some View {
        if let image = store.thumbnail(at: item.thumbPath) ?? store.image(at: item.photoPath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.12))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 44)
        }
    }
}

private struct SetPhotoRow: View {
    let store: LocalLibraryStore
    let item: LocalLibraryStore.LocalLibraryItem
    let isMain: Bool
    let isCover: Bool
    let onSetMain: () -> Void
    let onSetCover: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let image = store.thumbnail(at: item.thumbPath) ?? store.image(at: item.photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: 64)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Photo \(item.id.prefix(6))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                HStack(spacing: 6) {
                    if isMain {
                        Text("主图")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if isCover {
                        Text("封面")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button(action: onSetMain) {
                Image(systemName: isMain ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMain ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            Button(action: onSetCover) {
                Image(systemName: isCover ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCover ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
