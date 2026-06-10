//
//  FavoriteRow.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct FavoriteRow: View {
    let favorite: FavoriteQRCode

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(FavoriteDefaultNames.displayName(for: favorite.name))
                    .font(.headline)

                Text(LocalizedStringKey(favorite.kind.titleKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(favorite.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } icon: {
            Image(systemName: favorite.kind.systemImage)
                .foregroundStyle(.tint)
        }
    }
}
