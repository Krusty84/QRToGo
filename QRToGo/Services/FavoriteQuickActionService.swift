//
//  FavoriteQuickActionService.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
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
            .sorted(by: quickActionSort)
            .prefix(4)
            .map { favorite in
                UIApplicationShortcutItem(
                    type: FavoriteQuickActionConstants.favoriteType,
                    localizedTitle: FavoriteDefaultNames.displayName(for: favorite.name),
                    localizedSubtitle: AppLocalization.string(favorite.kind.titleKey),
                    icon: UIApplicationShortcutIcon(systemImageName: favorite.kind.systemImage),
                    userInfo: [
                        FavoriteQuickActionConstants.favoriteIDKey: favorite.id.uuidString as NSString
                    ]
                )
            }

        UIApplication.shared.shortcutItems = Array(shortcutItems)
    }
    
    private func quickActionSort(_ lhs: FavoriteQRCode, _ rhs: FavoriteQRCode) -> Bool {
        let lhsRank = FavoriteDefaultNames.quickActionSortRank(for: lhs.name)
        let rhsRank = FavoriteDefaultNames.quickActionSortRank(for: rhs.name)

        switch (lhsRank, rhsRank) {
        case let (lhsRank?, rhsRank?):
            return lhsRank < rhsRank

        case (_?, nil):
            return true

        case (nil, _?):
            return false

        case (nil, nil):
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
