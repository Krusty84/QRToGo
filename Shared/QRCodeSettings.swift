//
//  QRCodeSettings.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Foundation
import UIKit

struct QRColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(uiColor: UIColor) {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red.doubleValue, green: green.doubleValue, blue: blue.doubleValue, alpha: alpha.doubleValue)
    }

    var uiColor: UIColor {
        UIColor(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1),
            alpha: alpha.clamped(to: 0...1)
        )
    }
}

enum QRCodeErrorCorrectionLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case quartile
    case high

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .low: "option.errorCorrection.low"
        case .medium: "option.errorCorrection.medium"
        case .quartile: "option.errorCorrection.quartile"
        case .high: "option.errorCorrection.high"
        }
    }
}

enum QRQuietZonePreset: String, Codable, CaseIterable, Identifiable {
    case compact
    case normal
    case large

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .compact: "option.quietZone.compact"
        case .normal: "option.quietZone.normal"
        case .large: "option.quietZone.large"
        }
    }

    var fraction: CGFloat {
        switch self {
        case .compact: 0.18
        case .normal: 0.24
        case .large: 0.32
        }
    }
}

enum QRModuleStyle: String, Codable, CaseIterable, Identifiable {
    case square
    case rounded
    case dots

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .square: "option.moduleStyle.square"
        case .rounded: "option.moduleStyle.rounded"
        case .dots: "option.moduleStyle.dots"
        }
    }
}

enum QRCodeGenerationMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case staticImage

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .standard: "option.generationMode.standard"
        case .staticImage: "option.generationMode.staticImage"
        }
    }
}

enum QRVisualEffect: String, Codable, CaseIterable, Identifiable {
    case none
    case subtleCardShadow
    case roundedCardBackground
    case softBackgroundGradient

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .none: "option.visualEffect.none"
        case .subtleCardShadow: "option.visualEffect.subtleCardShadow"
        case .roundedCardBackground: "option.visualEffect.roundedCardBackground"
        case .softBackgroundGradient: "option.visualEffect.softBackgroundGradient"
        }
    }
}

enum QRExportFormat: String, Codable, CaseIterable, Identifiable {
    case png
    case jpeg

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .png: "option.exportFormat.png"
        case .jpeg: "option.exportFormat.jpeg"
        }
    }
}

struct QRCodeSettings: Codable, Equatable {
    var generationMode: QRCodeGenerationMode
    var foregroundColor: QRColor
    var backgroundColor: QRColor
    var errorCorrectionLevel: QRCodeErrorCorrectionLevel
    var outputSize: Int
    var quietZone: QRQuietZonePreset
    var moduleStyle: QRModuleStyle
    var staticImageData: Data?
    var centerIconEnabled: Bool
    var centerIconImageData: Data?
    var centerIconScale: Double
    var visualEffect: QRVisualEffect
    var exportFormat: QRExportFormat
    var createdAt: Date?
    var updatedAt: Date?

    static let defaultSampleText = "https://example.com"

    static var defaults: QRCodeSettings {
        QRCodeSettings(
            generationMode: .standard,
            foregroundColor: QRColor(red: 0, green: 0, blue: 0),
            backgroundColor: QRColor(red: 1, green: 1, blue: 1),
            errorCorrectionLevel: .high,
            outputSize: 768,
            quietZone: .normal,
            moduleStyle: .square,
            staticImageData: nil,
            centerIconEnabled: false,
            centerIconImageData: nil,
            centerIconScale: 0.18,
            visualEffect: .none,
            exportFormat: .png,
            createdAt: nil,
            updatedAt: nil
        )
    }

    init(
        generationMode: QRCodeGenerationMode,
        foregroundColor: QRColor,
        backgroundColor: QRColor,
        errorCorrectionLevel: QRCodeErrorCorrectionLevel,
        outputSize: Int,
        quietZone: QRQuietZonePreset,
        moduleStyle: QRModuleStyle,
        staticImageData: Data?,
        centerIconEnabled: Bool,
        centerIconImageData: Data?,
        centerIconScale: Double,
        visualEffect: QRVisualEffect,
        exportFormat: QRExportFormat,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.generationMode = generationMode
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.errorCorrectionLevel = errorCorrectionLevel
        self.outputSize = outputSize
        self.quietZone = quietZone
        self.moduleStyle = moduleStyle
        self.staticImageData = staticImageData
        self.centerIconEnabled = centerIconEnabled
        self.centerIconImageData = centerIconImageData
        self.centerIconScale = centerIconScale
        self.visualEffect = visualEffect
        self.exportFormat = exportFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasCenterIcon: Bool {
        centerIconEnabled && centerIconImageData != nil
    }

    var hasStaticImage: Bool {
        staticImageData != nil
    }

    func withUpdatedTimestamp(_ date: Date = .now) -> QRCodeSettings {
        var copy = self
        if copy.createdAt == nil {
            copy.createdAt = date
        }
        copy.updatedAt = date
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case generationMode
        case foregroundColor
        case backgroundColor
        case errorCorrectionLevel
        case outputSize
        case quietZone
        case moduleStyle
        case staticImageData
        case centerIconEnabled
        case centerIconImageData
        case centerIconScale
        case visualEffect
        case exportFormat
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = QRCodeSettings.defaults

        generationMode = try container.decodeIfPresent(QRCodeGenerationMode.self, forKey: .generationMode) ?? defaults.generationMode
        foregroundColor = try container.decodeIfPresent(QRColor.self, forKey: .foregroundColor) ?? defaults.foregroundColor
        backgroundColor = try container.decodeIfPresent(QRColor.self, forKey: .backgroundColor) ?? defaults.backgroundColor
        errorCorrectionLevel = try container.decodeIfPresent(QRCodeErrorCorrectionLevel.self, forKey: .errorCorrectionLevel) ?? defaults.errorCorrectionLevel
        outputSize = try container.decodeIfPresent(Int.self, forKey: .outputSize) ?? defaults.outputSize
        quietZone = try container.decodeIfPresent(QRQuietZonePreset.self, forKey: .quietZone) ?? defaults.quietZone
        moduleStyle = try container.decodeIfPresent(QRModuleStyle.self, forKey: .moduleStyle) ?? defaults.moduleStyle
        staticImageData = try container.decodeIfPresent(Data.self, forKey: .staticImageData)
        centerIconEnabled = try container.decodeIfPresent(Bool.self, forKey: .centerIconEnabled) ?? defaults.centerIconEnabled
        centerIconImageData = try container.decodeIfPresent(Data.self, forKey: .centerIconImageData)
        centerIconScale = try container.decodeIfPresent(Double.self, forKey: .centerIconScale) ?? defaults.centerIconScale
        visualEffect = try container.decodeIfPresent(QRVisualEffect.self, forKey: .visualEffect) ?? defaults.visualEffect
        exportFormat = try container.decodeIfPresent(QRExportFormat.self, forKey: .exportFormat) ?? defaults.exportFormat
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

private extension CGFloat {
    var doubleValue: Double { Double(self) }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> CGFloat {
        CGFloat(min(max(self, range.lowerBound), range.upperBound))
    }
}
