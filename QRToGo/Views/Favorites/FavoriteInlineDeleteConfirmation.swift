//
//  FavoriteInlineDeleteConfirmation.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct FavoriteInlineDeleteConfirmation: View {
    let favoriteName: String
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String.localizedStringWithFormat(
                AppLocalization.string("favorites.delete.inlineTitle"),
                favoriteName
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

            Text("favorites.delete.inlineMessage")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("share.cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("favorites.delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            Color.red.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
        .padding(.top, 8)
    }
}
