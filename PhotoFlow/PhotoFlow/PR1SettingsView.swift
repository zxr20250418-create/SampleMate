import SwiftUI

struct PR1SettingsView: View {
    @AppStorage("priceVisible") private var priceVisible = true

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show price row", isOn: $priceVisible)
            }
            .navigationTitle("Settings")
        }
    }
}
