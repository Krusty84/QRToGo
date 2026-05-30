//
//  SettingsViewModel.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Contacts
import Observation
import UIKit

@Observable
@MainActor
final class SettingsViewModel {
    private let settingsStore: QRCodeSettingsStore
    private let appLanguageStore: AppLanguageStore
    private let generatorService: QRCodeGeneratorService
    private let photoAlbumSaver: PhotoAlbumSaver

    var appLanguage: AppLanguage = .system
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

    init(
        settingsStore: QRCodeSettingsStore? = nil,
        appLanguageStore: AppLanguageStore? = nil,
        generatorService: QRCodeGeneratorService? = nil,
        photoAlbumSaver: PhotoAlbumSaver? = nil
    ) {
        self.settingsStore = settingsStore ?? QRCodeSettingsStore()
        self.appLanguageStore = appLanguageStore ?? AppLanguageStore()
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
        refreshPreview()
    }

    func setContentKind(_ kind: GenerateContentKind) {
        contentDraft.kind = kind
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else {
            return
        }
        appLanguage = language
        appLanguageStore.save(language)
        statusMessage = nil
        refreshPreview()
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

    func setStaticImageData(_ data: Data?) {
        guard let data else {
            draftSettings.staticImageData = nil
            setGenerationMode(.standard)
            return
        }
        guard let preparedData = prepareImageData(from: data, maxDimension: 1400) else {
            statusMessage = AppLocalization.string("error.staticImageDecode")
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

    func savePreviewToPhotos() async {
        guard hasBlockingValidation == false else {
            statusMessage = AppLocalization.string("settings.fixErrorsFirst")
            return
        }

        isSavingPreview = true
        defer { isSavingPreview = false }

        do {
            let settings = draftSettings.normalized()
            let output = try generatorService.generate(content: generatedContent(), settings: settings)
            try await photoAlbumSaver.savePNGData(output.pngData, albumName: settings.photoAlbumName)
            statusMessage = String.localizedStringWithFormat(
                AppLocalization.string("settings.savePreviewSuccess"),
                settings.photoAlbumName
            )
        } catch {
            statusMessage = error.localizedDescription
        }
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
            ?? AppLocalization.string("generate.contactFallback")

        return GenerateSelectedContact(
            displayName: displayName,
            vCardString: String(decoding: vCardData, as: UTF8.self)
        )
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
