//
//  FavoriteDefaultNames.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 05/06/2026.
//

import Foundation

enum FavoriteDefaultNamePreset: CaseIterable {
    case myContact
    case myEmergency
    case myTarget
    case myHome
    case myWebsite

    var titleKey: String {
        switch self {
        case .myContact:
            "favorites.suggestion.myContact"
        case .myEmergency:
            "favorites.suggestion.myEmergency"
        case .myTarget:
            "favorites.suggestion.myTarget"
        case .myHome:
            "favorites.suggestion.myHome"
        case .myWebsite:
            "favorites.suggestion.myWebsite"
        }
    }

    var legacyEnglishName: String {
        switch self {
        case .myContact:
            "My Contact"
        case .myEmergency:
            "My Emergency"
        case .myTarget:
            "My Target"
        case .myHome:
            "My Home"
        case .myWebsite:
            "My Website"
        }
    }

    var localizedName: String {
        AppLocalization.string(titleKey)
    }

    var sortRank: Int {
        Self.allCases.firstIndex(of: self) ?? Int.max
    }

    var knownNames: [String] {
        [
            legacyEnglishName,
            AppLocalization.string(titleKey, language: .english),
            AppLocalization.string(titleKey, language: .simplifiedChinese),
            AppLocalization.string(titleKey, language: .russian)
        ]
    }
}

enum FavoriteDefaultNames {
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func preset(for value: String) -> FavoriteDefaultNamePreset? {
        let normalizedValue = normalized(value)

        return FavoriteDefaultNamePreset.allCases.first { preset in
            preset.knownNames.contains { knownName in
                normalized(knownName) == normalizedValue
            }
        }
    }

    static func isDefaultName(_ value: String) -> Bool {
        preset(for: value) != nil
    }

    static func isUsed(_ name: String, in favorites: [FavoriteQRCode]) -> Bool {
        if let targetPreset = preset(for: name) {
            return favorites.contains { favorite in
                preset(for: favorite.name) == targetPreset
            }
        }

        let normalizedName = normalized(name)

        return favorites.contains { favorite in
            normalized(favorite.name) == normalizedName
        }
    }

    static func availableNames(for favorites: [FavoriteQRCode]) -> [String] {
        FavoriteDefaultNamePreset.allCases
            .filter { preset in
                isUsed(preset.localizedName, in: favorites) == false
            }
            .map(\.localizedName)
    }

    static func quickActionSortRank(for name: String) -> Int? {
        preset(for: name)?.sortRank
    }

    static func displayName(for name: String) -> String {
        preset(for: name)?.localizedName ?? name
    }
}
