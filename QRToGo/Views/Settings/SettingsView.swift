//
//  SettingsView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var pendingCropImage: UIImage?
    @State private var isCropSheetPresented = false
    @FocusState private var isAlbumNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.colors") {
                    ColorPicker("settings.foregroundColor", selection: foregroundColorBinding, supportsOpacity: false)
                    ColorPicker("settings.backgroundColor", selection: backgroundColorBinding, supportsOpacity: false)
                }

                Section("settings.section.style") {
                    Toggle("settings.centerIconEnabled", isOn: centerLogoEnabledBinding)

                    if viewModel.draftSettings.centerIconEnabled {
                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            centerLogoPickerContent
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("settings.centerIconScale")
                                Spacer()
                                Text("\(Int(viewModel.draftSettings.centerIconScale * 100))%")
                                    .foregroundStyle(.secondary)
                            }

                            Slider(
                                value: $viewModel.draftSettings.centerIconScale,
                                in: 0.14...0.24,
                                step: 0.01
                            )

                            Text("settings.centerIconScaleHint")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if centerLogoImage != nil {
                            Button("settings.centerIconRemove", role: .destructive) {
                                viewModel.removeCenterIcon()
                            }
                        }
                    }
                }

                Section("settings.section.language") {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            viewModel.setAppLanguage(language)
                        } label: {
                            languageRow(for: language)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("settings.section.export") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.albumName")

                        TextField(QRCodeSettings.defaultPhotoAlbumName, text: $viewModel.draftSettings.photoAlbumName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($isAlbumNameFocused)
                    }

                    Button("settings.reset", role: .destructive) {
                        viewModel.resetToDefaults()
                    }

                    Button("settings.save") {
                        viewModel.saveSettings()
                    }
                    .disabled(viewModel.hasBlockingValidation || viewModel.hasUnsavedChanges == false)
                }

                Section("settings.section.about") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("settings.about", systemImage: "info.circle")
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(verbatim: statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("tab.settings")
        }
        .onChange(of: selectedIconItem) { _, newItem in
            Task {
                await loadIcon(from: newItem)
            }
        }
        .sheet(isPresented: $isCropSheetPresented, onDismiss: clearPendingCrop) {
            if let pendingCropImage {
                ImageCropView(
                    image: pendingCropImage,
                    outputSize: 512,
                    onCancel: cancelCrop,
                    onUseImage: applyCroppedImage
                )
            }
        }
    }

    private var foregroundColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: viewModel.draftSettings.foregroundColor.uiColor)
            },
            set: { newValue in
                viewModel.draftSettings.foregroundColor = QRColor(uiColor: UIColor(newValue))
            }
        )
    }

    @ViewBuilder
    private func languageRow(for language: AppLanguage) -> some View {
        let isSelected = viewModel.appLanguage == language

        HStack {
            Text(LocalizedStringKey(language.titleKey))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(uiColor: viewModel.draftSettings.backgroundColor.uiColor)
            },
            set: { newValue in
                viewModel.draftSettings.backgroundColor = QRColor(uiColor: UIColor(newValue))
            }
        )
    }

    private var centerLogoEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.draftSettings.centerIconEnabled
            },
            set: { newValue in
                viewModel.setCenterLogoEnabled(newValue)
            }
        )
    }

    private var centerLogoImage: UIImage? {
        guard let data = viewModel.draftSettings.centerIconImageData else {
            return nil
        }
        return UIImage(data: data)
    }

    @ViewBuilder
    private var centerLogoPickerContent: some View {
        if let centerLogoImage {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(uiColor: .secondarySystemBackground))

                Image(uiImage: centerLogoImage)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "photo.badge.plus")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(12)
            }
        } else {
            ContentUnavailableView(
                "settings.centerIconPick",
                systemImage: "photo"
            )
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 18))
        }
    }

    @MainActor
    private func loadIcon(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard let data, let image = UIImage(data: data) else {
                viewModel.statusMessage = AppLocalization.string("error.iconDecode")
                selectedIconItem = nil
                return
            }
            presentCrop(for: image)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }

        selectedIconItem = nil
    }

    private func presentCrop(for image: UIImage) {
        pendingCropImage = image
        isCropSheetPresented = true
    }

    private func applyCroppedImage(_ data: Data) {
        viewModel.setCenterIconData(data)
        isCropSheetPresented = false
    }

    private func cancelCrop() {
        isCropSheetPresented = false
    }

    private func clearPendingCrop() {
        pendingCropImage = nil
        selectedIconItem = nil
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
