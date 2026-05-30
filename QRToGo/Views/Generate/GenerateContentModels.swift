//
//  GenerateContentModels.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum GenerateContentKind: String, CaseIterable, Identifiable {
    case website
    case localFile
    case contact
    case wifi
    case text
    case clipboard
    case email
    case sms
    case call
    case event
    case location

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .website: "generate.kind.website"
        case .localFile: "generate.kind.localFile"
        case .contact: "generate.kind.contact"
        case .wifi: "generate.kind.wifi"
        case .text: "generate.kind.text"
        case .clipboard: "generate.kind.clipboard"
        case .email: "generate.kind.email"
        case .sms: "generate.kind.sms"
        case .call: "generate.kind.call"
        case .event: "generate.kind.event"
        case .location: "generate.kind.location"
        }
    }
}

enum GenerateWiFiSecurity: String, CaseIterable, Identifiable {
    case wpa
    case wep
    case none

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .wpa: "generate.wifi.security.wpa"
        case .wep: "generate.wifi.security.wep"
        case .none: "generate.wifi.security.none"
        }
    }

    var payloadValue: String {
        switch self {
        case .wpa: "WPA"
        case .wep: "WEP"
        case .none: "nopass"
        }
    }
}

struct GenerateSelectedLocalContent: Equatable {
    let payload: LocalFilePayload

    var fileName: String { payload.fileName }
    var contentType: String { payload.contentType }
    var size: Int64 { payload.size }

    var payloadString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }
}

struct GenerateSelectedContact: Equatable {
    let displayName: String
    let vCardString: String
}

struct GenerateContentDraft: Equatable {
    var kind: GenerateContentKind = .text
    var clipboardText = ""
    var localContent: GenerateSelectedLocalContent?
    var contact: GenerateSelectedContact?
    var wifiSSID = ""
    var wifiPassword = ""
    var wifiSecurity: GenerateWiFiSecurity = .wpa
    var wifiIsHidden = false
    var emailTo = ""
    var emailSubject = ""
    var emailBody = ""
    var smsNumber = ""
    var smsBody = ""
    var callNumber = ""
    var eventTitle = ""
    var eventLocation = ""
    var eventNotes = ""
    var eventStartDate = Date.now
    var eventEndDate = Date.now.addingTimeInterval(3600)
    var locationLatitude = ""
    var locationLongitude = ""
    var locationLabel = ""

    static let defaults = GenerateContentDraft()
}

enum GenerateContentError: LocalizedError {
    case websiteNotImplemented
    case clipboardEmpty
    case localFileMissing
    case contactMissing
    case wifiSSIDMissing
    case wifiPasswordMissing
    case emailRecipientMissing
    case smsNumberMissing
    case phoneNumberMissing
    case eventTitleMissing
    case eventDateRangeInvalid
    case locationInvalid

    var errorDescription: String? {
        switch self {
        case .websiteNotImplemented:
            NSLocalizedString("error.generateWebsiteUnavailable", comment: "Website unavailable")
        case .clipboardEmpty:
            NSLocalizedString("error.generateClipboardEmpty", comment: "Clipboard empty")
        case .localFileMissing:
            NSLocalizedString("error.generateLocalFileMissing", comment: "Local file missing")
        case .contactMissing:
            NSLocalizedString("error.generateContactMissing", comment: "Contact missing")
        case .wifiSSIDMissing:
            NSLocalizedString("error.generateWiFiSSIDMissing", comment: "Wi-Fi SSID missing")
        case .wifiPasswordMissing:
            NSLocalizedString("error.generateWiFiPasswordMissing", comment: "Wi-Fi password missing")
        case .emailRecipientMissing:
            NSLocalizedString("error.generateEmailRecipientMissing", comment: "Email recipient missing")
        case .smsNumberMissing:
            NSLocalizedString("error.generateSMSNumberMissing", comment: "SMS number missing")
        case .phoneNumberMissing:
            NSLocalizedString("error.generatePhoneNumberMissing", comment: "Phone number missing")
        case .eventTitleMissing:
            NSLocalizedString("error.generateEventTitleMissing", comment: "Event title missing")
        case .eventDateRangeInvalid:
            NSLocalizedString("error.generateEventDateRangeInvalid", comment: "Event date range invalid")
        case .locationInvalid:
            NSLocalizedString("error.generateLocationInvalid", comment: "Location invalid")
        }
    }
}

struct PickedMediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let sourceURL = received.file
            let destinationURL = FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appendingPathExtension(sourceURL.pathExtension)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return Self(url: destinationURL)
        }
    }
}
