//
//  QRCodeExportMetadataUtilities.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

enum QRCodeExportMetadataUtilities {
    static func exportDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguageStore().load().locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMM yy"
        return formatter.string(from: date)
    }

    static func exportFilenameDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    static func filenameSlug(from value: String) -> String? {
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

    static func labeledText(labelKey: String, value: String) -> String {
        "\(AppLocalization.string(labelKey)): \(value)"
    }

    static func uniqueKeywords(_ values: [String?]) -> [String] {
        var seen: Set<String> = []
        var uniqueValues: [String] = []

        for value in values {
            guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  trimmedValue.isEmpty == false
            else {
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
