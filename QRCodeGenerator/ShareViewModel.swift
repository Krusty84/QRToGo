//
//  ShareViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Observation
import UIKit

@Observable
@MainActor
final class ShareViewModel {
    private let extensionContext: NSExtensionContext?
    private let settingsStore: QRCodeSettingsStore
    private let generatorService: QRCodeGeneratorService
    private let inputReader: SharedInputReader
    private let photoAlbumSaver: PhotoAlbumSaver

    var candidates: [SharedInputCandidate] = []
    var selectedCandidateID: String?
    var previewImage: UIImage?
    var previewErrorMessage: String?
    var statusMessage: String?
    var validationResults: [QRValidationResult] = []
    var isLoading = false
    var isGeneratingPreview = false
    var isSaving = false

    private var hasLoaded = false
    private var settings = QRCodeSettings.defaults
    private var renderedOutput: QRCodeRenderOutput?

    init(
        extensionContext: NSExtensionContext?,
        settingsStore: QRCodeSettingsStore? = nil,
        generatorService: QRCodeGeneratorService? = nil,
        inputReader: SharedInputReader? = nil,
        photoAlbumSaver: PhotoAlbumSaver? = nil
    ) {
        self.extensionContext = extensionContext
        self.settingsStore = settingsStore ?? QRCodeSettingsStore()
        self.generatorService = generatorService ?? QRCodeGeneratorService()
        self.inputReader = inputReader ?? SharedInputReader()
        self.photoAlbumSaver = photoAlbumSaver ?? PhotoAlbumSaver()
    }

    var selectedCandidate: SharedInputCandidate? {
        candidates.first(where: { $0.id == selectedCandidateID }) ?? candidates.first
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        loadCurrentSettings()

        do {
            candidates = try await inputReader.readCandidates(from: extensionContext)
            selectedCandidateID = candidates.first?.id
            await regeneratePreview()
        } catch {
            previewErrorMessage = error.localizedDescription
        }
    }

    func updateSelectedCandidate(id: String) async {
        selectedCandidateID = id
        await regeneratePreview()
    }

    func saveToPhotos() async {
        isSaving = true
        defer { isSaving = false }

        await regeneratePreview()

        guard let output = renderedOutput else {
            return
        }

        do {
            try await photoAlbumSaver.savePNGData(output.pngData, albumName: settings.photoAlbumName)
            statusMessage = String.localizedStringWithFormat(
                NSLocalizedString("share.saveSuccess", comment: "Share save success"),
                settings.photoAlbumName
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    func cancelRequest() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }

    private func regeneratePreview() async {
        guard let candidate = selectedCandidate else {
            previewImage = nil
            previewErrorMessage = NSLocalizedString("error.noCandidateSelected", comment: "No candidate selected")
            renderedOutput = nil
            return
        }

        loadCurrentSettings()
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }

        do {
            let output = try generatorService.generate(
                content: candidate.content,
                settings: settings,
                outputSize: min(max(settings.outputSize, 360), 768)
            )
            previewImage = output.image
            previewErrorMessage = nil
            renderedOutput = output
        } catch {
            previewImage = nil
            previewErrorMessage = error.localizedDescription
            renderedOutput = nil
        }
    }

    private func loadCurrentSettings() {
        do {
            settings = try settingsStore.load()
        } catch {
            statusMessage = error.localizedDescription
            settings = .defaults
        }
        validationResults = generatorService.validationResults(for: settings)
    }
}
