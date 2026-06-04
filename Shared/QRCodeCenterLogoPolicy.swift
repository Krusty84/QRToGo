//
//  QRCodeCenterLogoPolicy.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import CoreGraphics
import Foundation

enum QRCodeCenterLogoPolicy {
    static func resolvedScale(
        requestedScale: Double,
        content: String,
        settings: QRCodeSettings,
        qrPixelSize: Int
    ) -> CGFloat {
        let byteCount = content.data(using: .utf8)?.count ?? content.count
        let requested = min(max(requestedScale, 0.10), 0.24)

        let maxByPayload = maxScaleByPayload(byteCount)
        let maxByCorrection = maxScaleByCorrection(settings.errorCorrectionLevel)
        let maxByPixelSize = maxScaleByPixelSize(qrPixelSize)

        let resolved = min(requested, maxByPayload, maxByCorrection, maxByPixelSize)
        return CGFloat(resolved)
    }

    private static func maxScaleByPayload(_ byteCount: Int) -> Double {
        if byteCount <= 500 {
            return 0.24
        }

        if byteCount <= 900 {
            return 0.22
        }

        if byteCount <= 1300 {
            return 0.20
        }

        if byteCount <= 1800 {
            return 0.18
        }

        return 0.14
    }

    private static func maxScaleByCorrection(_ level: QRCodeErrorCorrectionLevel) -> Double {
        switch level {
        case .high:
            return 0.24
        case .quartile:
            return 0.21
        case .medium:
            return 0.18
        case .low:
            return 0.12
        }
    }

    private static func maxScaleByPixelSize(_ qrPixelSize: Int) -> Double {
        if qrPixelSize >= 1024 {
            return 0.24
        }

        if qrPixelSize >= 768 {
            return 0.22
        }

        if qrPixelSize >= 512 {
            return 0.20
        }

        return 0.18
    }
}
