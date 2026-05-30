//
//  SettingsViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Contacts
import Observation
import UIKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class SettingsViewModel {
    private let settingsStore: QRCodeSettingsStore
    private let generatorService: QRCodeGeneratorService
    private let photoAlbumSaver: PhotoAlbumSaver

    var sampleText = QRCodeSettings.defaultSampleText
    var contentDraft = GenerateContentDraft.defaults
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
        applyPasteboardContent(force: false)
    }

    func reloadClipboardContent() {
        applyPasteboardContent(force: true)
    }

    func setContentKind(_ kind: GenerateContentKind) {
        contentDraft.kind = kind
        if kind == .clipboard {
            applyPasteboardContent(force: true)
        }
    }

    func refreshPreview() {
        validationResults = generatorService.validationResults(for: draftSettings)
        previewTask?.cancel()
        previewErrorMessage = nil
        isGeneratingPreview = true

        let settings = draftSettings
        let previewSize = min(max(settings.outputSize, 360), 768)
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
                let output = try generatorService.generate(content: content, settings: settings, outputSize: previewSize)
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

    func importSelectedFile(at url: URL) {
        do {
            contentDraft.localContent = try makeLocalContent(from: url, preferredTypeIdentifier: nil)
            statusMessage = nil
        } catch {
            statusMessage = NSLocalizedString("error.localFileImport", comment: "Local file import failed")
        }
    }

    func importSelectedMediaFile(at url: URL, preferredTypeIdentifier: String?) {
        do {
            contentDraft.localContent = try makeLocalContent(from: url, preferredTypeIdentifier: preferredTypeIdentifier)
            statusMessage = nil
        } catch {
            statusMessage = NSLocalizedString("error.localFileImport", comment: "Local file import failed")
        }
    }

    func removeSelectedLocalContent() {
        contentDraft.localContent = nil
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
            let output = try generatorService.generate(content: generatedContent(), settings: settings)
            try await photoAlbumSaver.savePNGData(output.pngData, albumName: settings.photoAlbumName)
            statusMessage = String.localizedStringWithFormat(
                NSLocalizedString("settings.savePreviewSuccess", comment: "Preview saved"),
                settings.photoAlbumName
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func applyPasteboardContent(force: Bool) {
        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        if force == false, lastSeenPasteboardChangeCount == changeCount {
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

        contentDraft.clipboardText = trimmedPastedText

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

    private func generatedContent() throws -> String {
        switch contentDraft.kind {
        case .website:
            throw GenerateContentError.websiteNotImplemented
        case .localFile:
            guard let localContent = contentDraft.localContent else {
                throw GenerateContentError.localFileMissing
            }
            return localContent.payloadString
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
        case .text:
            return sampleText
        case .clipboard:
            let clipboardText = contentDraft.clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clipboardText.isEmpty == false else {
                throw GenerateContentError.clipboardEmpty
            }
            return clipboardText
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

    private func wifiPayload() -> String {
        let ssid = escapedWiFiValue(contentDraft.wifiSSID)
        let password = escapedWiFiValue(contentDraft.wifiPassword)
        return "WIFI:T:\(contentDraft.wifiSecurity.payloadValue);S:\(ssid);P:\(password);H:\(contentDraft.wifiIsHidden ? "true" : "false");;"
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
        let vCardData = try CNContactVCardSerialization.data(with: [contact])
        let displayName =
            CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
            ?? contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? NSLocalizedString("generate.contactFallback", comment: "Contact fallback")

        return GenerateSelectedContact(
            displayName: displayName,
            vCardString: String(decoding: vCardData, as: UTF8.self)
        )
    }

    private func makeLocalContent(from url: URL, preferredTypeIdentifier: String?) throws -> GenerateSelectedLocalContent {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let directoryURL = try AppGroupConfiguration.importedFilesDirectoryURL(fileManager: fileManager)
        let fileName = url.lastPathComponent.isEmpty ? UUID().uuidString : url.lastPathComponent
        let destinationURL = directoryURL.appending(path: "\(UUID().uuidString)-\(fileName)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: url, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let contentType = values.contentType?.identifier
            ?? preferredTypeIdentifier
            ?? UTType(filenameExtension: destinationURL.pathExtension)?.identifier
            ?? UTType.data.identifier

        let payload = LocalFilePayload(
            type: "local-file",
            fileName: destinationURL.lastPathComponent,
            contentType: contentType,
            size: Int64(values.fileSize ?? 0),
            importId: destinationURL.deletingPathExtension().lastPathComponent
        )
        return GenerateSelectedLocalContent(payload: payload)
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

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
