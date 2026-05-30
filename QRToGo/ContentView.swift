//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var settingsViewModel = SettingsViewModel()
    @State private var generateViewModel = GenerateViewModel()

    var body: some View {
        TabView {
            GenerateView(
                viewModel: generateViewModel,
                settingsViewModel: settingsViewModel
            )
                .tabItem {
                    Label("tab.generate", systemImage: "qrcode.viewfinder")
                }

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }

            AboutView()
                .tabItem {
                    Label("tab.about", systemImage: "info.circle")
                }
        }
        .task {
            settingsViewModel.loadIfNeeded()
            generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
        }
        .environment(\.locale, settingsViewModel.appLanguage.locale)
        .onChange(of: generateViewModel.contentDraft) { _, _ in
            generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
        }
        .onChange(of: settingsViewModel.draftSettings) { _, _ in
            generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
        }
        .onChange(of: settingsViewModel.appLanguage) { _, _ in
            generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
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
