import PhotosUI
import SwiftUI

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

    init(store: LocalLibraryStore = LocalLibraryStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Categories")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Tags")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sets")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            ForEach(store.sets) { set in
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
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 12)
            .navigationTitle("Library")
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
        let mainID = set.mainPhotoID.isEmpty ? set.photoIDsOrdered.first : set.mainPhotoID
        if let mainID,
           let item = store.items.first(where: { $0.id == mainID }),
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

    var body: some View {
        ScrollView {
            let set = store.sets.first(where: { $0.id == setID })
            if let set {
                let tags = tagsSorted()
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                let items = set.photoIDsOrdered.compactMap { id in
                    store.items.first(where: { $0.id == id })
                }
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        SetPhotoCell(store: store,
                                     item: item,
                                     isMain: item.id == set.mainPhotoID) {
                            store.setMainPhoto(setID: set.id, photoID: item.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                Text("Set not found")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            }
        }
        .navigationTitle(store.sets.first(where: { $0.id == setID })?.title ?? "Set")
        .toolbar {
            Button("Delete Set", role: .destructive) {
                store.deleteSet(setID: setID)
                dismiss()
            }
        }
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
}

private struct SetPhotoCell: View {
    let store: LocalLibraryStore
    let item: LocalLibraryStore.LocalLibraryItem
    let isMain: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            if let image = store.thumbnail(at: item.thumbPath) ?? store.image(at: item.photoPath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.12))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
            }
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isMain ? Color.primary.opacity(0.9) : .clear, lineWidth: 2))
    }
}
