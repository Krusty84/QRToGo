//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GenerateView(viewModel: viewModel)
                .tabItem {
                    Label("tab.generate", systemImage: "qrcode.viewfinder")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }

            AboutView()
                .tabItem {
                    Label("tab.about", systemImage: "info.circle")
                }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            viewModel.refreshSampleTextFromPasteboardIfNeeded()
        }
        .onChange(of: viewModel.sampleText) { _, _ in
            viewModel.refreshPreview()
        }
        .onChange(of: viewModel.contentDraft) { _, _ in
            viewModel.refreshPreview()
        }
        .onChange(of: viewModel.draftSettings) { _, _ in
            viewModel.refreshPreview()
        }
    }
}

private struct AboutView: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle("tab.about")
        }
    }
}

#Preview {
    ContentView()
}
