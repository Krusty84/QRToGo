//
//  SettingsViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Observation
import UIKit

@Observable
@MainActor
final class SettingsViewModel {
    private let settingsStore: QRCodeSettingsStore
    private let generatorService: QRCodeGeneratorService
    private let photoAlbumSaver: PhotoAlbumSaver

    var sampleText = QRCodeSettings.defaultSampleText
    var draftSettings = QRCodeSettings.defaults
    var persistedSettings = QRCodeSettings.defaults
    var previewImage: UIImage?
    var previewErrorMessage: String?
    var validationResults: [QRValidationResult] = []
    var statusMessage: String?
    var isGeneratingPreview = false
    var isSavingPreview = false

    private var hasLoaded = false
    private var previewTask: Task<Void, Never>?
    private var lastSeenPasteboardChangeCount: Int?
    private var lastAppliedPasteboardText: String?

    init(
        settingsStore: QRCodeSettingsStore? = nil,
        generatorService: QRCodeGeneratorService? = nil,
        photoAlbumSaver: PhotoAlbumSaver? = nil
    ) {
        self.settingsStore = settingsStore ?? QRCodeSettingsStore()
        self.generatorService = generatorService ?? QRCodeGeneratorService()
        self.photoAlbumSaver = photoAlbumSaver ?? PhotoAlbumSaver()
    }

    var hasBlockingValidation: Bool {
        validationResults.contains { $0.severity == .error }
    }

    var hasUnsavedChanges: Bool {
        draftSettings != persistedSettings
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }
        hasLoaded = true

        do {
            let loadedSettings = try settingsStore.load()
            persistedSettings = loadedSettings
            draftSettings = loadedSettings
        } catch {
            statusMessage = error.localizedDescription
            persistedSettings = .defaults
            draftSettings = .defaults
        }

        refreshSampleTextFromPasteboardIfNeeded()
        refreshPreview()
    }

    func refreshSampleTextFromPasteboardIfNeeded() {
        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard lastSeenPasteboardChangeCount != changeCount else {
            return
        }
        lastSeenPasteboardChangeCount = changeCount

        guard let pastedText = pasteboardCandidate(from: pasteboard) else {
            return
        }

        let trimmedPastedText = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPastedText.isEmpty == false else {
            return
        }

        let trimmedSampleText = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canReplaceCurrentText =
            trimmedSampleText.isEmpty ||
            sampleText == QRCodeSettings.defaultSampleText ||
            sampleText == lastAppliedPasteboardText

        guard canReplaceCurrentText else {
            return
        }

        sampleText = trimmedPastedText
        lastAppliedPasteboardText = trimmedPastedText
    }

    func refreshPreview() {
        validationResults = generatorService.validationResults(for: draftSettings)
        previewTask?.cancel()
        previewErrorMessage = nil
        isGeneratingPreview = true

        let previewText = sampleText
        let settings = draftSettings
        let previewSize = min(max(settings.outputSize, 360), 768)

        previewTask = Task {
            do {
                let output = try generatorService.generate(content: previewText, settings: settings, outputSize: previewSize)
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    previewImage = output.image
                    previewErrorMessage = nil
                    isGeneratingPreview = false
                }
            } catch {
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    previewImage = nil
                    previewErrorMessage = error.localizedDescription
                    isGeneratingPreview = false
                }
            }
        }
    }

    func saveSettings() {
        guard hasBlockingValidation == false else {
            statusMessage = NSLocalizedString("settings.fixErrorsFirst", comment: "Fix errors first")
            return
        }

        do {
            let savedSettings = try settingsStore.save(draftSettings)
            persistedSettings = savedSettings
            draftSettings = savedSettings
            statusMessage = NSLocalizedString("settings.saved", comment: "Settings saved")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resetToDefaults() {
        draftSettings = .defaults
        statusMessage = NSLocalizedString("settings.resetDone", comment: "Defaults restored")
    }

    func setCenterIconData(_ data: Data?) {
        guard let data else {
            draftSettings.centerIconImageData = nil
            setCenterLogoEnabled(false)
            return
        }
        guard let preparedData = prepareImageData(from: data, maxDimension: 240) else {
            statusMessage = NSLocalizedString("error.iconDecode", comment: "Icon decode failed")
            return
        }
        draftSettings.centerIconImageData = preparedData
        setCenterLogoEnabled(true)
    }

    func removeCenterIcon() {
        draftSettings.centerIconImageData = nil
        setCenterLogoEnabled(false)
    }

    func setStaticImageData(_ data: Data?) {
        guard let data else {
            draftSettings.staticImageData = nil
            setGenerationMode(.standard)
            return
        }
        guard let preparedData = prepareImageData(from: data, maxDimension: 1400) else {
            statusMessage = NSLocalizedString("error.staticImageDecode", comment: "Static image decode failed")
            return
        }
        draftSettings.staticImageData = preparedData
        setGenerationMode(.staticImage)
    }

    func removeStaticImage() {
        draftSettings.staticImageData = nil
        setGenerationMode(.standard)
    }

    func setCenterLogoEnabled(_ isEnabled: Bool) {
        if isEnabled {
            draftSettings.generationMode = .standard
        }
        draftSettings.centerIconEnabled = isEnabled
    }

    func setGenerationMode(_ mode: QRCodeGenerationMode) {
        draftSettings.generationMode = mode
        if mode == .staticImage {
            draftSettings.centerIconEnabled = false
        }
    }

    func savePreviewToPhotos() async {
        guard hasBlockingValidation == false else {
            statusMessage = NSLocalizedString("settings.fixErrorsFirst", comment: "Fix errors first")
            return
        }

        isSavingPreview = true
        defer { isSavingPreview = false }

        do {
            let settings = draftSettings.normalized()
            let output = try generatorService.generate(content: sampleText, settings: settings)
            try await photoAlbumSaver.savePNGData(output.pngData, albumName: settings.photoAlbumName)
            statusMessage = String.localizedStringWithFormat(
                NSLocalizedString("settings.savePreviewSuccess", comment: "Preview saved"),
                settings.photoAlbumName
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func prepareImageData(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let imageSize = image.size
        let scale = min(maxDimension / max(imageSize.width, imageSize.height), 1)
        let targetSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return renderedImage.pngData()
    }

    private func pasteboardCandidate(from pasteboard: UIPasteboard) -> String? {
        if let url = pasteboard.url?.absoluteString {
            return url
        }
        if let string = pasteboard.string {
            return string
        }
        return nil
    }
}
