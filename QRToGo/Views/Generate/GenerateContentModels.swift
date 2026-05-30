//
//  GenerateContentModels.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import Foundation

enum GenerateContentKind: String, CaseIterable, Identifiable {
    case website
    case contact
    case wifi
    case email
    case sms
    case call
    case event
    case location

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .website: "generate.kind.website"
        case .contact: "generate.kind.contact"
        case .wifi: "generate.kind.wifi"
        case .email: "generate.kind.email"
        case .sms: "generate.kind.sms"
        case .call: "generate.kind.call"
        case .event: "generate.kind.event"
        case .location: "generate.kind.location"
        }
    }

    var systemImage: String {
        switch self {
        case .website: "globe"
        case .contact: "person.crop.circle"
        case .wifi: "wifi"
        case .email: "envelope"
        case .sms: "message"
        case .call: "phone"
        case .event: "calendar"
        case .location: "location"
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

struct GenerateSelectedContact: Equatable {
    let displayName: String
    let vCardString: String
}

struct GenerateContentDraft: Equatable {
    var kind: GenerateContentKind = .wifi
    var websiteURL = ""
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
    case websiteURLMissing
    case websiteURLInvalid
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
        case .websiteURLMissing:
            AppLocalization.string("error.generateWebsiteMissing")
        case .websiteURLInvalid:
            AppLocalization.string("error.generateWebsiteInvalid")
        case .contactMissing:
            AppLocalization.string("error.generateContactMissing")
        case .wifiSSIDMissing:
            AppLocalization.string("error.generateWiFiSSIDMissing")
        case .wifiPasswordMissing:
            AppLocalization.string("error.generateWiFiPasswordMissing")
        case .emailRecipientMissing:
            AppLocalization.string("error.generateEmailRecipientMissing")
        case .smsNumberMissing:
            AppLocalization.string("error.generateSMSNumberMissing")
        case .phoneNumberMissing:
            AppLocalization.string("error.generatePhoneNumberMissing")
        case .eventTitleMissing:
            AppLocalization.string("error.generateEventTitleMissing")
        case .eventDateRangeInvalid:
            AppLocalization.string("error.generateEventDateRangeInvalid")
        case .locationInvalid:
            AppLocalization.string("error.generateLocationInvalid")
        }
    }
}
