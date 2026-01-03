import SwiftUI

struct ShowcaseView: View {
    @EnvironmentObject var store: LocalLibraryStore

    @AppStorage("priceVisible") private var priceVisible: Bool = true
    @AppStorage("compactTextVisible") private var compactTextVisible: Bool = true
    @AppStorage("slideshowEnabled") private var slideshowEnabled: Bool = false
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds: Int = 5

    @State private var isFullscreen = false
    @State private var overlaysVisible = true
    @State private var categoryIndex = 0
    @State private var setIndex = 0
    @State private var photoIndex = 0
    @State private var isSlideshowPlaying = false
    @State private var slideshowTimer: Timer?

    @Environment(\.scenePhase) private var scenePhase

    private let catalog = ShowcaseDemoCatalog.sample
    private let photoAspect: CGFloat = 2.0 / 3.0

    private struct DisplayPhoto: Identifiable {
        let id: String
        let source: PhotoSource
    }

    private enum PhotoSource {
        case local(LocalLibraryStore.Item)
        case demo(ShowcaseDemoPhoto)
    }

    var body: some View {
        let usesCategories = !store.categories.isEmpty
        let usesSets = !store.sets.isEmpty
        let usesLocal = !store.items.isEmpty
        let categories = categoriesSorted()
        let activeCategory = categories[safe: categoryIndex]
        let setsForCategory = usesCategories
            ? store.sets.filter { $0.categoryId == activeCategory?.id }
            : store.sets
        let activeSet = setsForCategory[safe: setIndex]
        let setPhotoItems = activeSet?.photoIDsOrdered.compactMap { id in
            store.items.first(where: { $0.id == id })
        } ?? []
        let category = catalog.categories[safe: categoryIndex]
        let demoSet = category?.sets[safe: setIndex]
        let demoPhotos = demoSet?.photos ?? []
        let displayPhotos: [DisplayPhoto] = usesCategories || usesSets
            ? setPhotoItems.map { DisplayPhoto(id: $0.id, source: .local($0)) }
            : (usesLocal
                ? store.items.map { DisplayPhoto(id: $0.id, source: .local($0)) }
                : demoPhotos.enumerated().map { DisplayPhoto(id: "demo-\($0.offset)", source: .demo($0.element)) })
        let categoryName = usesCategories
            ? (activeCategory?.name ?? "分类")
            : (usesSets ? "Sample Sets" : (usesLocal ? "Local Library" : (category?.name ?? "Showcase")))
        let setTitle = usesCategories || usesSets
            ? (activeSet?.title ?? "Set")
            : (usesLocal ? "Imported Photos" : (demoSet?.title ?? "Set"))
        let setNote = usesCategories || usesSets ? "" : (usesLocal ? "From your Photos library." : (demoSet?.note ?? ""))
        let priceText = usesCategories || usesSets || usesLocal ? "" : (demoSet?.priceText ?? "")
        let categoryEmpty = usesCategories && setsForCategory.isEmpty

        GeometryReader { proxy in
            let size = proxy.size
            let thumbnailHeight: CGFloat = 102
            let mainHeight = isFullscreen ? size.height * 0.72 : size.height * 0.42

            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    if !isFullscreen {
                        headerBar(categoryName: categoryName, setTitle: setTitle, photosCount: displayPhotos.count)
                            .padding(.horizontal, 20)
                    }

                    ZStack(alignment: .center) {
                        if isFullscreen {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color.black.opacity(0.55))
                                .background(.ultraThinMaterial)
                                .padding(.horizontal, 12)
                        }

                        Group {
                            if categoryEmpty {
                                categoryEmptyView(height: mainHeight)
                            } else if let photo = displayPhotos[safe: photoIndex] {
                                mainPhotoView(photo: photo, height: mainHeight, isFullscreen: isFullscreen)
                            } else {
                                fallbackMainPhoto(height: mainHeight, isFullscreen: isFullscreen)
                            }
                        }
                        .gesture(dragGesture())
                        .gesture(pinchGesture())
                        .onTapGesture {
                            if isFullscreen { overlaysVisible.toggle() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .overlay(alignment: .top) {
                        if isFullscreen && overlaysVisible {
                            headerBar(categoryName: categoryName, setTitle: setTitle, photosCount: displayPhotos.count)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isFullscreen && overlaysVisible {
                            filmstrip(photos: displayPhotos, height: thumbnailHeight)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }

                    if !isFullscreen {
                        compactThumbnailRow(photos: displayPhotos, height: thumbnailHeight)
                            .padding(.horizontal, 20)

                        if compactTextVisible {
                            showcaseCard(note: setNote, priceText: priceText)
                                .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isFullscreen) { value in
            if value {
                if slideshowEnabled { startSlideshow(photosCount: displayPhotos.count) }
            } else {
                pauseSlideshow()
            }
        }
        .onChange(of: slideshowIntervalSeconds) { _ in
            if isSlideshowPlaying { startSlideshow(photosCount: displayPhotos.count) }
        }
        .onChange(of: slideshowEnabled) { value in
            if !value { pauseSlideshow() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { pauseSlideshow() }
        }
        .onChange(of: store.items.count) { _ in
            if photoIndex >= displayPhotos.count { photoIndex = 0 }
        }
        .onChange(of: store.categories) { _ in
            let categories = categoriesSorted()
            if categoryIndex >= categories.count { categoryIndex = 0 }
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                setIndex = 0
                syncPhotoIndex(mainID: setsForCategory.first?.mainPhotoID,
                               photos: displayPhotosForSet(setsForCategory.first))
            }
        }
        .onChange(of: categoryIndex) { _ in
            let categories = categoriesSorted()
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                setIndex = 0
                syncPhotoIndex(mainID: setsForCategory.first?.mainPhotoID,
                               photos: displayPhotosForSet(setsForCategory.first))
            }
        }
        .onChange(of: store.sets) { _ in
            let categories = categoriesSorted()
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                if setIndex >= setsForCategory.count { setIndex = 0 }
                let activeSet = setsForCategory[safe: setIndex]
                syncPhotoIndex(mainID: activeSet?.mainPhotoID,
                               photos: displayPhotosForSet(activeSet))
            } else if !store.sets.isEmpty {
                if setIndex >= store.sets.count { setIndex = 0 }
                syncPhotoIndex(mainID: store.sets[safe: setIndex]?.mainPhotoID,
                               photos: displayPhotosForSet(store.sets[safe: setIndex]))
            }
        }
    }

    private func headerBar(categoryName: String, setTitle: String, photosCount: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(setTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isFullscreen {
                Button {
                    if isSlideshowPlaying { pauseSlideshow() }
                    else { startSlideshow(photosCount: photosCount) }
                } label: {
                    Text(isSlideshowPlaying ? "showcase.pause" : "showcase.play")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("\(min(photoIndex + 1, photosCount))/\(max(photosCount, 1))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white.opacity(0.9), in: Capsule())
            Text(isFullscreen ? "Full" : "Compact")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white, in: Capsule())
        }
        .padding(.vertical, 8)
    }

    private func mainPhotoView(photo: DisplayPhoto, height: CGFloat, isFullscreen: Bool) -> some View {
        photoView(photo: photo, height: height, corner: isFullscreen ? 22 : 20, useThumbnail: false)
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .padding(isFullscreen ? 18 : 0)
            .frame(height: height)
    }

    private func fallbackMainPhoto(height: CGFloat, isFullscreen: Bool) -> some View {
        RoundedRectangle(cornerRadius: isFullscreen ? 22 : 20)
            .fill(Color.gray.opacity(0.16))
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .padding(isFullscreen ? 18 : 0)
            .frame(height: height)
    }

    private func categoryEmptyView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.12))
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .overlay(
                VStack(spacing: 6) {
                    Text("该分类暂无套图")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("上下滑动切换分类")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            )
            .frame(height: height)
    }

    private func filmstrip(photos: [DisplayPhoto], height: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.offset) { idx, p in
                    thumbnailButton(photo: p, height: height, isSelected: idx == photoIndex) {
                        pauseSlideshow()
                        photoIndex = idx
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func compactThumbnailRow(photos: [DisplayPhoto], height: CGFloat) -> some View {
        let indices = compactThumbnailIndices(count: photos.count)
        return HStack(spacing: 12) {
            ForEach(indices, id: \.self) { idx in
                if let photo = photos[safe: idx] {
                    thumbnailButton(photo: photo, height: height, isSelected: idx == photoIndex) {
                        pauseSlideshow()
                        photoIndex = idx
                    }
                }
            }
        }
    }

    private func compactThumbnailIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let maxCount = min(3, count)
        return (0..<maxCount).map { (photoIndex + $0) % count }
    }

    private func thumbnailButton(photo: DisplayPhoto, height: CGFloat, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            photoView(photo: photo, height: height, corner: 14, useThumbnail: true)
                .aspectRatio(photoAspect, contentMode: .fit)
                .frame(height: height)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.primary.opacity(0.9) : Color.black.opacity(0.08), lineWidth: isSelected ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func photoView(photo: DisplayPhoto, height: CGFloat, corner: CGFloat, useThumbnail: Bool) -> some View {
        switch photo.source {
        case .local(let item):
            let image = useThumbnail ? store.thumbnail(at: item.thumbPath) : store.image(at: item.photoPath)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: corner))
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.gray.opacity(0.16))
                    .frame(height: height)
            }
        case .demo(let demo):
            Placeholder(photo: demo, height: height, corner: corner)
        }
    }

    private func showcaseCard(note: String, priceText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Showcase")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(note)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if priceVisible && !priceText.isEmpty {
                HStack(spacing: 10) {
                    Text("Package").foregroundStyle(.secondary)
                    Text(priceText).fontWeight(.bold)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 18).onEnded { v in
            let dx = v.translation.width, dy = v.translation.height
            if abs(dx) > abs(dy) {
                if dx <= -60 { pauseSlideshow(); nextSet(1) }
                else if dx >= 60 { pauseSlideshow(); nextSet(-1) }
            } else {
                if dy <= -60 { pauseSlideshow(); nextCategory(1) }
                else if dy >= 60 { pauseSlideshow(); nextCategory(-1) }
            }
        }
    }

    private func pinchGesture() -> some Gesture {
        MagnificationGesture().onEnded { value in
            if value > 1.08 { pauseSlideshow(); isFullscreen = true }
            else if value < 0.92 { pauseSlideshow(); isFullscreen = false }
        }
    }

    private func startSlideshow(photosCount: Int) {
        guard photosCount > 0 else { return }
        pauseSlideshow()
        isSlideshowPlaying = true
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(slideshowIntervalSeconds), repeats: true) { _ in
            advancePhoto(photosCount: photosCount)
        }
    }

    private func pauseSlideshow() {
        isSlideshowPlaying = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }

    private func advancePhoto(photosCount: Int) {
        guard photosCount > 0 else { return }
        photoIndex = (photoIndex + 1) % photosCount
    }

    private func nextCategory(_ d: Int) {
        let categories = categoriesSorted()
        if !categories.isEmpty {
            let c = categories.count
            categoryIndex = (categoryIndex + d + c) % c
            let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
            setIndex = 0
            syncPhotoIndex(mainID: setsForCategory.first?.mainPhotoID,
                           photos: displayPhotosForSet(setsForCategory.first))
            return
        }
        if !store.sets.isEmpty { return }
        let c = catalog.categories.count
        categoryIndex = (categoryIndex + d + c) % c
        setIndex = 0
        photoIndex = 0
    }

    private func nextSet(_ d: Int) {
        let categories = categoriesSorted()
        if !categories.isEmpty {
            let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
            let s = setsForCategory.count
            if s == 0 { return }
            setIndex = (setIndex + d + s) % s
            let activeSet = setsForCategory[safe: setIndex]
            syncPhotoIndex(mainID: activeSet?.mainPhotoID, photos: displayPhotosForSet(activeSet))
            return
        }
        if !store.sets.isEmpty {
            let s = store.sets.count
            if s == 0 { return }
            setIndex = (setIndex + d + s) % s
            syncPhotoIndex(mainID: store.sets[safe: setIndex]?.mainPhotoID,
                           photos: displayPhotosForSet(store.sets[safe: setIndex]))
            return
        }
        let s = catalog.categories[categoryIndex].sets.count
        setIndex = (setIndex + d + s) % s
        photoIndex = 0
    }

    private func categoriesSorted() -> [LocalLibraryStore.DisplayCategory] {
        store.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    private func displayPhotosForSet(_ set: LocalLibraryStore.SampleSet?) -> [DisplayPhoto] {
        guard let set else { return [] }
        let items = set.photoIDsOrdered.compactMap { id in
            store.items.first(where: { $0.id == id })
        }
        return items.map { DisplayPhoto(id: $0.id, source: .local($0)) }
    }

    private func syncPhotoIndex(mainID: String?, photos: [DisplayPhoto]) {
        guard !photos.isEmpty else {
            photoIndex = 0
            return
        }
        if let mainID,
           let idx = photos.firstIndex(where: { $0.id == mainID }) {
            photoIndex = idx
        } else if photoIndex >= photos.count {
            photoIndex = 0
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct ShowcaseDemoCatalog {
    let categories: [ShowcaseDemoCategory]
    static let sample = ShowcaseDemoCatalog(categories: [
        ShowcaseDemoCategory(name: "Beach · Golden Hour", sets: [
            ShowcaseDemoSet(title: "Couple Walk", note: "Warm backlight. Simple poses.", priceText: "199 RMB",
                    photos: [.warm("A1"), .warm("A2"), .warm("A3")]),
            ShowcaseDemoSet(title: "Solo Portrait", note: "Face light first.", priceText: "168 RMB",
                    photos: [.warm("B1"), .warm("B2"), .warm("B3")])
        ]),
        ShowcaseDemoCategory(name: "City · Cool Tone", sets: [
            ShowcaseDemoSet(title: "Coffee Shop", note: "Window light.", priceText: "199 RMB",
                    photos: [.cool("C1"), .cool("C2"), .cool("C3")]),
            ShowcaseDemoSet(title: "Street Notes", note: "Walk & turn.", priceText: "168 RMB",
                    photos: [.neutral("D1"), .neutral("D2"), .neutral("D3")])
        ])
    ])
}
private struct ShowcaseDemoCategory { let name: String; let sets: [ShowcaseDemoSet] }
private struct ShowcaseDemoSet { let title: String; let note: String; let priceText: String; let photos: [ShowcaseDemoPhoto] }
private struct ShowcaseDemoPhoto {
    let label: String; let colors: [Color]
    static func warm(_ s: String) -> ShowcaseDemoPhoto { .init(label: s, colors: [Color.orange.opacity(0.25), Color.pink.opacity(0.25)]) }
    static func cool(_ s: String) -> ShowcaseDemoPhoto { .init(label: s, colors: [Color.blue.opacity(0.22), Color.teal.opacity(0.22)]) }
    static func neutral(_ s: String) -> ShowcaseDemoPhoto { .init(label: s, colors: [Color.gray.opacity(0.18), Color.indigo.opacity(0.18)]) }
}
private struct Placeholder: View {
    let photo: ShowcaseDemoPhoto; let height: CGFloat; let corner: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(LinearGradient(colors: photo.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(VStack(spacing: 10) {
                Image(systemName: "photo").font(.system(size: 36, weight: .semibold))
                Text(photo.label).font(.system(size: 22, weight: .bold, design: .rounded))
            }.foregroundStyle(.primary.opacity(0.8)))
            .frame(height: height)
    }
}
