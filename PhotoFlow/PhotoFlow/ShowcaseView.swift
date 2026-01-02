import SwiftUI

struct ShowcaseView: View {
    @AppStorage("priceVisible") private var priceVisible: Bool = true

    @State private var isFullscreen = false
    @State private var categoryIndex = 0
    @State private var setIndex = 0
    @State private var photoIndex = 0

    private let catalog = ShowcaseDemoCatalog.sample

    var body: some View {
        let category = catalog.categories[categoryIndex]
        let set = category.sets[setIndex]
        let photos = set.photos

        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name).font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(set.title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(isFullscreen ? "Full" : "Compact")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .padding(.horizontal, 20)

                if isFullscreen {
                    Placeholder(photo: photos[photoIndex], height: 520, corner: 22).padding(.horizontal, 20)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Placeholder(photo: photos[photoIndex], height: 320, corner: 18).padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { idx, p in
                                    Button { photoIndex = idx } label: {
                                        Placeholder(photo: p, height: 86, corner: 12)
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(idx == photoIndex ? Color.primary.opacity(0.75) : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Showcase").font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text(set.note).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary)

                            if priceVisible {
                                HStack(spacing: 10) {
                                    Text("Package").foregroundStyle(.secondary)
                                    Text(set.priceText).fontWeight(.bold)
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                        }
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
        }
        .gesture(dragGesture())
        .gesture(pinchGesture())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 18).onEnded { v in
            let dx = v.translation.width, dy = v.translation.height
            if abs(dx) > abs(dy) {
                if dx <= -60 { nextSet(1) } else if dx >= 60 { nextSet(-1) }
            } else {
                if dy <= -60 { nextCategory(1) } else if dy >= 60 { nextCategory(-1) }
            }
        }
    }

    private func pinchGesture() -> some Gesture {
        MagnificationGesture().onEnded { value in
            if value > 1.08 { isFullscreen = true }
            else if value < 0.92 { isFullscreen = false }
        }
    }

    private func nextCategory(_ d: Int) {
        let c = catalog.categories.count
        categoryIndex = (categoryIndex + d + c) % c
        setIndex = 0
        photoIndex = 0
    }

    private func nextSet(_ d: Int) {
        let s = catalog.categories[categoryIndex].sets.count
        setIndex = (setIndex + d + s) % s
        photoIndex = 0
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
