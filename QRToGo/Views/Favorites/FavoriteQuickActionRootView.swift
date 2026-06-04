//
//  FavoriteQuickActionRootView.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import SwiftUI

struct FavoriteQuickActionRootView: View {
    let favoriteID: UUID
    let onClose: () -> Void

    @State private var favorite: FavoriteQRCode?
    @State private var loadedFavoriteID: UUID?
    @State private var hasLoadedFavorite = false

    private let store = FavoriteQRCodeStore()

    var body: some View {
        Group {
            if let favorite, loadedFavoriteID == favoriteID {
                FavoriteQuickActionPresentationView(
                    favorite: favorite,
                    onClose: onClose
                )
            } else if hasLoadedFavorite, loadedFavoriteID == favoriteID {
                FavoriteQuickActionMissingView(onClose: onClose)
            } else {
                QuickActionPresentationContainer {
                    ProgressView("favorites.quickAction.loading")
                        .padding(24)
                        .frame(maxWidth: 380)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                        )
                        .padding()
                }
            }
        }
        .task(id: favoriteID) {
            favorite = nil
            loadedFavoriteID = nil
            hasLoadedFavorite = false

            favorite = store.findFavorite(id: favoriteID)
            loadedFavoriteID = favoriteID
            hasLoadedFavorite = true
        }
    }
}

#Preview {
    FavoriteQuickActionRootView(
        favoriteID: UUID(),
        onClose: { }
    )
}
