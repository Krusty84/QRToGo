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
    private let appLanguageStore: AppLanguageStore
    private let generatorService: QRCodeGeneratorService

    var appLanguage: AppLanguage = .system
    var draftSettings = QRCodeSettings.defaults
    var persistedSettings = QRCodeSettings.defaults
    var statusMessage: String?

    private var hasLoaded = false

    init(
        settingsStore: QRCodeSettingsStore? = nil,
        appLanguageStore: AppLanguageStore? = nil,
        generatorService: QRCodeGeneratorService? = nil
    ) {
        self.settingsStore = settingsStore ?? QRCodeSettingsStore()
        self.appLanguageStore = appLanguageStore ?? AppLanguageStore()
        self.generatorService = generatorService ?? QRCodeGeneratorService()
    }

    var validationResults: [QRValidationResult] {
        generatorService.validationResults(for: draftSettings)
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
        appLanguage = appLanguageStore.load()

        do {
            let loadedSettings = try settingsStore.load()
            persistedSettings = loadedSettings
            draftSettings = loadedSettings
        } catch {
            statusMessage = error.localizedDescription
            persistedSettings = .defaults
            draftSettings = .defaults
        }
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else {
            return
        }
        appLanguage = language
        appLanguageStore.save(language)
        statusMessage = nil
    }

    func saveSettings() {
        guard hasBlockingValidation == false else {
            statusMessage = AppLocalization.string("settings.fixErrorsFirst")
            return
        }

        do {
            let savedSettings = try settingsStore.save(draftSettings)
            persistedSettings = savedSettings
            draftSettings = savedSettings
            statusMessage = AppLocalization.string("settings.saved")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func resetToDefaults() {
        draftSettings = .defaults
        statusMessage = AppLocalization.string("settings.resetDone")
    }

    func setCenterIconData(_ data: Data?) {
        guard let data else {
            draftSettings.centerIconImageData = nil
            setCenterLogoEnabled(false)
            return
        }
        guard let preparedData = prepareImageData(from: data, maxDimension: 240) else {
            statusMessage = AppLocalization.string("error.iconDecode")
            return
        }
        draftSettings.centerIconImageData = preparedData
        setCenterLogoEnabled(true)
    }

    func removeCenterIcon() {
        draftSettings.centerIconImageData = nil
        setCenterLogoEnabled(false)
    }

    func setWatermarkImageData(_ data: Data?) {
        guard let data else {
            draftSettings.watermarkImageData = nil
            setGenerationMode(.standard)
            return
        }
        guard let preparedData = prepareImageData(from: data, maxDimension: 1400) else {
            statusMessage = AppLocalization.string("error.watermarkImageDecode")
            return
        }
        draftSettings.watermarkImageData = preparedData
        setGenerationMode(.watermark)
    }

    func removeWatermarkImage() {
        draftSettings.watermarkImageData = nil
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
        if mode == .watermark {
            draftSettings.centerIconEnabled = false
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
}
