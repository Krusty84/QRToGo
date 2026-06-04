//
//  FavoriteShortcutRouter.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import UIKit

@MainActor
final class FavoriteShortcutRouter {
    static let shared = FavoriteShortcutRouter()

    private weak var navigationState: AppNavigationState?
    private var pendingFavoriteID: UUID?

    private init() { }

    func connect(_ navigationState: AppNavigationState) {
        self.navigationState = navigationState

        if let pendingFavoriteID {
            route(to: pendingFavoriteID)
            self.pendingFavoriteID = nil
        }
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard
            shortcutItem.type == FavoriteQuickActionConstants.favoriteType,
            let favoriteIDString = shortcutItem.userInfo?[FavoriteQuickActionConstants.favoriteIDKey] as? String,
            let favoriteID = UUID(uuidString: favoriteIDString)
        else {
            return false
        }

        route(to: favoriteID)
        return true
    }

    private func route(to favoriteID: UUID) {
        guard let navigationState else {
            pendingFavoriteID = favoriteID
            return
        }

        navigationState.quickActionFavoriteID = favoriteID
        navigationState.quickActionPresentationError = nil
    }
}
