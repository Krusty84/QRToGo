//
//  FavoriteQRCodeStore.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import Foundation

struct FavoriteQRCodeStore {
    private let userDefaults: UserDefaults
    private let favoritesKey = "favoriteQRCodes"
    private let corruptBackupKey = "favoriteQRCodes.corruptBackup"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadAllFavorites() -> [FavoriteQRCode] {
        guard let data = userDefaults.data(forKey: favoritesKey) else {
            return []
        }

        do {
            return try decoder.decode([FavoriteQRCode].self, from: data).sortedByUpdatedDate()
        } catch {
            userDefaults.set(data, forKey: corruptBackupKey)
            return []
        }
    }

    func addFavorite(_ favorite: FavoriteQRCode) throws -> [FavoriteQRCode] {
        var favorites = loadAllFavorites()
        favorites.append(favorite)
        try save(favorites)
        return favorites.sortedByUpdatedDate()
    }

    func updateFavorite(_ favorite: FavoriteQRCode) throws -> [FavoriteQRCode] {
        var favorites = loadAllFavorites()
        guard let index = favorites.firstIndex(where: { $0.id == favorite.id }) else {
            return favorites
        }
        favorites[index] = favorite
        try save(favorites)
        return favorites.sortedByUpdatedDate()
    }

    func renameFavorite(id: UUID, name: String, updatedAt: Date = .now) throws -> [FavoriteQRCode] {
        var favorites = loadAllFavorites()
        guard let index = favorites.firstIndex(where: { $0.id == id }) else {
            return favorites
        }
        favorites[index].name = name
        favorites[index].updatedAt = updatedAt
        try save(favorites)
        return favorites.sortedByUpdatedDate()
    }

    func deleteFavorite(id: UUID) throws -> [FavoriteQRCode] {
        let favorites = loadAllFavorites().filter { $0.id != id }
        try save(favorites)
        return favorites.sortedByUpdatedDate()
    }

    func findFavorite(id: UUID) -> FavoriteQRCode? {
        loadAllFavorites().first { $0.id == id }
    }

    private func save(_ favorites: [FavoriteQRCode]) throws {
        let data = try encoder.encode(favorites.sortedByUpdatedDate())
        userDefaults.set(data, forKey: favoritesKey)
        userDefaults.synchronize()
    }
}

private extension [FavoriteQRCode] {
    func sortedByUpdatedDate() -> [FavoriteQRCode] {
        sorted { $0.updatedAt > $1.updatedAt }
    }
}
