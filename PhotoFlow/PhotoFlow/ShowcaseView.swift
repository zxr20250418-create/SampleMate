import SwiftUI

struct ShowcaseView: View {
    @ObservedObject var store: LocalLibraryStore

    @AppStorage("priceVisible") private var priceVisible: Bool = true
    @AppStorage("compactTextVisible") private var compactTextVisible: Bool = true
    @AppStorage("showcasePageTransitionStyle") private var pageTransitionStyleRaw: String = "fade"
    @AppStorage("compactBottomBoardModeRaw") private var compactBottomBoardModeRaw: String = "text"
    @AppStorage("compactBottomBoardScale") private var compactBottomBoardScale: Double = 1.0
    @AppStorage("compactBottomBoardImagePath") private var compactBottomBoardImagePath: String = ""
    @AppStorage("slideshowEnabled") private var slideshowEnabled: Bool = false
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds: Int = 5
    @AppStorage("showcaseTagFilterMode") private var filterModeRaw: String = FilterMode.or.rawValue
    @AppStorage("showcaseTagFilterIds") private var selectedTagIdsRaw: String = ""
    @AppStorage("showcaseFullscreenBackgroundStyle") private var bgStyleRaw: String = "blur"

    @State private var isFullscreen = false
    @State private var overlaysVisible = true
    @State private var categoryIndex = 0
    @State private var setIndex = 0
    @State private var photoIndex = 0
    @State private var selectedTagIds: Set<String> = []
    @State private var showTagSheet = false
    @State private var showPresetSheet = false
    @State private var showBgPickerSheet = false
    @State private var showPresetNamePrompt = false
    @State private var presetName: String = ""
    @State private var showRenamePresetPrompt = false
    @State private var renamePresetID: String?
    @State private var renamePresetName: String = ""
    @State private var showDeletePresetPrompt = false
    @State private var deletePresetID: String?
    @State private var isSlideshowPlaying = false
    @State private var slideshowTimer: Timer?
    @State private var overlayAutoHideTask: Task<Void, Never>?
    @State private var filmstripRequested = false
    @State private var manualTransitionID = UUID()
    @GestureState private var isHorizontalPaging = false

    @Environment(\.scenePhase) private var scenePhase

    private let catalog = ShowcaseDemoCatalog.sample
    private let photoAspect: CGFloat = 2.0 / 3.0
    private let overlayAutoHideSeconds: Double = 2.5

    private struct DisplayPhoto: Identifiable {
        let id: String
        let source: PhotoSource
    }

    private enum PhotoSource {
        case local(LocalLibraryStore.Item)
        case demo(ShowcaseDemoPhoto)
    }

    private enum FilterMode: String {
        case or
        case and
    }

    private enum PageTransitionStyle: String {
        case none
        case fade
        case fadeScale
    }

    private enum CompactBottomBoardMode: String {
        case text
        case image
    }

    private enum FullscreenBackgroundStyle: String, CaseIterable {
        case blur
        case black
        case gray
        case charcoal
        case paper

        var title: String {
            switch self {
            case .blur:
                return "Blur"
            case .black:
                return "Black"
            case .gray:
                return "Gray"
            case .charcoal:
                return "Charcoal"
            case .paper:
                return "纸白"
            }
        }
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
        let filteredSets = filterSetsByTag(setsForCategory)
        let activeSet = filteredSets[safe: setIndex]
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
        let categoryEmpty = (usesCategories || usesSets) && filteredSets.isEmpty
        let selectedTagName = tagFilterTitle()
        let activePhotoID = displayPhotos[safe: photoIndex]?.id ?? "empty"

        GeometryReader { proxy in
            let size = proxy.size
            let thumbnailHeight: CGFloat = 102
            let filmstripFrameHeight: CGFloat = thumbnailHeight + 20
            let mainHeight = isFullscreen ? size.height * 0.72 : size.height * 0.42
            let shouldShowFilmstrip = isFullscreen
                ? (filmstripRequested && !isSlideshowPlaying && !isHorizontalPaging)
                : true
            let filmstripHeightFull: CGFloat = 112
            let shelfPadding: CGFloat = 12
            let shelfHeight: CGFloat = filmstripHeightFull + shelfPadding * 2

            ZStack {
                if isFullscreen {
                    fullscreenBackgroundView(photo: displayPhotos[safe: photoIndex])
                } else {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                }
                VStack(spacing: 16) {
                    if !isFullscreen {
                        headerBar(categoryName: categoryName,
                                  setTitle: setTitle,
                                  tagTitle: selectedTagName,
                                  photosCount: displayPhotos.count)
                            .padding(.horizontal, 20)
                    }

                    ZStack(alignment: .center) {
                        Group {
                            Group {
                                if categoryEmpty {
                                    categoryEmptyView(height: mainHeight)
                                } else if let photo = displayPhotos[safe: photoIndex] {
                                    mainPhotoView(photo: photo, height: mainHeight, isFullscreen: isFullscreen)
                                } else {
                                    fallbackMainPhoto(height: mainHeight, isFullscreen: isFullscreen)
                                }
                            }
                            .id(activePhotoID)
                            .transition(isSlideshowPlaying ? .opacity : .identity)
                            .animation(isFullscreen && isSlideshowPlaying ? .easeInOut(duration: 0.18) : nil,
                                       value: activePhotoID)
                        }
                        .id(manualTransitionID)
                        .transition(manualTransition)
                        .contentShape(Rectangle())
                        .highPriorityGesture(dragGesture())
                        .simultaneousGesture(pinchGesture())
                        .simultaneousGesture(TapGesture().onEnded {
                            guard isFullscreen else { return }
                            if isSlideshowPlaying {
                                stopSlideshowAndRevealFilmstrip()
                            } else {
                                let next = !filmstripRequested
                                filmstripRequested = next
                                overlaysVisible = next
                                if next { scheduleOverlayAutoHide() }
                                else { cancelOverlayAutoHide() }
                            }
                        })
                        .animation(isFullscreen ? .easeInOut(duration: 0.20) : nil, value: manualTransitionID)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .overlay(alignment: .top) {
                        if isFullscreen && overlaysVisible && !isSlideshowPlaying {
                            fullscreenPillBar(categoryName: categoryName,
                                              setTitle: setTitle,
                                              photosCount: displayPhotos.count)
                                .padding(.top, 12)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isFullscreen && isSlideshowPlaying {
                            Button {
                                stopSlideshowAndRevealFilmstrip()
                            } label: {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                        }
                    }

                    if !isFullscreen {
                        filmstrip(photos: displayPhotos, height: thumbnailHeight)
                            .padding(.horizontal, 20)
                            .background {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.ultraThinMaterial)
                                    .allowsHitTesting(false)
                            }
                        compactBottomBoard(note: setNote, priceText: priceText)
                    } else {
                        Spacer(minLength: shelfHeight)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .overlay(alignment: .bottom) {
                    if isFullscreen {
                        filmstripTray(photos: displayPhotos, height: filmstripHeightFull)
                            .frame(height: filmstripHeightFull)
                            .padding(.horizontal, 12)
                            .padding(.bottom, shelfPadding)
                            .opacity(shouldShowFilmstrip ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: filmstripRequested)
                            .animation(nil, value: isHorizontalPaging)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncSelectedTagsFromStorage()
        }
        .sheet(isPresented: $showTagSheet) {
            tagPickerSheet
        }
        .sheet(isPresented: $showPresetSheet) {
            presetSheet
        }
        .sheet(isPresented: $showBgPickerSheet) {
            List {
                ForEach(FullscreenBackgroundStyle.allCases, id: \.self) { style in
                    Button {
                        bgStyleRaw = style.rawValue
                        showBgPickerSheet = false
                    } label: {
                        HStack {
                            Text(style.title)
                            Spacer()
                            if bgStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert("保存为预设", isPresented: $showPresetNamePrompt) {
            TextField("Name", text: $presetName)
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                _ = store.createPreset(name: name,
                                       mode: filterMode.rawValue,
                                       tagIds: selectedTagIds.sorted())
                presetName = ""
            }
            Button("Cancel", role: .cancel) {
                presetName = ""
            }
        }
        .alert("重命名预设", isPresented: $showRenamePresetPrompt) {
            TextField("Name", text: $renamePresetName)
            Button("Save") {
                let name = renamePresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let id = renamePresetID, !name.isEmpty else { return }
                store.renamePreset(id: id, name: name)
                renamePresetID = nil
                renamePresetName = ""
            }
            Button("Cancel", role: .cancel) {
                renamePresetID = nil
                renamePresetName = ""
            }
        }
        .alert("删除预设？", isPresented: $showDeletePresetPrompt) {
            Button("Delete", role: .destructive) {
                if let id = deletePresetID {
                    store.deletePreset(id: id)
                }
                deletePresetID = nil
            }
            Button("Cancel", role: .cancel) {
                deletePresetID = nil
            }
        }
        .onChange(of: isFullscreen) { value in
            if value {
                overlaysVisible = true
                filmstripRequested = false
                if slideshowEnabled {
                    startSlideshow(photosCount: displayPhotos.count)
                } else {
                    scheduleOverlayAutoHide()
                }
            } else {
                pauseSlideshow()
                cancelOverlayAutoHide()
                overlaysVisible = true
                filmstripRequested = false
            }
        }
        .onChange(of: slideshowIntervalSeconds) { _ in
            if isSlideshowPlaying { startSlideshow(photosCount: displayPhotos.count) }
        }
        .onChange(of: slideshowEnabled) { value in
            if !value {
                pauseSlideshow()
                if isFullscreen {
                    overlaysVisible = true
                    scheduleOverlayAutoHide()
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                pauseSlideshow()
                cancelOverlayAutoHide()
            }
        }
        .onChange(of: store.items.count) { _ in
            if photoIndex >= displayPhotos.count { photoIndex = 0 }
        }
        .onChange(of: selectedTagIds) { _ in
            selectedTagIdsRaw = selectedTagIds.sorted().joined(separator: ",")
            applyTagFilterSelection()
        }
        .onChange(of: filterModeRaw) { _ in
            applyTagFilterSelection()
        }
        .onChange(of: store.categories) { _ in
            pauseSlideshow()
            let categories = categoriesSorted()
            if categoryIndex >= categories.count { categoryIndex = 0 }
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                let filteredSets = filterSetsByTag(setsForCategory)
                setIndex = 0
                syncPhotoIndex(mainID: filteredSets.first?.mainPhotoID,
                               photos: displayPhotosForSet(filteredSets.first))
            }
        }
        .onChange(of: categoryIndex) { _ in
            stopSlideshowOnly()
            let categories = categoriesSorted()
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                let filteredSets = filterSetsByTag(setsForCategory)
                setIndex = 0
                syncPhotoIndex(mainID: filteredSets.first?.mainPhotoID,
                               photos: displayPhotosForSet(filteredSets.first))
            }
        }
        .onChange(of: store.sets) { _ in
            pauseSlideshow()
            let categories = categoriesSorted()
            if !categories.isEmpty {
                let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
                let filteredSets = filterSetsByTag(setsForCategory)
                if setIndex >= filteredSets.count { setIndex = 0 }
                let activeSet = filteredSets[safe: setIndex]
                syncPhotoIndex(mainID: activeSet?.mainPhotoID,
                               photos: displayPhotosForSet(activeSet))
            } else if !store.sets.isEmpty {
                let filteredSets = filterSetsByTag(store.sets)
                if setIndex >= filteredSets.count { setIndex = 0 }
                let activeSet = filteredSets[safe: setIndex]
                syncPhotoIndex(mainID: activeSet?.mainPhotoID,
                               photos: displayPhotosForSet(activeSet))
            }
        }
    }

    private var tagPickerSheet: some View {
        let tags = store.tags.sorted { $0.sortIndex < $1.sortIndex }
        return NavigationStack {
            List {
                Section {
                    Picker("筛选模式", selection: Binding(
                        get: { filterMode },
                        set: { filterModeRaw = $0.rawValue }
                    )) {
                        Text("OR").tag(FilterMode.or)
                        Text("AND").tag(FilterMode.and)
                    }
                    .pickerStyle(.segmented)
                }
                Button {
                    selectedTagIds.removeAll()
                } label: {
                    HStack {
                        Text("全部（清空）")
                        Spacer()
                        if selectedTagIds.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(tags) { tag in
                    let isSelected = selectedTagIds.contains(tag.id)
                    Button {
                        if isSelected {
                            selectedTagIds.remove(tag.id)
                        } else {
                            selectedTagIds.insert(tag.id)
                        }
                    } label: {
                        HStack {
                            Text(tag.name)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func headerBar(categoryName: String, setTitle: String, tagTitle: String, photosCount: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(setTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showTagSheet = true
            } label: {
                Text("标签：\(tagTitle)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                showPresetSheet = true
            } label: {
                Text("预设")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Text("\(min(photoIndex + 1, photosCount))/\(max(photosCount, 1))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.9), in: Capsule())
                Button {
                    userPressedPlayPause(photosCount: photosCount)
                } label: {
                    Image(systemName: isSlideshowPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
                Text(isFullscreen ? "Full" : "Compact")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white, in: Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private func fullscreenPillBar(categoryName: String, setTitle: String, photosCount: Int) -> some View {
        let content = HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(setTitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(min(photoIndex + 1, photosCount))/\(max(photosCount, 1))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Button {
                userPressedPlayPause(photosCount: photosCount)
            } label: {
                Image(systemName: isSlideshowPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .padding(6)
                    .background(.white.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                showBgPickerSheet = true
            } label: {
                Image(systemName: "paintbrush")
                    .font(.system(size: 10, weight: .bold))
                    .padding(6)
                    .background(.white.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(.ultraThinMaterial).allowsHitTesting(false)
        }
        .frame(maxWidth: 520)
        return HStack {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
    }

    private var presetSheet: some View {
        let presets = store.presets.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.createdAt > $1.createdAt
        }
        return NavigationStack {
            List {
                Section {
                    Button {
                        presetName = ""
                        showPresetNamePrompt = true
                    } label: {
                        Text("保存当前为预设")
                    }
                }
                Section("Presets") {
                    if presets.isEmpty {
                        Text("暂无预设")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(presets) { preset in
                            Button {
                                applyPreset(preset)
                                showPresetSheet = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.name)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        Text("\(preset.mode.uppercased()) · \(preset.tagIds.count) tags")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if preset.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contextMenu {
                                Button(preset.isPinned ? "取消置顶" : "置顶") {
                                    store.togglePinPreset(id: preset.id)
                                }
                                Button("重命名") {
                                    renamePresetID = preset.id
                                    renamePresetName = preset.name
                                    showRenamePresetPrompt = true
                                }
                                Button("删除", role: .destructive) {
                                    deletePresetID = preset.id
                                    showDeletePresetPrompt = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func fullscreenBackgroundView(photo: DisplayPhoto?) -> some View {
        Group {
            switch bgStyle {
            case .blur:
                if let photo {
                    fullscreenBlurBackground(photo: photo)
                } else {
                    Color.black
                }
            case .black:
                Color.black
            case .gray:
                Color(white: 0.12)
            case .charcoal:
                Color(white: 0.06)
            case .paper:
                Color(white: 0.96)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func fullscreenBlurBackground(photo: DisplayPhoto) -> some View {
        switch photo.source {
        case .local(let item):
            if let image = store.image(at: item.photoPath) ?? store.thumbnail(at: item.thumbPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 30)
                    .brightness(-0.2)
                    .saturation(0.9)
                    .clipped()
            } else {
                Color.black
            }
        case .demo(let demo):
            LinearGradient(colors: demo.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 28)
                .brightness(-0.2)
                .saturation(0.9)
        }
    }

    private func mainPhotoView(photo: DisplayPhoto, height: CGFloat, isFullscreen: Bool) -> some View {
        photoView(photo: photo, height: height, corner: isFullscreen ? 22 : 20, useThumbnail: false)
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .frame(height: height)
    }

    private func fallbackMainPhoto(height: CGFloat, isFullscreen: Bool) -> some View {
        RoundedRectangle(cornerRadius: isFullscreen ? 22 : 20)
            .fill(Color.gray.opacity(0.16))
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .frame(height: height)
    }

    private func categoryEmptyView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.12))
            .aspectRatio(photoAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .center)
            .overlay(
                VStack(spacing: 6) {
                    Text("暂无匹配套图")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("请切换标签或分类")
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
                        stopSlideshowOnly()
                        photoIndex = idx
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func filmstripTray(photos: [DisplayPhoto], height: CGFloat) -> some View {
        filmstrip(photos: photos, height: height)
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func compactBottomBoard(note: String, priceText: String) -> some View {
        switch compactBottomBoardMode {
        case .text:
            if compactTextVisible {
                showcaseCard(note: note, priceText: priceText)
                    .padding(.horizontal, 20)
            } else {
                EmptyView()
            }
        case .image:
            compactBottomBoardImageView()
                .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func compactBottomBoardImageView() -> some View {
        if let image = compactBottomBoardImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(compactBottomBoardScale)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
        } else {
            Text("未选择讲解板图片（去设置里选择）")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
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
        DragGesture(minimumDistance: 18)
            .updating($isHorizontalPaging) { value, state, _ in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy), abs(dx) > 24 {
                    state = true
                }
            }
            .onChanged { value in
                guard isFullscreen else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy), abs(dx) > 24 {
                    filmstripRequested = false
                }
            }
            .onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                if abs(dx) > abs(dy) {
                    if dx <= -60 {
                        stopSlideshowOnly()
                        manualTransitionID = UUID()
                        nextSet(1)
                    } else if dx >= 60 {
                        stopSlideshowOnly()
                        manualTransitionID = UUID()
                        nextSet(-1)
                    }
                } else {
                    if dy <= -60 {
                        stopSlideshowOnly()
                        manualTransitionID = UUID()
                        nextCategory(1)
                    } else if dy >= 60 {
                        stopSlideshowOnly()
                        manualTransitionID = UUID()
                        nextCategory(-1)
                    }
                }
            }
    }

    private func pinchGesture() -> some Gesture {
        MagnificationGesture().onEnded { value in
            if value > 1.08 { stopSlideshowOnly(); isFullscreen = true }
            else if value < 0.92 { stopSlideshowOnly(); isFullscreen = false }
        }
    }

    private func startSlideshow(photosCount: Int) {
        guard photosCount > 0 else { return }
        pauseSlideshow()
        isSlideshowPlaying = true
        overlaysVisible = false
        filmstripRequested = false
        cancelOverlayAutoHide()
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(slideshowIntervalSeconds), repeats: true) { _ in
            advancePhoto(photosCount: photosCount)
        }
    }

    private func pauseSlideshow() {
        isSlideshowPlaying = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }

    private func scheduleOverlayAutoHide() {
        cancelOverlayAutoHide()
        guard isFullscreen, !isSlideshowPlaying, filmstripRequested else { return }
        overlayAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(overlayAutoHideSeconds * 1_000_000_000))
            await MainActor.run {
                guard isFullscreen, !isSlideshowPlaying else { return }
                overlaysVisible = false
                filmstripRequested = false
            }
        }
    }

    private func cancelOverlayAutoHide() {
        overlayAutoHideTask?.cancel()
        overlayAutoHideTask = nil
    }

    private func stopSlideshowAndRevealFilmstrip() {
        pauseSlideshow()
        overlaysVisible = true
        filmstripRequested = true
        scheduleOverlayAutoHide()
    }

    private func stopSlideshowOnly() {
        pauseSlideshow()
        cancelOverlayAutoHide()
    }

    private func userPressedPlayPause(photosCount: Int) {
        if isSlideshowPlaying {
            pauseSlideshow()
            return
        }
        if !isFullscreen { isFullscreen = true }
        startSlideshow(photosCount: photosCount)
        overlaysVisible = false
        filmstripRequested = false
        cancelOverlayAutoHide()
    }

    private func advancePhoto(photosCount: Int) {
        guard photosCount > 0 else { return }
        photoIndex = (photoIndex + 1) % photosCount
    }

    private func nextCategory(_ d: Int) {
        stopSlideshowOnly()
        let categories = categoriesSorted()
        if !categories.isEmpty {
            let c = categories.count
            categoryIndex = (categoryIndex + d + c) % c
            let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
            let filteredSets = filterSetsByTag(setsForCategory)
            setIndex = 0
            syncPhotoIndex(mainID: filteredSets.first?.mainPhotoID,
                           photos: displayPhotosForSet(filteredSets.first))
            return
        }
        if !store.sets.isEmpty { return }
        let c = catalog.categories.count
        categoryIndex = (categoryIndex + d + c) % c
        setIndex = 0
        photoIndex = 0
    }

    private func nextSet(_ d: Int) {
        stopSlideshowOnly()
        let categories = categoriesSorted()
        if !categories.isEmpty {
            let setsForCategory = store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
            let filteredSets = filterSetsByTag(setsForCategory)
            let s = filteredSets.count
            if s == 0 { return }
            setIndex = (setIndex + d + s) % s
            let activeSet = filteredSets[safe: setIndex]
            syncPhotoIndex(mainID: activeSet?.mainPhotoID, photos: displayPhotosForSet(activeSet))
            return
        }
        if !store.sets.isEmpty {
            let filteredSets = filterSetsByTag(store.sets)
            let s = filteredSets.count
            if s == 0 { return }
            setIndex = (setIndex + d + s) % s
            let activeSet = filteredSets[safe: setIndex]
            syncPhotoIndex(mainID: activeSet?.mainPhotoID,
                           photos: displayPhotosForSet(activeSet))
            return
        }
        let s = catalog.categories[categoryIndex].sets.count
        setIndex = (setIndex + d + s) % s
        photoIndex = 0
    }

    private func categoriesSorted() -> [LocalLibraryStore.DisplayCategory] {
        store.categories.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var filterMode: FilterMode {
        FilterMode(rawValue: filterModeRaw) ?? .or
    }

    private var pageTransitionStyle: PageTransitionStyle {
        PageTransitionStyle(rawValue: pageTransitionStyleRaw) ?? .fade
    }

    private var manualTransition: AnyTransition {
        switch pageTransitionStyle {
        case .none:
            return .identity
        case .fade:
            return .opacity
        case .fadeScale:
            return .opacity.combined(with: .scale(scale: 0.99))
        }
    }

    private var compactBottomBoardMode: CompactBottomBoardMode {
        CompactBottomBoardMode(rawValue: compactBottomBoardModeRaw) ?? .text
    }

    private var bgStyle: FullscreenBackgroundStyle {
        FullscreenBackgroundStyle(rawValue: bgStyleRaw) ?? .blur
    }

    private func compactBottomBoardImage() -> UIImage? {
        guard !compactBottomBoardImagePath.isEmpty else { return nil }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(compactBottomBoardImagePath)
        return UIImage(contentsOfFile: url.path)
    }

    private func syncSelectedTagsFromStorage() {
        let ids = selectedTagIdsRaw.split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
        selectedTagIds = Set(ids)
    }

    private func applyPreset(_ preset: LocalLibraryStore.FilterPreset) {
        stopSlideshowOnly()
        filterModeRaw = preset.mode
        selectedTagIds = Set(preset.tagIds)
        selectedTagIdsRaw = preset.tagIds.joined(separator: ",")
        applyTagFilterSelection()
    }

    private func applyTagFilterSelection() {
        stopSlideshowOnly()
        let categories = categoriesSorted()
        let setsForCategory = !categories.isEmpty
            ? store.sets.filter { $0.categoryId == categories[safe: categoryIndex]?.id }
            : store.sets
        let filteredSets = filterSetsByTag(setsForCategory)
        setIndex = 0
        syncPhotoIndex(mainID: filteredSets.first?.mainPhotoID,
                       photos: displayPhotosForSet(filteredSets.first))
    }

    private func filterSetsByTag(_ sets: [LocalLibraryStore.SampleSet]) -> [LocalLibraryStore.SampleSet] {
        guard !selectedTagIds.isEmpty else { return sets }
        switch filterMode {
        case .or:
            return sets.filter { set in
                store.setTagLinks.contains { $0.setId == set.id && selectedTagIds.contains($0.tagId) }
            }
        case .and:
            return sets.filter { set in
                let linkedTagIds = Set(store.setTagLinks.filter { $0.setId == set.id }.map { $0.tagId })
                return selectedTagIds.allSatisfy { linkedTagIds.contains($0) }
            }
        }
    }

    private func tagFilterTitle() -> String {
        let count = selectedTagIds.count
        if count == 0 { return "全部" }
        if count == 1, let tagId = selectedTagIds.first {
            return store.tags.first(where: { $0.id == tagId })?.name ?? "全部"
        }
        return "已选 \(count)"
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
