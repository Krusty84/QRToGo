//
//  QRCodeErrorCorrectionPolicy.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import Foundation

enum QRCodeErrorCorrectionPolicy {
    static func recommendedLevel(
        for content: String,
        settings: QRCodeSettings
    ) -> QRCodeErrorCorrectionLevel {
        let byteCount = content.data(using: .utf8)?.count ?? content.count
        let isContactPayload = looksLikeVCard(content)

        if settings.hasCenterIcon {
            return recommendedLevelForPayloadWithCenterIcon(byteCount: byteCount)
        }

        if isContactPayload {
            return recommendedLevelForContactPayload(byteCount: byteCount)
        }

        return recommendedLevelForGeneralPayload(byteCount: byteCount)
    }

    private static func recommendedLevelForContactPayload(byteCount: Int) -> QRCodeErrorCorrectionLevel {
        if byteCount <= 1050 {
            return .high
        }

        if byteCount <= 1550 {
            return .quartile
        }

        if byteCount <= 2250 {
            return .medium
        }

        return .low
    }

    private static func recommendedLevelForPayloadWithCenterIcon(byteCount: Int) -> QRCodeErrorCorrectionLevel {
        if byteCount <= 950 {
            return .high
        }

        if byteCount <= 1450 {
            return .quartile
        }

        if byteCount <= 2150 {
            return .medium
        }

        return .low
    }

    private static func recommendedLevelForGeneralPayload(byteCount: Int) -> QRCodeErrorCorrectionLevel {
        if byteCount <= 1150 {
            return .high
        }

        if byteCount <= 1550 {
            return .quartile
        }

        if byteCount <= 2250 {
            return .medium
        }

        return .low
    }

    private static func looksLikeVCard(_ content: String) -> Bool {
        let uppercased = content.uppercased()
        return uppercased.contains("BEGIN:VCARD") && uppercased.contains("END:VCARD")
    }
}
