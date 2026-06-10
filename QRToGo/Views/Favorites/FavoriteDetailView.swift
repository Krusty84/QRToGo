//
//  FavoriteDetailView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI
import UIKit

struct FavoriteDetailView: View {
    let viewModel: FavoritesViewModel
    let favoriteID: UUID
    let onDelete: () -> Void

    @State private var previewImage: UIImage?
    @State private var previewErrorMessage: String?
    @State private var isGeneratingPreview = false
    @State private var isRenamePresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        if let favorite = viewModel.favorite(id: favoriteID) {
            let displayName = FavoriteDefaultNames.displayName(for: favorite.name)
            Form {
                Section("favorites.preview") {
                    QRPreviewView(
                        image: previewImage,
                        isLoading: isGeneratingPreview,
                        errorMessage: previewErrorMessage
                    )
                }

                Section {
                    LabeledContent("favorites.name", value: displayName)
                    LabeledContent("export.card.type") {
                        Label(
                            LocalizedStringKey(favorite.kind.titleKey),
                            systemImage: favorite.kind.systemImage
                        )
                    }

                    if let exportPurpose = favorite.exportPurpose {
                        LabeledContent("export.card.purpose", value: exportPurpose)
                    }

                    LabeledContent(
                        "export.card.created",
                        value: favorite.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(
                        "favorites.updated",
                        value: favorite.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .navigationTitle(displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("favorites.rename", systemImage: "pencil") {
                            isRenamePresented = true
                        }

                        Button("favorites.delete", systemImage: "trash", role: .destructive) {
                            isDeleteConfirmationPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(Text("favorites.title"))
                }
            }
            .task(id: favorite) {
                generatePreview(for: favorite)
            }
            .sheet(isPresented: $isRenamePresented) {
                FavoriteRenameSheet(initialName: displayName) { name in
                    renameFavorite(to: name)
                }
            }
            .confirmationDialog(
                "favorites.delete.confirm",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("favorites.delete", role: .destructive) {
                    deleteFavorite()
                }

                Button("share.cancel", role: .cancel) { }
            } message: {
                Text("favorites.delete.message")
            }
        } else {
            ContentUnavailableView(
                AppLocalization.string("favorites.open.missing"),
                systemImage: "star.slash"
            )
        }
    }

    private func generatePreview(for favorite: FavoriteQRCode) {
        isGeneratingPreview = true
        previewErrorMessage = nil

        do {
            previewImage = try viewModel.previewImage(for: favorite)
        } catch {
            previewImage = nil
            previewErrorMessage = error.localizedDescription
        }

        isGeneratingPreview = false
    }

    private func renameFavorite(to name: String) {
        do {
            try viewModel.renameFavorite(id: favoriteID, name: name)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }
    }

    private func deleteFavorite() {
        do {
            try viewModel.deleteFavorite(id: favoriteID)
            onDelete()
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }
    }
}
