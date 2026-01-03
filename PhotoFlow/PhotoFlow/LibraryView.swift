import PhotosUI
import SwiftUI

struct LibraryView: View {
    @StateObject private var store = LocalLibraryStore()
    @State private var selections: [PhotosPickerItem] = []
    @State private var selectedPhotoIDs: [String] = []
    @State private var setTitle: String = ""
    @State private var showNewSetPrompt = false
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
                            Text("Sets")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            ForEach(store.sets) { set in
                                Button {
                                    path.append(set.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        setThumbnailView(set: set)
                                            .frame(width: 56, height: 84)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(set.title)
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            Text("\(set.photoIDsOrdered.count) photos")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
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
        }
    }

    private func defaultSetTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd HH:mm"
        return "套图 \(formatter.string(from: Date()))"
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
