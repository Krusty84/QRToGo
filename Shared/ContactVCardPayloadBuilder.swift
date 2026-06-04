//
//  ContactVCardPayloadBuilder.swift
//  QRToGo
//
//  Created by Codex on 03/06/2026.
//

import Contacts
import Foundation

struct ContactVCardPayload {
    let displayName: String
    let previewValue: String
    let content: String
}

enum ContactVCardPayloadBuilder {
    static func makePayload(from contact: CNContact, fallbackNameKey: String) throws -> ContactVCardPayload {
        let sanitizedContact = contact.mutableCopy() as! CNMutableContact
        // `thumbnailImageData` is derived and read-only; clearing `imageData` removes photo data from serialization.
        sanitizedContact.imageData = nil

        let contactForSerialization: CNContact = sanitizedContact
        let initialData = try CNContactVCardSerialization.data(with: [contactForSerialization])
        return try makePayload(fromVCardData: initialData, fallbackNameKey: fallbackNameKey)
    }

    static func makePayload(fromVCardData data: Data, fallbackNameKey: String) throws -> ContactVCardPayload {
        let contacts = try CNContactVCardSerialization.contacts(with: data)
        guard let primaryContact = contacts.first else {
            throw ContactVCardPayloadError.emptyContactData
        }

        let normalizedData = try CNContactVCardSerialization.data(with: contacts)
        let content = String(decoding: normalizedData, as: UTF8.self)
        let displayName = contactDisplayName(from: primaryContact, fallbackNameKey: fallbackNameKey)
        let previewValue = contactPreviewValue(from: primaryContact, fallback: displayName)

        return ContactVCardPayload(
            displayName: displayName,
            previewValue: previewValue,
            content: content
        )
    }

    private static func contactDisplayName(from contact: CNContact, fallbackNameKey: String) -> String {
        if let fullName = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           fullName.isEmpty == false
        {
            return fullName
        }

        let organizationName = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if organizationName.isEmpty == false {
            return organizationName
        }

        return AppLocalization.string(fallbackNameKey)
    }

    private static func contactPreviewValue(from contact: CNContact, fallback: String) -> String {
        if let phone = contact.phoneNumbers.first?.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
           phone.isEmpty == false
        {
            return phone
        }

        if let email = contact.emailAddresses.first?.value as String?,
           email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            return email
        }

        return fallback
    }
}

enum ContactVCardPayloadError: LocalizedError {
    case emptyContactData

    var errorDescription: String? {
        AppLocalization.string("error.generateContactMissing")
    }
}
