//
//  GenerateView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 30/05/2026.
//

import SwiftUI
import Combine

struct GenerateView: View {
    @Bindable var viewModel: GenerateViewModel
    let settingsViewModel: SettingsViewModel
    let favoritesViewModel: FavoritesViewModel
    @State private var isContactPickerPresented = false
    @State private var isFavoriteSheetPresented = false
    @StateObject private var locationProvider = CurrentLocationProvider()
    @State private var isFullScreenLocationMapPresented = false
    @State private var saveToPhotosFeedback: ActionFeedback?
    @State private var addToFavoriteFeedback: ActionFeedback?
    @FocusState private var focusedField: GenerateFocusedField?

    var body: some View {
        NavigationStack {
            Form {
                Section("generate.section.type") {
                    GenerateContentKindGrid(
                        selectedKind: viewModel.contentDraft.kind,
                        onSelect: viewModel.setContentKind
                    )
                }

                Section("generate.section.content") {
                    GenerateContentEditor(
                        draft: $viewModel.contentDraft,
                        selectedLocation: viewModel.selectedLocation,
                        isResolvingCurrentLocation: locationProvider.isRequestingLocation,
                        wifiSecurity: wifiSecurityBinding,
                        onPickContact: presentContactPicker,
                        onRemoveContact: viewModel.removeSelectedContact,
                        onSelectLocation: viewModel.setSelectedLocation,
                        onOpenFullScreenMap: openFullScreenLocationMap,
                        focusedField: $focusedField
                    )

                    if viewModel.contentDraft.kind != .location {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("generate.exportPurpose", text: $viewModel.exportPurposeDraft, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                }

                Section("settings.section.preview") {
                    QRPreviewView(
                        image: viewModel.previewImage,
                        isLoading: viewModel.isGeneratingPreview,
                        errorMessage: viewModel.previewErrorMessage
                    )

                    if viewModel.hasGeneratedQRCode {
                        GenerateQRQualityView(
                            validationResults: settingsViewModel.validationResults
                        )
                    }

                    Button {
                        savePreviewToPhotos()
                    } label: {
                        HStack {
                            if viewModel.isSavingPreview {
                                ProgressView()
                            } else {
                                Label("settings.savePreview", systemImage: "photo.badge.plus")
                                    .foregroundStyle(actionButtonForeground(isDisabled: isSaveToPhotosDisabled))
                            }

                            Spacer()

                            GenerateActionFeedbackBadge(feedback: saveToPhotosFeedback)
                        }
                    }
                    .disabled(isSaveToPhotosDisabled)
                    .opacity(isSaveToPhotosDisabled ? 0.45 : 1.0)

                    Button {
                        presentFavoriteSheet()
                    } label: {
                        HStack {
                            Label("favorites.add.button", systemImage: "text.badge.star")
                                .foregroundStyle(actionButtonForeground(isDisabled: isAddToFavoriteDisabled))

                            Spacer()

                            GenerateActionFeedbackBadge(feedback: addToFavoriteFeedback)
                        }
                    }
                    .disabled(isAddToFavoriteDisabled)
                    .opacity(isAddToFavoriteDisabled ? 0.45 : 1.0)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("tab.generate")
            .onChange(of: viewModel.contentDraft) { _, _ in
                resetActionFeedbackBadges()
            }
            .task(id: viewModel.contentDraft.kind) {
                guard viewModel.contentDraft.kind == .location else {
                    return
                }

                locationProvider.prepareForLocationMode()
            }
            .onReceive(locationProvider.$currentSelection.compactMap { $0 }) { selection in
                guard viewModel.contentDraft.kind == .location else {
                    return
                }

                viewModel.setSelectedLocation(selection)
            }
            .onChange(of: settingsViewModel.draftSettings) { _, _ in
                resetActionFeedbackBadges()
            }
            .onChange(of: viewModel.hasGeneratedQRCode) { _, hasGeneratedQRCode in
                if hasGeneratedQRCode == false {
                    resetActionFeedbackBadges()
                }
            }
            .onChange(of: viewModel.exportPurposeDraft) { _, _ in
                withAnimation(.snappy) {
                    saveToPhotosFeedback = nil
                }
            }
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPickerView(
                onSelect: { contact in
                    viewModel.setSelectedContact(contact)
                    isContactPickerPresented = false
                },
                onCancel: {
                    isContactPickerPresented = false
                }
            )
        }
        .sheet(isPresented: $isFavoriteSheetPresented) {
            AddFavoriteSheet(
                availableSuggestionNames: FavoriteDefaultNames.availableNames(
                    for: favoritesViewModel.favorites
                )
            ) { name in
                addFavorite(named: name)
            }
        }
        .fullScreenCover(isPresented: $isFullScreenLocationMapPresented) {
            LocationMapPickerView(
                initialSelection: viewModel.selectedLocation
            ) { selection in
                viewModel.setSelectedLocation(selection)
                isFullScreenLocationMapPresented = false
            }
        }
    }

    private var wifiSecurityBinding: Binding<GenerateWiFiSecurity> {
        Binding(
            get: {
                viewModel.contentDraft.wifiSecurity
            },
            set: { newValue in
                viewModel.setWiFiSecurity(newValue)
            }
        )
    }

    private func actionButtonForeground(isDisabled: Bool) -> Color {
        isDisabled ? Color.secondary : Color.accentColor
    }

    private func resetActionFeedbackBadges() {
        withAnimation(.snappy) {
            saveToPhotosFeedback = nil
            addToFavoriteFeedback = nil
        }
    }

    private var isSaveToPhotosDisabled: Bool {
        viewModel.isSavingPreview
            || viewModel.hasGeneratedQRCode == false
            || settingsViewModel.hasBlockingValidation
    }

    private var isAddToFavoriteDisabled: Bool {
        viewModel.hasGeneratedQRCode == false
            || settingsViewModel.hasBlockingValidation
            || viewModel.canMakeFavoriteQRCode(using: settingsViewModel.draftSettings) == false
    }

    private func presentContactPicker() {
        isContactPickerPresented = true
    }

    private func openFullScreenLocationMap() {
        isFullScreenLocationMapPresented = true
    }

    private func savePreviewToPhotos() {
        guard isSaveToPhotosDisabled == false else {
            return
        }

        Task {
            let isSuccess = await viewModel.savePreviewToPhotos(
                using: settingsViewModel.draftSettings
            )

            withAnimation(.snappy) {
                saveToPhotosFeedback = isSuccess ? .success : .failure
            }
        }
    }

    private func presentFavoriteSheet() {
        guard isAddToFavoriteDisabled == false else {
            return
        }

        isFavoriteSheetPresented = true
    }

    private func addFavorite(named name: String) -> Bool {
        guard viewModel.hasGeneratedQRCode, viewModel.previewImage != nil else {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }

        guard settingsViewModel.hasBlockingValidation == false else {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }

        do {
            let favorite = try viewModel.makeFavoriteQRCode(
                name: name,
                using: settingsViewModel.draftSettings
            )
            try favoritesViewModel.addFavorite(favorite)

            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .success
            }

            return true
        } catch {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }
    }
}

#Preview {
    GenerateView(
        viewModel: GenerateViewModel(),
        settingsViewModel: SettingsViewModel(),
        favoritesViewModel: FavoritesViewModel()
    )
}
