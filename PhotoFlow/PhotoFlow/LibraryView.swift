import PhotosUI
import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: LocalLibraryStore
    @State private var selections: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selections, matching: .images) {
                    Label("Import photos", systemImage: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.white.opacity(0.95), in: Capsule())
                }
                .buttonStyle(.plain)
                .onChange(of: selections) { newValue in
                    guard !newValue.isEmpty else { return }
                    Task {
                        await store.importItems(newValue)
                        selections = []
                    }
                }

                ScrollView {
                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.items) { item in
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 12)
            .navigationTitle("Library")
            .background(Color(.systemGroupedBackground))
        }
    }
}
