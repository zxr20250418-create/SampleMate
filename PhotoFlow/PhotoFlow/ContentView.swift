//
//  ContentView.swift
//  PhotoFlow
//
//  Created by 郑鑫荣 on 2025/12/30.
//

import SwiftUI

struct ContentView: View {
    @State private var showShowcase: Bool = false
    @State private var showSettings: Bool = false
    @State private var showLibrary: Bool = false
    @AppStorage("onsiteModeEnabled") private var onsiteModeEnabled: Bool = false

    @StateObject private var libraryStore = LocalLibraryStore()

    private let highlights: [Highlight] = [
        Highlight(title: "Golden Hour Walk", subtitle: "24 shots · 6 picks", tone: .warm),
        Highlight(title: "Coffee Shop", subtitle: "12 shots · 3 picks", tone: .cool),
        Highlight(title: "Studio Test", subtitle: "40 shots · 10 picks", tone: .neutral),
        Highlight(title: "Street Notes", subtitle: "18 shots · 5 picks", tone: .warm)
    ]

    private let quickStats: [Stat] = [
        Stat(label: "In review", value: "94"),
        Stat(label: "Picked", value: "26"),
        Stat(label: "Exported", value: "8")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray5)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        statsRow
                        highlightsGrid
                        footer
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showShowcase) {
                ShowcaseView(store: libraryStore)
            }
            .sheet(isPresented: $showSettings) {
                PR1SettingsView()
            }
            .sheet(isPresented: $showLibrary) {
                LibraryView(store: libraryStore)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SampleMate")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("iPad-first review space for fast photo decisions.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ActionChip(title: "home.action.showcase", systemImage: "play.rectangle") {
                    showShowcase = true
                }
                if !onsiteModeEnabled {
                    ActionChip(title: "Library", systemImage: "photo.on.rectangle.angled") {
                        showLibrary = true
                    }
                }
                ActionChip(title: "home.action.settings", systemImage: "gearshape") {
                    showSettings = true
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            ForEach(quickStats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(stat.label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var highlightsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return VStack(alignment: .leading, spacing: 16) {
            Text("Today’s Highlights")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(highlights) { highlight in
                    HighlightCard(highlight: highlight)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next up")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Library, Stats, and Showcase dashboards coming soon.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)
        }
        .padding(16)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}

private struct Highlight: Identifiable {
    enum Tone {
        case warm
        case cool
        case neutral

        var gradient: LinearGradient {
            switch self {
            case .warm:
                return LinearGradient(colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.25)],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing)
            case .cool:
                return LinearGradient(colors: [Color.blue.opacity(0.2), Color.teal.opacity(0.25)],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing)
            case .neutral:
                return LinearGradient(colors: [Color.gray.opacity(0.15), Color.indigo.opacity(0.2)],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing)
            }
        }
    }

    let id = UUID()
    let title: LocalizedStringKey
    let subtitle: String
    let tone: Tone
}

private struct Stat: Identifiable {
    let id = UUID()
    let label: LocalizedStringKey
    let value: String
}

private struct HighlightCard: View {
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(highlight.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(highlight.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(highlight.tone.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ActionChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                }
                .buttonStyle(.plain)
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.95), in: Capsule())
    }
}
