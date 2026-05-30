//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
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
        .environment(\.locale, viewModel.appLanguage.locale)
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
