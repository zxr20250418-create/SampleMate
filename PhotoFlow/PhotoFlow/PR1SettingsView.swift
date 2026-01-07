import SwiftUI
import PhotosUI
import UIKit

struct PR1SettingsView: View {
    private let compactBottomBoardFilename = "compact_bottom_board.png"

    @AppStorage("priceVisible") private var priceVisible = true
    @AppStorage("compactTextVisible") private var compactTextVisible = true
    @AppStorage("showcasePageTransitionStyle") private var showcasePageTransitionStyle = "fade"
    @AppStorage("compactBottomBoardModeRaw") private var compactBottomBoardModeRaw = "text"
    @AppStorage("compactBottomBoardScale") private var compactBottomBoardScale: Double = 1.0
    @AppStorage("compactBottomBoardImagePath") private var compactBottomBoardImagePath = ""
    @AppStorage("slideshowEnabled") private var slideshowEnabled = false
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds = 5
    @AppStorage("onsiteModeEnabled") private var onsiteModeEnabled: Bool = false
    @State private var compactBottomBoardItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show price row", isOn: $priceVisible)
                Toggle("Show compact text", isOn: $compactTextVisible)
                Picker("手动切换过渡", selection: $showcasePageTransitionStyle) {
                    Text("无").tag("none")
                    Text("淡入").tag("fade")
                    Text("淡入+微缩放").tag("fadeScale")
                }
                .pickerStyle(.segmented)
                Picker("讲解板模式", selection: $compactBottomBoardModeRaw) {
                    Text("文字").tag("text")
                    Text("图片").tag("image")
                }
                .pickerStyle(.segmented)
                PhotosPicker(selection: $compactBottomBoardItem, matching: .images) {
                    Text("选择讲解板图片")
                }
                .onChange(of: compactBottomBoardItem) { newItem in
                    guard let newItem else { return }
                    Task {
                        guard let data = try? await newItem.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        saveCompactBottomBoardImage(image)
                        await MainActor.run {
                            compactBottomBoardImagePath = compactBottomBoardFilename
                        }
                    }
                }
                HStack {
                    Text("讲解板大小")
                    Spacer()
                    Text(String(format: "%.2f", compactBottomBoardScale))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $compactBottomBoardScale, in: 0.6...1.6)
                Button("清除图片", role: .destructive) {
                    deleteCompactBottomBoardImage()
                    compactBottomBoardImagePath = ""
                }
                .disabled(compactBottomBoardImagePath.isEmpty)
                Toggle("Enable slideshow", isOn: $slideshowEnabled)
                Picker("Slideshow interval", selection: $slideshowIntervalSeconds) {
                    ForEach([2, 3, 5, 8, 10], id: \.self) { seconds in
                        Text("\(seconds)s")
                    }
                }
                .disabled(!slideshowEnabled)
                Toggle("现场模式", isOn: $onsiteModeEnabled)
                Text("开启后隐藏管理入口，仅用于现场展示")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("settings.title")
        }
    }

    private func compactBottomBoardURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(compactBottomBoardFilename)
    }

    private func saveCompactBottomBoardImage(_ image: UIImage) {
        let url = compactBottomBoardURL()
        if let data = image.pngData() ?? image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func deleteCompactBottomBoardImage() {
        let url = compactBottomBoardURL()
        try? FileManager.default.removeItem(at: url)
    }
}
