import SwiftUI

struct PR1SettingsView: View {
    @AppStorage("priceVisible") private var priceVisible = true
    @AppStorage("compactTextVisible") private var compactTextVisible = true
    @AppStorage("slideshowEnabled") private var slideshowEnabled = false
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds = 5

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show price row", isOn: $priceVisible)
                Toggle("Show compact text", isOn: $compactTextVisible)
                Toggle("Enable slideshow", isOn: $slideshowEnabled)
                Picker("Slideshow interval", selection: $slideshowIntervalSeconds) {
                    ForEach([2, 3, 5, 8, 10], id: \.self) { seconds in
                        Text("\(seconds)s")
                    }
                }
                .disabled(!slideshowEnabled)
            }
            .navigationTitle("Settings")
        }
    }
}
