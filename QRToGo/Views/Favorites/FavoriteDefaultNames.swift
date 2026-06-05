//
//  FavoriteDefaultNames.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 05/06/2026.
//

import Foundation

enum FavoriteDefaultNames {
    static let orderedNames = [
        "My Contact",
        "My Emergency",
        "My Target",
        "My Home",
        "My Website"
    ]

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func isDefaultName(_ value: String) -> Bool {
        let normalizedValue = normalized(value)
        return orderedNames.contains {
            normalized($0) == normalizedValue
        }
    }

    static func isUsed(_ name: String, in favorites: [FavoriteQRCode]) -> Bool {
        let normalizedName = normalized(name)
        return favorites.contains {
            normalized($0.name) == normalizedName
        }
    }

    static func availableNames(for favorites: [FavoriteQRCode]) -> [String] {
        orderedNames.filter { name in
            isUsed(name, in: favorites) == false
        }
    }

    static func quickActionSortRank(for name: String) -> Int? {
        let normalizedName = normalized(name)
        return orderedNames.firstIndex {
            normalized($0) == normalizedName
        }
    }
}
