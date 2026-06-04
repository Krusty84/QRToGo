//
//  GenerateViewModel.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
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
    }

    func setWiFiSecurity(_ security: GenerateWiFiSecurity) {
        contentDraft.wifiSecurity = security
        if security == .none {
            contentDraft.wifiPassword = ""
        }
    }

    func refreshPreview(using settings: QRCodeSettings) {
        previewTask?.cancel()
        previewErrorMessage = nil
        isGeneratingPreview = true

        let previewSettings = settings.normalized()
        let previewSize = min(max(previewSettings.outputSize, 360), 768)
        let content: String

        do {
            content = try generatedContent()
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

    func savePreviewToPhotos(using settings: QRCodeSettings) async {
        let validationResults = generatorService.validationResults(for: settings)
        guard validationResults.contains(where: { $0.severity == .error }) == false else {
            statusMessage = AppLocalization.string("settings.fixErrorsFirst")
            return
        }

        isSavingPreview = true
        defer { isSavingPreview = false }

        do {
            let normalizedSettings = settings.normalized()
            let createdAt = Date.now
            let payload = try generatedContent()
            let output = try generatorService.generate(
                content: payload,
                settings: normalizedSettings
            )
            let searchMetadata = exportSearchMetadata(createdAt: createdAt)
            let cardOutput = try exportCardRenderer.render(
                qrImage: output.image,
                metadata: exportCardMetadata(createdAt: createdAt, payload: payload),
                searchMetadata: searchMetadata
            )
            try await photoAlbumSaver.savePNGData(
                cardOutput.pngData,
                albumName: normalizedSettings.photoAlbumName,
                originalFilename: searchMetadata.originalFilename
            )
            statusMessage = String.localizedStringWithFormat(
                AppLocalization.string("settings.savePreviewSuccess"),
                normalizedSettings.photoAlbumName
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func canMakeFavoriteQRCode(using settings: QRCodeSettings) -> Bool {
        let validationResults = generatorService.validationResults(for: settings)
        guard validationResults.contains(where: { $0.severity == .error }) == false else {
            return false
        }

        return (try? generatedContent()) != nil
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
            payload: try generatedContent(),
            settings: settings.normalized(),
            exportPurpose: exportPurposeDraft.nonEmpty,
            createdAt: now,
            updatedAt: now
        )
    }

    private func exportCardMetadata(
        createdAt: Date,
        payload: String
    ) -> QRCodeExportCardMetadata {
        let safeSummary = exportSafeSummary()
        return QRCodeExportCardMetadata(
            title: AppLocalization.string("export.card.title"),
            titleTypeText: AppLocalization.string(contentDraft.kind.titleKey),
            titleIconSystemName: contentDraft.kind.systemImage,
            density: exportDensity(for: payload),
            detailLine: safeSummary.detailValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string(safeSummary.detailLabelKey),
                    value: $0
                )
            },
            typeLine: QRCodeExportCardLine(
                label: AppLocalization.string("export.card.type"),
                value: AppLocalization.string(contentDraft.kind.titleKey)
            ),
            createdLine: QRCodeExportCardLine(
                label: AppLocalization.string("export.card.created"),
                value: exportDateText(for: createdAt)
            ),
            purposeLine: exportPurposeDraft.nonEmpty.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string("export.card.purpose"),
                    value: $0
                )
            },
        )
    }

    private func exportDensity(for payload: String) -> QRCodeExportCardDensity {
        if contentDraft.kind == .contact {
            return .dense
        }

        if contentDraft.kind == .email, contentDraft.emailBody.nonEmpty != nil {
            return payload.count <= 240 ? .normal : .dense
        }

        if contentDraft.kind == .sms, contentDraft.smsBody.nonEmpty != nil {
            return payload.count <= 240 ? .normal : .dense
        }

        if contentDraft.kind == .event,
           contentDraft.eventLocation.nonEmpty != nil || contentDraft.eventNotes.nonEmpty != nil
        {
            return payload.count <= 240 ? .normal : .dense
        }

        if payload.count <= 120 {
            return .compact
        }

        if payload.count <= 240 {
            return .normal
        }

        return .dense
    }

    private func exportSearchMetadata(createdAt: Date) -> QRCodeExportCardSearchMetadata {
        let safeSummary = exportSafeSummary()
        let title = AppLocalization.string("export.card.title")
        let createdText = exportDateText(for: createdAt)
        var descriptionParts = [
            title,
            labeledText(
                labelKey: "export.card.type",
                value: AppLocalization.string(contentDraft.kind.titleKey)
            )
        ]

        if let detailValue = safeSummary.detailValue {
            descriptionParts.append(
                labeledText(labelKey: safeSummary.detailLabelKey, value: detailValue)
            )
        }

        if let purpose = exportPurposeDraft.nonEmpty {
            descriptionParts.append(
                labeledText(labelKey: "export.card.purpose", value: purpose)
            )
        }

        descriptionParts.append(
            labeledText(labelKey: "export.card.created", value: createdText)
        )

        let keywords = uniqueKeywords(
            [
                title,
                "QR",
                AppLocalization.string(contentDraft.kind.titleKey)
            ]
            + safeSummary.keywordValues
            + [exportPurposeDraft.nonEmpty]
        )

        return QRCodeExportCardSearchMetadata(
            title: title,
            description: descriptionParts.joined(separator: " | "),
            keywords: keywords,
            originalFilename: exportOriginalFilename(createdAt: createdAt)
        )
    }

    private func exportSafeSummary() -> ExportSafeSummary {
        switch contentDraft.kind {
        case .website:
            let address = ((try? websitePayload()) ?? contentDraft.websiteURL).nonEmpty
            let host = address.flatMap { URL(string: $0)?.host }
            return ExportSafeSummary(
                detailLabelKey: "export.card.address",
                detailValue: address,
                keywordValues: [address].compactMap { $0 },
                filenameHint: host ?? address
            )
        case .contact:
            let displayName = contentDraft.contact.flatMap { $0.displayName.nonEmpty }
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: displayName,
                keywordValues: [displayName].compactMap { $0 },
                filenameHint: displayName
            )
        case .wifi:
            guard let ssid = contentDraft.wifiSSID.nonEmpty else {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.details",
                    detailValue: nil,
                    keywordValues: [],
                    filenameHint: nil
                )
            }
            let security = AppLocalization.string(contentDraft.wifiSecurity.titleKey)
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: "\(ssid) • \(security)",
                keywordValues: [ssid, security],
                filenameHint: ssid
            )
        case .email:
            let recipient = contentDraft.emailTo.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: recipient,
                keywordValues: [recipient].compactMap { $0 },
                filenameHint: recipient
            )
        case .sms:
            let number = contentDraft.smsNumber.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: number,
                keywordValues: [number].compactMap { $0 },
                filenameHint: number
            )
        case .call:
            let number = contentDraft.callNumber.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: number,
                keywordValues: [number].compactMap { $0 },
                filenameHint: number
            )
        case .event:
            let title = contentDraft.eventTitle.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: title,
                keywordValues: [title].compactMap { $0 },
                filenameHint: title
            )
        case .location:
            if let label = contentDraft.locationLabel.nonEmpty {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.address",
                    detailValue: label,
                    keywordValues: [label],
                    filenameHint: label
                )
            }
            guard
                let latitude = parsedCoordinate(from: contentDraft.locationLatitude),
                let longitude = parsedCoordinate(from: contentDraft.locationLongitude)
            else {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.details",
                    detailValue: nil,
                    keywordValues: [],
                    filenameHint: "location"
                )
            }
            let coordinates = "\(formattedCoordinate(latitude)), \(formattedCoordinate(longitude))"
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: coordinates,
                keywordValues: [coordinates],
                filenameHint: "location"
            )
        }
    }

    private func exportDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguageStore().load().locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func exportOriginalFilename(createdAt: Date) -> String {
        let safeSummary = exportSafeSummary()
        let timestamp = exportFilenameDateText(for: createdAt)
        let components = [
            "QRToGO",
            exportFilenameTypeComponent(),
            safeSummary.filenameHint.flatMap(filenameSlug(from:)),
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

    private func exportFilenameTypeComponent() -> String {
        switch contentDraft.kind {
        case .website:
            "Website"
        case .contact:
            "Contact"
        case .wifi:
            "WiFi"
        case .email:
            "Email"
        case .sms:
            "SMS"
        case .call:
            "Call"
        case .event:
            "Event"
        case .location:
            "Location"
        }
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

    private func generatedContent() throws -> String {
        switch contentDraft.kind {
        case .website:
            return try websitePayload()
        case .contact:
            guard let contact = contentDraft.contact else {
                throw GenerateContentError.contactMissing
            }
            return contact.vCardString
        case .wifi:
            let ssid = contentDraft.wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ssid.isEmpty == false else {
                throw GenerateContentError.wifiSSIDMissing
            }
            if contentDraft.wifiSecurity != .none,
               contentDraft.wifiPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw GenerateContentError.wifiPasswordMissing
            }
            return wifiPayload()
        case .email:
            let recipient = contentDraft.emailTo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard recipient.isEmpty == false else {
                throw GenerateContentError.emailRecipientMissing
            }
            return emailPayload(for: recipient)
        case .sms:
            let number = contentDraft.smsNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard number.isEmpty == false else {
                throw GenerateContentError.smsNumberMissing
            }
            return smsPayload(for: number)
        case .call:
            let number = contentDraft.callNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard number.isEmpty == false else {
                throw GenerateContentError.phoneNumberMissing
            }
            return "tel:\(number)"
        case .event:
            let title = contentDraft.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else {
                throw GenerateContentError.eventTitleMissing
            }
            guard contentDraft.eventEndDate >= contentDraft.eventStartDate else {
                throw GenerateContentError.eventDateRangeInvalid
            }
            return eventPayload()
        case .location:
            return try locationPayload()
        }
    }

    private func websitePayload() throws -> String {
        let trimmedValue = contentDraft.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            throw GenerateContentError.websiteURLMissing
        }

        let candidateValue: String
        if trimmedValue.contains("://") {
            candidateValue = trimmedValue
        } else {
            candidateValue = "https://\(trimmedValue)"
        }

        guard let components = URLComponents(string: candidateValue),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              host.isEmpty == false,
              let url = components.url
        else {
            throw GenerateContentError.websiteURLInvalid
        }

        return url.absoluteString
    }

    private func wifiPayload() -> String {
        let ssid = escapedWiFiValue(contentDraft.wifiSSID)
        let hiddenValue = contentDraft.wifiIsHidden ? "true" : "false"

        if contentDraft.wifiSecurity == .none {
            return "WIFI:T:\(contentDraft.wifiSecurity.payloadValue);S:\(ssid);H:\(hiddenValue);;"
        }

        let password = escapedWiFiValue(contentDraft.wifiPassword)
        return "WIFI:T:\(contentDraft.wifiSecurity.payloadValue);S:\(ssid);P:\(password);H:\(hiddenValue);;"
    }

    private func emailPayload(for recipient: String) -> String {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient

        var queryItems: [URLQueryItem] = []
        let subject = contentDraft.emailSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        if subject.isEmpty == false {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        let body = contentDraft.emailBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty == false {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.string ?? "mailto:\(recipient)"
    }

    private func smsPayload(for number: String) -> String {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = number

        let body = contentDraft.smsBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty == false {
            components.queryItems = [URLQueryItem(name: "body", value: body)]
        }

        return components.string ?? "sms:\(number)"
    }

    private func eventPayload() -> String {
        let summary = escapedICSValue(contentDraft.eventTitle)
        let location = escapedICSValue(contentDraft.eventLocation)
        let notes = escapedICSValue(contentDraft.eventNotes)

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//QRToGo//EN",
            "BEGIN:VEVENT",
            "UID:\(eventUID())",
            "DTSTAMP:\(icsTimestamp(for: .now))",
            "DTSTART:\(icsTimestamp(for: contentDraft.eventStartDate))",
            "DTEND:\(icsTimestamp(for: contentDraft.eventEndDate))",
            "SUMMARY:\(summary)"
        ]

        if location.isEmpty == false {
            lines.append("LOCATION:\(location)")
        }
        if notes.isEmpty == false {
            lines.append("DESCRIPTION:\(notes)")
        }

        lines.append(contentsOf: [
            "END:VEVENT",
            "END:VCALENDAR"
        ])
        return lines.joined(separator: "\n")
    }

    private func locationPayload() throws -> String {
        guard
            let latitude = parsedCoordinate(from: contentDraft.locationLatitude),
            let longitude = parsedCoordinate(from: contentDraft.locationLongitude),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            throw GenerateContentError.locationInvalid
        }

        let coordinateText = "\(formattedCoordinate(latitude)),\(formattedCoordinate(longitude))"
        let label = contentDraft.locationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard label.isEmpty == false else {
            return "geo:\(coordinateText)"
        }

        var components = URLComponents()
        components.scheme = "geo"
        components.path = coordinateText
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(coordinateText)(\(label))")
        ]
        return components.string ?? "geo:\(coordinateText)"
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
    
    private func escapedWiFiValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ":", with: "\\:")
    }

    private func escapedICSValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func icsTimestamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private func eventUID() -> String {
        let title = contentDraft.eventTitle
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "qrtogo-\(Int(contentDraft.eventStartDate.timeIntervalSince1970))-\(title.isEmpty ? "event" : title)@local"
    }

    private func parsedCoordinate(from value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private func formattedCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

private struct ExportSafeSummary {
    let detailLabelKey: String
    let detailValue: String?
    let keywordValues: [String]
    let filenameHint: String?
}

private enum FavoriteQRCodeCreationError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        AppLocalization.string("favorites.add.error")
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
