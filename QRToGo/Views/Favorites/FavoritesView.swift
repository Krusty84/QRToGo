//
//  FavoritesView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import SwiftUI

struct FavoritesView: View {
    let viewModel: FavoritesViewModel
    let navigationState: AppNavigationState

    @State private var path: [UUID] = []
    @State private var favoriteToRename: FavoriteQRCode?
    @State private var pendingDeleteFavoriteID: UUID?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("favorites.title")
                .navigationDestination(for: UUID.self) { favoriteID in
                    FavoriteDetailView(
                        viewModel: viewModel,
                        favoriteID: favoriteID,
                        onDelete: {
                            path.removeAll()
                        }
                    )
                }
        }
        .task {
            viewModel.loadIfNeeded()
            handleRequestedFavorite()
        }
        .onChange(of: navigationState.requestedFavoriteID) { _, _ in
            handleRequestedFavorite()
        }
        .sheet(item: $favoriteToRename) { favorite in
            FavoriteRenameSheet(
                initialName: FavoriteDefaultNames.displayName(for: favorite.name)
            ) { name in
                renameFavorite(favorite, to: name)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.favorites.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "favorites.empty.title",
                    systemImage: "star",
                    description: Text("favorites.empty.description")
                )

                if let statusMessage = viewModel.statusMessage {
                    Text(verbatim: statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            List {
                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(verbatim: statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(viewModel.favorites) { favorite in
                    FavoriteListRow(
                        favorite: favorite,
                        isDeleteConfirmationVisible: pendingDeleteFavoriteID == favorite.id,
                        onRename: {
                            pendingDeleteFavoriteID = nil
                            favoriteToRename = favorite
                        },
                        onDeleteRequest: {
                            withAnimation(.snappy) {
                                pendingDeleteFavoriteID = favorite.id
                            }
                        },
                        onConfirmDelete: {
                            deleteFavoriteConfirmed(favorite)
                        },
                        onCancelDelete: {
                            withAnimation(.snappy) {
                                pendingDeleteFavoriteID = nil
                            }
                        }
                    )
                }
            }
        }
    }

    private func handleRequestedFavorite() {
        guard let requestedFavoriteID = navigationState.requestedFavoriteID else {
            return
        }

        viewModel.loadIfNeeded()
        navigationState.selectedTab = .favorites

        if viewModel.favorite(id: requestedFavoriteID) != nil {
            path = [requestedFavoriteID]
            viewModel.statusMessage = nil
        } else {
            path.removeAll()
            viewModel.statusMessage = AppLocalization.string("favorites.open.missing")
        }

        navigationState.requestedFavoriteID = nil
    }

    private func renameFavorite(_ favorite: FavoriteQRCode, to name: String) {
        do {
            try viewModel.renameFavorite(id: favorite.id, name: name)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }
    }
    
    private func deleteFavoriteConfirmed(_ favorite: FavoriteQRCode) {
        do {
            try viewModel.deleteFavorite(id: favorite.id)

            withAnimation(.snappy) {
                pendingDeleteFavoriteID = nil
            }
        } catch {
            viewModel.statusMessage = error.localizedDescription

            withAnimation(.snappy) {
                pendingDeleteFavoriteID = nil
            }
        }
    }
}

#Preview {
    FavoritesView(
        viewModel: FavoritesViewModel(),
        navigationState: AppNavigationState()
    )
}
