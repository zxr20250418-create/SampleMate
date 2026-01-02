import SwiftUI

struct PR1SettingsView: View {
    @AppStorage("priceVisible") private var priceVisible = true
    @AppStorage("compactTextVisible") private var compactTextVisible = true

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show price row", isOn: $priceVisible)
                Toggle("Show compact text", isOn: $compactTextVisible)
            }
            .navigationTitle("Settings")
        }
    }
}
