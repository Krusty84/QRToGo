//
//  FavoritesView.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import SwiftUI
import UIKit

struct FavoritesView: View {
    let viewModel: FavoritesViewModel
    let navigationState: AppNavigationState

    @State private var path: [UUID] = []
    @State private var favoriteToRename: FavoriteQRCode?
    @State private var favoriteToDelete: FavoriteQRCode?

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
            FavoriteRenameSheet(initialName: favorite.name) { name in
                renameFavorite(favorite, to: name)
            }
        }
        .confirmationDialog(
            "favorites.delete.confirm",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            if let favoriteToDelete {
                Button("favorites.delete", role: .destructive) {
                    deleteFavorite(favoriteToDelete)
                }
            }
            Button("share.cancel", role: .cancel) {
                favoriteToDelete = nil
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
                    NavigationLink(value: favorite.id) {
                        FavoriteRow(favorite: favorite)
                    }
                    .swipeActions {
                        Button("favorites.delete", role: .destructive) {
                            favoriteToDelete = favorite
                        }

                        Button("favorites.rename") {
                            favoriteToRename = favorite
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { favoriteToDelete != nil },
            set: { isPresented in
                if isPresented == false {
                    favoriteToDelete = nil
                }
            }
        )
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

    private func deleteFavorite(_ favorite: FavoriteQRCode) {
        do {
            try viewModel.deleteFavorite(id: favorite.id)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }
        favoriteToDelete = nil
    }
}

private struct FavoriteRow: View {
    let favorite: FavoriteQRCode

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.name)
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

private struct FavoriteDetailView: View {
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
            Form {
                Section("favorites.preview") {
                    QRPreviewView(
                        image: previewImage,
                        isLoading: isGeneratingPreview,
                        errorMessage: previewErrorMessage
                    )
                }

                Section {
                    LabeledContent("favorites.name", value: favorite.name)
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
            .navigationTitle(favorite.name)
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
                FavoriteRenameSheet(initialName: favorite.name) { name in
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

private struct FavoriteRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    let onRename: (String) -> Void

    init(initialName: String, onRename: @escaping (String) -> Void) {
        _name = State(initialValue: initialName)
        self.onRename = onRename
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("favorites.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("favorites.rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("share.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("favorites.rename") {
                        onRename(trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    FavoritesView(
        viewModel: FavoritesViewModel(),
        navigationState: AppNavigationState()
    )
}
