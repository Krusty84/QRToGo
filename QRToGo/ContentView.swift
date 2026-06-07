//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var navigationState: AppNavigationState
    @State private var settingsViewModel = SettingsViewModel()
    @State private var generateViewModel = GenerateViewModel()
    @State private var favoritesViewModel = FavoritesViewModel()
    @State private var isInitialLoading = true
    @State private var didPerformInitialLoad = false

    init() {
        let launchMode = FavoriteShortcutRouter.shared.initialLaunchMode()
        _navigationState = State(initialValue: AppNavigationState(launchMode: launchMode))
    }

    var body: some View {
        Group {
            if isInitialLoading {
                AppLoadingView()
            } else {
                rootContent
            }
        }
            .task {
                await performInitialLoadIfNeeded()
            }
            .environment(\.locale, settingsViewModel.appLanguage.locale)
            .onChange(of: generateViewModel.contentDraft) { _, _ in
                guard isInitialLoading == false else {
                    return
                }
                generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
            }
            .onChange(of: settingsViewModel.draftSettings) { _, _ in
                guard isInitialLoading == false else {
                    return
                }
                generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
            }
            .onChange(of: settingsViewModel.appLanguage) { _, _ in
                guard isInitialLoading == false else {
                    return
                }
                generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)
                FavoriteQuickActionService().updateShortcuts(from: favoritesViewModel.favorites)
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch navigationState.launchMode {
        case .normal:
            MainTabRootView(
                navigationState: navigationState,
                settingsViewModel: settingsViewModel,
                generateViewModel: generateViewModel,
                favoritesViewModel: favoritesViewModel
            )
        case let .favoriteQuickAction(favoriteID):
            FavoriteQuickActionRootView(
                favoriteID: favoriteID,
                onClose: closeQuickActionPresentation
            )
        }
    }

    private func closeQuickActionPresentation() {
        navigationState.launchMode = .normal
    }

    @MainActor
    private func performInitialLoadIfNeeded() async {
        guard didPerformInitialLoad == false else {
            return
        }
        didPerformInitialLoad = true

        await Task.yield()

        settingsViewModel.loadIfNeeded()
        favoritesViewModel.loadIfNeeded()
        FavoriteShortcutRouter.shared.connect(navigationState)
        generateViewModel.refreshPreview(using: settingsViewModel.draftSettings)

        withAnimation(.easeOut(duration: 0.2)) {
            isInitialLoading = false
        }
    }
}

#Preview {
    ContentView()
}
