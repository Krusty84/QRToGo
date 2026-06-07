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
    private let exportCardRenderer: QRCodeExportCardRenderer

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
    private var renderedExportCardOutput: QRCodeRenderOutput?
    private var renderedExportOriginalFilename: String?

    init(
        extensionContext: NSExtensionContext?,
        settingsStore: QRCodeSettingsStore? = nil,
        generatorService: QRCodeGeneratorService? = nil,
        inputReader: SharedInputReader? = nil,
        photoAlbumSaver: PhotoAlbumSaver? = nil,
        exportCardRenderer: QRCodeExportCardRenderer? = nil
    ) {
        self.extensionContext = extensionContext
        self.settingsStore = settingsStore ?? QRCodeSettingsStore()
        self.generatorService = generatorService ?? QRCodeGeneratorService()
        self.inputReader = inputReader ?? SharedInputReader()
        self.photoAlbumSaver = photoAlbumSaver ?? PhotoAlbumSaver()
        self.exportCardRenderer = exportCardRenderer ?? QRCodeExportCardRenderer()
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

        if renderedExportCardOutput == nil || renderedExportOriginalFilename == nil {
            await regeneratePreview()
        }

        do {
            guard
                let cardOutput = renderedExportCardOutput,
                let originalFilename = renderedExportOriginalFilename
            else {
                return
            }
            let normalizedSettings = settings.normalized()
            try await photoAlbumSaver.savePNGData(
                cardOutput.pngData,
                albumName: normalizedSettings.photoAlbumName,
                originalFilename: originalFilename
            )
            statusMessage = String.localizedStringWithFormat(
                AppLocalization.string("share.saveSuccess"),
                normalizedSettings.photoAlbumName
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
            previewErrorMessage = AppLocalization.string("error.noCandidateSelected")
            renderedExportCardOutput = nil
            renderedExportOriginalFilename = nil
            return
        }

        loadCurrentSettings()
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }

        do {
            let normalizedSettings = settings.normalized()
            let createdAt = Date.now
            let qrOutput = try generatorService.generate(
                content: candidate.content,
                settings: normalizedSettings
            )
            let metadataBuilder = ShareExportMetadataBuilder(candidate: candidate)
            let searchMetadata = metadataBuilder.exportSearchMetadata(createdAt: createdAt)
            let cardOutput = try exportCardRenderer.render(
                qrImage: qrOutput.image,
                metadata: metadataBuilder.exportCardMetadata(createdAt: createdAt),
                searchMetadata: searchMetadata
            )
            previewImage = cardOutput.image
            previewErrorMessage = nil
            renderedExportCardOutput = cardOutput
            renderedExportOriginalFilename = searchMetadata.originalFilename
        } catch {
            previewImage = nil
            previewErrorMessage = error.localizedDescription
            renderedExportCardOutput = nil
            renderedExportOriginalFilename = nil
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
