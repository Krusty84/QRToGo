//
//  GenerateFocusedField.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

enum GenerateFocusedField: Hashable {
    case websiteURL
    case wifiSSID
    case wifiPassword
    case emailRecipient
    case emailSubject
    case emailBody
    case smsNumber
    case smsBody
    case callNumber
    case eventTitle
    case eventLocation
    case eventNotes
    case locationLatitude
    case locationLongitude
    case locationLabel
}
