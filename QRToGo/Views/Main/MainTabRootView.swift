//
//  MainTabRootView.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import SwiftUI

struct MainTabRootView: View {
    @Bindable var navigationState: AppNavigationState
    let settingsViewModel: SettingsViewModel
    let generateViewModel: GenerateViewModel
    let favoritesViewModel: FavoritesViewModel

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            GenerateView(
                viewModel: generateViewModel,
                settingsViewModel: settingsViewModel,
                favoritesViewModel: favoritesViewModel
            )
                .tabItem {
                    Label("tab.generate", systemImage: "qrcode.viewfinder")
                }
                .tag(MainTab.generate)

            FavoritesView(
                viewModel: favoritesViewModel,
                navigationState: navigationState
            )
                .tabItem {
                    Label("tab.favorites", systemImage: "star.fill")
                }
                .tag(MainTab.favorites)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
                .tag(MainTab.settings)

            AboutView()
                .tabItem {
                    Label("tab.about", systemImage: "info.circle")
                }
                .tag(MainTab.about)
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
    MainTabRootView(
        navigationState: AppNavigationState(),
        settingsViewModel: SettingsViewModel(),
        generateViewModel: GenerateViewModel(),
        favoritesViewModel: FavoritesViewModel()
    )
}
