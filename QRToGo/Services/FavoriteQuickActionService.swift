//
//  FavoriteQuickActionService.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import UIKit

enum FavoriteQuickActionConstants {
    static let favoriteType = "com.krusty84.QRToGo.favorite"
    static let favoriteIDKey = "favoriteID"
}

@MainActor
final class FavoriteQuickActionService {
    func updateShortcuts(from favorites: [FavoriteQRCode]) {
        let shortcutItems = favorites
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map { favorite in
                UIApplicationShortcutItem(
                    type: FavoriteQuickActionConstants.favoriteType,
                    localizedTitle: favorite.name,
                    localizedSubtitle: AppLocalization.string(favorite.kind.titleKey),
                    icon: UIApplicationShortcutIcon(systemImageName: favorite.kind.systemImage),
                    userInfo: [
                        FavoriteQuickActionConstants.favoriteIDKey: favorite.id.uuidString as NSString
                    ]
                )
            }

        UIApplication.shared.shortcutItems = Array(shortcutItems)
    }
}
