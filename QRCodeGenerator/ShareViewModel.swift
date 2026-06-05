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
            let summary = exportSafeSummary(for: candidate)
            let searchMetadata = exportSearchMetadata(for: summary, createdAt: createdAt)
            let cardOutput = try exportCardRenderer.render(
                qrImage: qrOutput.image,
                metadata: exportCardMetadata(
                    for: summary,
                    candidate: candidate,
                    createdAt: createdAt
                ),
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

    private func exportCardMetadata(
        for summary: ShareExportSafeSummary,
        candidate: SharedInputCandidate,
        createdAt: Date
    ) -> QRCodeExportCardMetadata {
        QRCodeExportCardMetadata(
            title: AppLocalization.string("export.card.title"),
            titleTypeText: summary.typeText,
            titleIconSystemName: summary.iconSystemName,
            density: exportDensity(for: candidate),
            detailLine: summary.detailValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string(summary.detailLabelKey),
                    value: $0
                )
            },
            createdLine: QRCodeExportCardLine(
                label: AppLocalization.string("export.card.created"),
                value: exportDateText(for: createdAt)
            ),
            purposeLine: summary.purposeValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string("export.card.purpose"),
                    value: $0
                )
            }
        )
    }

    private func exportDensity(for candidate: SharedInputCandidate) -> QRCodeExportCardDensity {
        if candidate.kind == .contact {
            return .dense
        }

        if candidate.content.count <= 120 {
            return .compact
        }

        if candidate.content.count <= 240 {
            return .normal
        }

        return .dense
    }

    private func exportSearchMetadata(
        for summary: ShareExportSafeSummary,
        createdAt: Date
    ) -> QRCodeExportCardSearchMetadata {
        let title = AppLocalization.string("export.card.title")
        let createdText = exportDateText(for: createdAt)
        var descriptionParts = [
            title,
            labeledText(
                labelKey: "export.card.type",
                value: summary.typeText
            )
        ]

        if let detailValue = summary.detailValue {
            descriptionParts.append(
                labeledText(labelKey: summary.detailLabelKey, value: detailValue)
            )
        }

        if let purposeValue = summary.purposeValue {
            descriptionParts.append(
                labeledText(labelKey: "export.card.purpose", value: purposeValue)
            )
        }

        descriptionParts.append(
            labeledText(labelKey: "export.card.created", value: createdText)
        )

        let keywords = uniqueKeywords(
            [
                title,
                "QR",
                summary.typeText
            ]
            + summary.keywordValues
            + [summary.purposeValue]
        )

        return QRCodeExportCardSearchMetadata(
            title: title,
            description: descriptionParts.joined(separator: " | "),
            keywords: keywords,
            originalFilename: exportOriginalFilename(for: summary, createdAt: createdAt)
        )
    }

    private func exportSafeSummary(for candidate: SharedInputCandidate) -> ShareExportSafeSummary {
        switch candidate.kind {
        case .webURL:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string("generate.kind.website"),
                iconSystemName: "globe",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(for: candidate, detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "Website",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .telegramLink:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "paperplane",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(for: candidate, detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "Telegram",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .remoteFileURL:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "link",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(for: candidate, detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "RemoteFile",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .contact:
                let details = candidate.previewValue.nonEmpty ?? candidate.sourceTitle?.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "person.crop.circle",
                detailLabelKey: "export.card.details",
                detailValue: details,
                purposeValue: nil,
                keywordValues: [details].compactMap { $0 },
                filenameTypeComponent: "Contact",
                filenameHint: candidate.sourceTitle?.nonEmpty ?? details
            )
        }
    }

    private func exportPurposeValue(
        for candidate: SharedInputCandidate,
        detailValue: String?
    ) -> String? {
        guard let purpose = candidate.sourceTitle?.nonEmpty else {
            return nil
        }
        guard purpose != detailValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return purpose
    }

    private func exportDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguageStore().load().locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportOriginalFilename(
        for summary: ShareExportSafeSummary,
        createdAt: Date
    ) -> String {
        let timestamp = exportFilenameDateText(for: createdAt)
        let components = [
            "QRToGO",
            summary.filenameTypeComponent,
            summary.filenameHint.flatMap(filenameSlug(from:)),
            timestamp
        ].compactMap { $0 }

        let baseName = components.joined(separator: "-")
        let truncatedBaseName = String(baseName.prefix(92))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(truncatedBaseName).png"
    }

    private func exportFilenameDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    private func urlFilenameHint(from value: String?) -> String? {
        guard
            let value,
            let url = URL(string: value)
        else {
            return nil
        }

        var components: [String] = []
        if let host = url.host?.nonEmpty {
            components.append(host)
        }
        let pathComponents = url.pathComponents
            .filter { $0 != "/" }
            .prefix(2)
        components.append(contentsOf: pathComponents)

        let hint = components.joined(separator: "-")
        return hint.nonEmpty
    }

    private func filenameSlug(from value: String) -> String? {
        let latinText = value.applyingTransform(.toLatin, reverse: false) ?? value
        let foldedText = latinText.folding(options: .diacriticInsensitive, locale: .current)
        let slug = foldedText
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()

        guard slug.isEmpty == false else {
            return nil
        }

        return String(slug.prefix(32))
    }

    private func labeledText(labelKey: String, value: String) -> String {
        "\(AppLocalization.string(labelKey)): \(value)"
    }

    private func uniqueKeywords(_ values: [String?]) -> [String] {
        var seen: Set<String> = []
        var uniqueValues: [String] = []

        for value in values {
            guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmedValue.isEmpty == false else {
                continue
            }
            let dedupeKey = trimmedValue.lowercased()
            guard seen.insert(dedupeKey).inserted else {
                continue
            }
            uniqueValues.append(trimmedValue)
        }

        return uniqueValues
    }
}

private struct ShareExportSafeSummary {
    let typeText: String
    let iconSystemName: String?
    let detailLabelKey: String
    let detailValue: String?
    let purposeValue: String?
    let keywordValues: [String]
    let filenameTypeComponent: String
    let filenameHint: String?
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
