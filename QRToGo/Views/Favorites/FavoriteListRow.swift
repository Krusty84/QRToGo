//
//  FavoriteListRow.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct FavoriteListRow: View {
    let favorite: FavoriteQRCode
    let isDeleteConfirmationVisible: Bool
    let onRename: () -> Void
    let onDeleteRequest: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: favorite.id) {
                FavoriteRow(favorite: favorite)
            }

            if isDeleteConfirmationVisible {
                FavoriteInlineDeleteConfirmation(
                    favoriteName: FavoriteDefaultNames.displayName(for: favorite.name),
                    onDelete: onConfirmDelete,
                    onCancel: onCancelDelete
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDeleteRequest()
            } label: {
                Label("favorites.delete", systemImage: "trash")
            }

            Button {
                onRename()
            } label: {
                Label("favorites.rename", systemImage: "pencil")
            }
            .tint(.gray)
        }
    }
}
