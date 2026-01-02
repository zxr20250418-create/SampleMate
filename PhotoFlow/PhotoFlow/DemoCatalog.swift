import SwiftUI

struct DemoCategory: Identifiable {
    let id: String
    let name: String
    let note: String
    let sets: [DemoSet]
}

struct DemoSet: Identifiable {
    let id: String
    let name: String
    let photos: [DemoPhoto]
}

struct DemoPhoto: Identifiable {
    let id: String
    let label: String
    let paletteIndex: Int
}

enum DemoCatalog {
    static let categories: [DemoCategory] = [
        DemoCategory(
            id: "cat-a",
            name: "Couples",
            note: "Soft light, gentle motion, relaxed poses.",
            sets: [
                DemoSet(
                    id: "cat-a-set-1",
                    name: "Set 01",
                    photos: makePhotos(prefix: "A1", paletteOffset: 0)
                ),
                DemoSet(
                    id: "cat-a-set-2",
                    name: "Set 02",
                    photos: makePhotos(prefix: "A2", paletteOffset: 3)
                )
            ]
        ),
        DemoCategory(
            id: "cat-b",
            name: "Portraits",
            note: "Clean backdrop, bold contrast, classic framing.",
            sets: [
                DemoSet(
                    id: "cat-b-set-1",
                    name: "Set 01",
                    photos: makePhotos(prefix: "B1", paletteOffset: 6)
                ),
                DemoSet(
                    id: "cat-b-set-2",
                    name: "Set 02",
                    photos: makePhotos(prefix: "B2", paletteOffset: 9)
                )
            ]
        )
    ]

    private static func makePhotos(prefix: String, paletteOffset: Int) -> [DemoPhoto] {
        (0..<3).map { index in
            DemoPhoto(
                id: "\(prefix)-P\(index + 1)",
                label: "\(prefix)-0\(index + 1)",
                paletteIndex: paletteOffset + index
            )
        }
    }
}

enum DemoPalette {
    static let palettes: [[Color]] = [
        [Color(red: 0.97, green: 0.78, blue: 0.62), Color(red: 0.93, green: 0.49, blue: 0.40)],
        [Color(red: 0.89, green: 0.76, blue: 0.96), Color(red: 0.63, green: 0.56, blue: 0.93)],
        [Color(red: 0.62, green: 0.82, blue: 0.92), Color(red: 0.34, green: 0.62, blue: 0.84)],
        [Color(red: 0.95, green: 0.90, blue: 0.64), Color(red: 0.79, green: 0.68, blue: 0.36)],
        [Color(red: 0.80, green: 0.90, blue: 0.78), Color(red: 0.50, green: 0.72, blue: 0.58)],
        [Color(red: 0.94, green: 0.73, blue: 0.84), Color(red: 0.82, green: 0.45, blue: 0.67)]
    ]

    static func colors(for index: Int) -> [Color] {
        let safeIndex = abs(index) % palettes.count
        return palettes[safeIndex]
    }
}

struct PlaceholderPhotoView: View {
    let photo: DemoPhoto
    var cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            LinearGradient(colors: DemoPalette.colors(for: photo.paletteIndex),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .semibold))
                Text(photo.label)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
