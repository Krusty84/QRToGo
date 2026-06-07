//
//  FavoritesViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import Observation
import UIKit

@Observable
@MainActor
final class FavoritesViewModel {
    private let store: FavoriteQRCodeStore
    private let generatorService: QRCodeGeneratorService
    private let quickActionService: FavoriteQuickActionService

    var favorites: [FavoriteQRCode] = []
    var statusMessage: String?

    private var hasLoaded = false

    init(
        store: FavoriteQRCodeStore? = nil,
        generatorService: QRCodeGeneratorService? = nil,
        quickActionService: FavoriteQuickActionService? = nil
    ) {
        self.store = store ?? FavoriteQRCodeStore()
        self.generatorService = generatorService ?? QRCodeGeneratorService()
        self.quickActionService = quickActionService ?? FavoriteQuickActionService()
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }
        hasLoaded = true
        favorites = store.loadAllFavorites()
        quickActionService.updateShortcuts(from: favorites)
    }

    func addFavorite(_ favorite: FavoriteQRCode) throws {
        if FavoriteDefaultNames.isDefaultName(favorite.name),
           FavoriteDefaultNames.isUsed(favorite.name, in: favorites)
        {
            throw FavoriteQRCodeValidationError.duplicateDefaultName
        }

        favorites = try store.addFavorite(favorite)
        statusMessage = nil
        quickActionService.updateShortcuts(from: favorites)
    }

    func renameFavorite(id: UUID, name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return
        }

        if FavoriteDefaultNames.isDefaultName(trimmedName) {
            let isUsedByAnotherFavorite = favorites.contains { favorite in
                favorite.id != id
                    && FavoriteDefaultNames.normalized(favorite.name) == FavoriteDefaultNames.normalized(trimmedName)
            }

            if isUsedByAnotherFavorite {
                throw FavoriteQRCodeValidationError.duplicateDefaultName
            }
        }

        favorites = try store.renameFavorite(id: id, name: trimmedName)
        statusMessage = nil
        quickActionService.updateShortcuts(from: favorites)
    }

    func deleteFavorite(id: UUID) throws {
        favorites = try store.deleteFavorite(id: id)
        statusMessage = nil
        quickActionService.updateShortcuts(from: favorites)
    }

    func favorite(id: UUID) -> FavoriteQRCode? {
        favorites.first { $0.id == id }
    }

    func previewImage(for favorite: FavoriteQRCode) throws -> UIImage {
        try generatorService.generate(
            content: favorite.payload,
            settings: favorite.settings,
            outputSize: min(max(favorite.settings.outputSize, 360), 768)
        ).image
    }
}

enum FavoriteQRCodeValidationError: LocalizedError {
    case duplicateDefaultName

    var errorDescription: String? {
        switch self {
        case .duplicateDefaultName:
            AppLocalization.string("favorites.defaultNameAlreadyUsed")
        }
    }
}
