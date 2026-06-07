//
//  GenerateViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 30/05/2026.
//

import Contacts
import Observation
import UIKit

@Observable
@MainActor
final class GenerateViewModel {
    private let generatorService: QRCodeGeneratorService
    private let photoAlbumSaver: PhotoAlbumSaver
    private let exportCardRenderer: QRCodeExportCardRenderer

    var contentDraft = GenerateContentDraft.defaults
    var exportPurposeDraft = ""
    var previewImage: UIImage?
    var previewErrorMessage: String?
    var statusMessage: String?
    var isGeneratingPreview = false
    var isSavingPreview = false
    var hasGeneratedQRCode: Bool {
        previewImage != nil
            && previewErrorMessage == nil
            && isGeneratingPreview == false
    }
    var selectedLocation: GenerateLocationSelection? {
        GeneratePayloadBuilder(draft: contentDraft).locationSelection()
    }

    private var previewTask: Task<Void, Never>?

    init(
        generatorService: QRCodeGeneratorService? = nil,
        photoAlbumSaver: PhotoAlbumSaver? = nil,
        exportCardRenderer: QRCodeExportCardRenderer? = nil
    ) {
        self.generatorService = generatorService ?? QRCodeGeneratorService()
        self.photoAlbumSaver = photoAlbumSaver ?? PhotoAlbumSaver()
        self.exportCardRenderer = exportCardRenderer ?? QRCodeExportCardRenderer()
    }

    func setContentKind(_ kind: GenerateContentKind) {
        contentDraft.kind = kind

        if kind == .location {
            exportPurposeDraft = ""
        }
    }

    func setWiFiSecurity(_ security: GenerateWiFiSecurity) {
        contentDraft.wifiSecurity = security
        if security == .none {
            contentDraft.wifiPassword = ""
        }
    }

    func setSelectedLocation(_ selection: GenerateLocationSelection) {
        contentDraft.locationLatitude = GeneratePayloadBuilder.formattedCoordinate(selection.latitude)
        contentDraft.locationLongitude = GeneratePayloadBuilder.formattedCoordinate(selection.longitude)

        let trimmedLabel = selection.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLabel.isEmpty == false {
            contentDraft.locationLabel = trimmedLabel
        }
    }

    func refreshPreview(using settings: QRCodeSettings) {
        previewTask?.cancel()
        previewImage = nil
        previewErrorMessage = nil
        isGeneratingPreview = true

        let previewSettings = settings.normalized()
        let previewSize = min(max(previewSettings.outputSize, 360), 768)
        let content: String
        let payloadBuilder = GeneratePayloadBuilder(draft: contentDraft)

        do {
            content = try payloadBuilder.generatedContent()
        } catch {
            previewImage = nil
            previewErrorMessage = error.localizedDescription
            isGeneratingPreview = false
            return
        }

        previewTask = Task {
            do {
                let output = try generatorService.generate(
                    content: content,
                    settings: previewSettings,
                    outputSize: previewSize
                )
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

    func setSelectedContact(_ contact: CNContact) {
        do {
            contentDraft.contact = try makeSelectedContact(from: contact)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeSelectedContact() {
        contentDraft.contact = nil
    }

    @discardableResult
    func savePreviewToPhotos(using settings: QRCodeSettings) async -> Bool {
        guard hasGeneratedQRCode, previewImage != nil else {
            statusMessage = nil
            return false
        }

        let validationResults = generatorService.validationResults(for: settings)
        guard validationResults.contains(where: { $0.severity == .error }) == false else {
            statusMessage = nil
            return false
        }

        isSavingPreview = true
        defer { isSavingPreview = false }

        do {
            let normalizedSettings = settings.normalized()
            let createdAt = Date.now
            let payloadBuilder = GeneratePayloadBuilder(draft: contentDraft)
            let metadataBuilder = GenerateExportMetadataBuilder(
                draft: contentDraft,
                exportPurposeDraft: exportPurposeDraft
            )
            let payload = try payloadBuilder.generatedContent()
            let output = try generatorService.generate(
                content: payload,
                settings: normalizedSettings
            )
            let searchMetadata = metadataBuilder.exportSearchMetadata(createdAt: createdAt)
            let cardOutput = try exportCardRenderer.render(
                qrImage: output.image,
                metadata: metadataBuilder.exportCardMetadata(createdAt: createdAt, payload: payload),
                searchMetadata: searchMetadata
            )
            try await photoAlbumSaver.savePNGData(
                cardOutput.pngData,
                albumName: normalizedSettings.photoAlbumName,
                originalFilename: searchMetadata.originalFilename
            )

            statusMessage = nil
            return true
        } catch {
            statusMessage = nil
            return false
        }
    }

    func canMakeFavoriteQRCode(using settings: QRCodeSettings) -> Bool {
        let validationResults = generatorService.validationResults(for: settings)
        guard validationResults.contains(where: { $0.severity == .error }) == false else {
            return false
        }

        return (try? GeneratePayloadBuilder(draft: contentDraft).generatedContent()) != nil
    }

    func makeFavoriteQRCode(name: String, using settings: QRCodeSettings) throws -> FavoriteQRCode {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            throw FavoriteQRCodeCreationError.emptyName
        }

        let now = Date.now
        return FavoriteQRCode(
            id: UUID(),
            name: trimmedName,
            kind: contentDraft.kind,
            payload: try GeneratePayloadBuilder(draft: contentDraft).generatedContent(),
            settings: settings.normalized(),
            exportPurpose: exportPurposeDraft.nonEmpty,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeSelectedContact(from contact: CNContact) throws -> GenerateSelectedContact {
        let payload = try ContactVCardPayloadBuilder.makePayload(
            from: contact,
            fallbackNameKey: "generate.contactFallback"
        )

        #if DEBUG
        ContactQRPayloadDiagnostics.logVCardText(
            payload.content,
            source: "MainApp.ContactPicker.finalPayload.afterSanitize"
        )
        #endif

        return GenerateSelectedContact(
            displayName: payload.displayName,
            vCardString: payload.content
        )
    }
}

private enum FavoriteQRCodeCreationError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        AppLocalization.string("favorites.add.error")
    }
}
