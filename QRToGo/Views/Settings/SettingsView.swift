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
    @State private var selectedStaticImageItem: PhotosPickerItem?
    @FocusState private var isAlbumNameFocused: Bool

    private let outputSizes = [512, 768, 1024, 1536]

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.colors") {
                    ColorPicker("settings.foregroundColor", selection: foregroundColorBinding, supportsOpacity: false)
                    ColorPicker("settings.backgroundColor", selection: backgroundColorBinding, supportsOpacity: false)
                }

                Section("settings.section.readability") {
                    Picker("settings.errorCorrection", selection: $viewModel.draftSettings.errorCorrectionLevel) {
                        ForEach(QRCodeErrorCorrectionLevel.allCases) { level in
                            Text(LocalizedStringKey(level.titleKey)).tag(level)
                        }
                    }

                    Picker("settings.outputSize", selection: $viewModel.draftSettings.outputSize) {
                        ForEach(outputSizes, id: \.self) { size in
                            Text("\(size) px").tag(size)
                        }
                    }

                    Picker("settings.quietZone", selection: $viewModel.draftSettings.quietZone) {
                        ForEach(QRQuietZonePreset.allCases) { preset in
                            Text(LocalizedStringKey(preset.titleKey)).tag(preset)
                        }
                    }
                }

                Section("settings.section.visualStyle") {
                    Toggle("settings.staticImageMode", isOn: staticImageModeBinding)
                        .disabled(viewModel.draftSettings.centerIconEnabled)

                    Toggle("settings.centerIconEnabled", isOn: centerLogoEnabledBinding)
                        .disabled(viewModel.draftSettings.generationMode == .staticImage)

                    Picker("settings.moduleStyle", selection: $viewModel.draftSettings.moduleStyle) {
                        ForEach(QRModuleStyle.allCases) { style in
                            Text(LocalizedStringKey(style.titleKey)).tag(style)
                        }
                    }

                    if viewModel.draftSettings.generationMode == .staticImage {
                        PhotosPicker(selection: $selectedStaticImageItem, matching: .images) {
                            staticImagePickerContent
                        }
                        .buttonStyle(.plain)

                        if staticImagePreview != nil {
                            Button("settings.staticImageRemove", role: .destructive) {
                                viewModel.removeStaticImage()
                            }
                        }
                    }

                    if viewModel.draftSettings.centerIconEnabled {
                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            centerLogoPickerContent
                        }
                        .buttonStyle(.plain)

                        if centerLogoImage != nil {
                            Button("settings.centerIconRemove", role: .destructive) {
                                viewModel.removeCenterIcon()
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("settings.centerIconScale")
                                Spacer()
                                Text(viewModel.draftSettings.centerIconScale.formatted(.percent.precision(.fractionLength(0))))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $viewModel.draftSettings.centerIconScale, in: 0.12...0.24, step: 0.01)
                        }
                    }

                    Picker("settings.visualEffect", selection: $viewModel.draftSettings.visualEffect) {
                        ForEach(QRVisualEffect.allCases) { effect in
                            Text(LocalizedStringKey(effect.titleKey)).tag(effect)
                        }
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("share.done") {
                        isAlbumNameFocused = false
                    }
                }
            }
        }
        .onChange(of: selectedIconItem) { _, newItem in
            Task {
                await loadIcon(from: newItem)
            }
        }
        .onChange(of: selectedStaticImageItem) { _, newItem in
            Task {
                await loadStaticImage(from: newItem)
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

    private var staticImageModeBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.draftSettings.generationMode == .staticImage
            },
            set: { isEnabled in
                viewModel.setGenerationMode(isEnabled ? .staticImage : .standard)
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

    private var staticImagePreview: UIImage? {
        guard let data = viewModel.draftSettings.staticImageData else {
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

    @ViewBuilder
    private var staticImagePickerContent: some View {
        if let staticImagePreview {
            Image(uiImage: staticImagePreview)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "photo.badge.plus")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(12)
                }
        } else {
            ContentUnavailableView(
                "settings.staticImagePick",
                systemImage: "photo.on.rectangle.angled"
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
            viewModel.setCenterIconData(data)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }

        selectedIconItem = nil
    }

    @MainActor
    private func loadStaticImage(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        do {
            let data = try await item.loadTransferable(type: Data.self)
            viewModel.setStaticImageData(data)
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }

        selectedStaticImageItem = nil
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
