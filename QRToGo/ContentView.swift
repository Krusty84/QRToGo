//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var navigationState = AppNavigationState()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var generateViewModel = GenerateViewModel()
    @State private var favoritesViewModel = FavoritesViewModel()

    var body: some View {
        @Bindable var bindableNavigationState = navigationState

        ZStack {
            TabView(selection: $bindableNavigationState.selectedTab) {
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

            quickActionPresentation
        }
        .task {
            settingsViewModel.loadIfNeeded()
            favoritesViewModel.loadIfNeeded()
            FavoriteShortcutRouter.shared.connect(navigationState)
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
            FavoriteQuickActionService().updateShortcuts(from: favoritesViewModel.favorites)
        }
    }

    @ViewBuilder
    private var quickActionPresentation: some View {
        if let favoriteID = navigationState.quickActionFavoriteID {
            if let favorite = favoritesViewModel.favorite(id: favoriteID) {
                FavoriteQuickActionPresentationView(
                    favorite: favorite,
                    onClose: closeQuickActionPresentation
                )
                .transition(.opacity)
                .zIndex(1)
            } else {
                FavoriteQuickActionMissingView(onClose: closeQuickActionPresentation)
                    .transition(.opacity)
                    .zIndex(1)
            }
        } else if navigationState.quickActionPresentationError != nil {
            FavoriteQuickActionMissingView(onClose: closeQuickActionPresentation)
                .transition(.opacity)
                .zIndex(1)
        }
    }

    private func closeQuickActionPresentation() {
        navigationState.quickActionFavoriteID = nil
        navigationState.quickActionPresentationError = nil
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
