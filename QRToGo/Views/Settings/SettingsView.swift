import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SettingsViewModel()
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedStaticImageItem: PhotosPickerItem?
    @FocusState private var isSampleTextFocused: Bool

    private let outputSizes = [512, 768, 1024, 1536]

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("settings.section.preview") {
                    TextField("settings.sampleText", text: $viewModel.sampleText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($isSampleTextFocused)

                    QRPreviewView(
                        image: viewModel.previewImage,
                        isLoading: viewModel.isGeneratingPreview,
                        errorMessage: viewModel.previewErrorMessage
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("settings.scannability", systemImage: "checkmark.shield")
                            .font(.headline)

                        if viewModel.validationResults.isEmpty {
                            Text("settings.scannability.safe")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            ForEach(viewModel.validationResults) { result in
                                Label {
                                    Text(LocalizedStringKey(result.messageKey))
                                } icon: {
                                    Image(systemName: result.severity == .error ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                                        .foregroundStyle(result.severity == .error ? .orange : .yellow)
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    Button {
                        Task {
                            await viewModel.savePreviewToPhotos()
                        }
                    } label: {
                        if viewModel.isSavingPreview {
                            ProgressView()
                        } else {
                            Label("settings.savePreview", systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(viewModel.isSavingPreview || viewModel.isGeneratingPreview || viewModel.hasBlockingValidation)
                }

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
                    Picker("settings.generationMode", selection: $viewModel.draftSettings.generationMode) {
                        ForEach(QRCodeGenerationMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    }

                    Picker("settings.moduleStyle", selection: $viewModel.draftSettings.moduleStyle) {
                        ForEach(QRModuleStyle.allCases) { style in
                            Text(LocalizedStringKey(style.titleKey)).tag(style)
                        }
                    }

                    if viewModel.draftSettings.generationMode == .staticImage {
                        if let staticImagePreview {
                            HStack(spacing: 12) {
                                Image(uiImage: staticImagePreview)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .clipShape(.rect(cornerRadius: 16))

                                Text("settings.staticImageReady")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                        } else {
                            Text("settings.noStaticImage")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        PhotosPicker(selection: $selectedStaticImageItem, matching: .images) {
                            Label(
                                staticImagePreview == nil ? "settings.staticImagePick" : "settings.staticImageReplace",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }

                        if staticImagePreview != nil {
                            Button("settings.staticImageRemove", role: .destructive) {
                                viewModel.removeStaticImage()
                            }
                        }
                    }

                    Toggle("settings.centerIconEnabled", isOn: $viewModel.draftSettings.centerIconEnabled)

                    if viewModel.draftSettings.centerIconEnabled {
                        if let centerLogoImage {
                            HStack(spacing: 12) {
                                Image(uiImage: centerLogoImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 52, height: 52)
                                    .clipShape(.rect(cornerRadius: 14))

                                Text("settings.centerIconReady")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                        } else {
                            Text("settings.noLogo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            Label(
                                centerLogoImage == nil ? "settings.centerIconPick" : "settings.centerIconReplace",
                                systemImage: "photo"
                            )
                        }

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
                    Picker("settings.exportFormat", selection: $viewModel.draftSettings.exportFormat) {
                        ForEach(QRExportFormat.allCases) { format in
                            Text(LocalizedStringKey(format.titleKey)).tag(format)
                        }
                    }

                    Text("settings.exportNote")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("share.done") {
                        isSampleTextFocused = false
                    }
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            viewModel.refreshSampleTextFromPasteboardIfNeeded()
        }
        .onChange(of: viewModel.sampleText) { _, _ in
            viewModel.refreshPreview()
        }
        .onChange(of: viewModel.draftSettings) { _, _ in
            viewModel.refreshPreview()
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
    SettingsView()
}
