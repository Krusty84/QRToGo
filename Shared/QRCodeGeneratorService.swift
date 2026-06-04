//
//  QRCodeGeneratorService.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import CoreGraphics
import EFQRCode
import Foundation
import UIKit

struct QRCodeRenderOutput {
    let image: UIImage
    let pngData: Data
}

enum QRCodeGeneratorError: LocalizedError {
    case emptyContent
    case iconDecodeFailed
    case renderFailed
    case exportFailed
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            AppLocalization.string("error.emptyContent")
        case .iconDecodeFailed:
            AppLocalization.string("error.iconDecode")
        case .renderFailed:
            AppLocalization.string("error.previewGenerate")
        case .exportFailed:
            AppLocalization.string("error.exportData")
        case let .underlying(error):
            error.localizedDescription
        }
    }
}

struct QRCodeGeneratorService {
    func validationResults(for settings: QRCodeSettings) -> [QRValidationResult] {
        let settings = settings.normalized()
        var results: [QRValidationResult] = []
        let contrast = contrastRatio(
            between: settings.foregroundColor.uiColor,
            and: settings.backgroundColor.uiColor
        )

        if contrast < 3 {
            results.append(.init(severity: .error, messageKey: "validation.lowContrast.error"))
        } else if contrast < 6 {
            results.append(.init(severity: .warning, messageKey: "validation.lowContrast.warning"))
        }

        if settings.centerIconEnabled && settings.centerIconImageData == nil {
            results.append(.init(severity: .warning, messageKey: "validation.iconMissing.warning"))
        }

        if settings.centerIconScale > 0.22 {
            results.append(.init(severity: .error, messageKey: "validation.iconTooLarge.error"))
        } else if settings.centerIconScale > 0.18 {
            results.append(.init(severity: .warning, messageKey: "validation.iconTooLarge.warning"))
        }

        switch settings.moduleStyle {
        case .square:
            break
        case .rounded:
            if settings.outputSize <= 512 {
                results.append(.init(severity: .warning, messageKey: "validation.moduleStyleRounded.warning"))
            }
        case .dots:
            results.append(.init(severity: .warning, messageKey: "validation.moduleStyleDots.warning"))
        }

        if settings.visualEffect != .none && settings.outputSize <= 768 {
            results.append(.init(severity: .warning, messageKey: "validation.effectFootprint.warning"))
        }

        if settings.outputSize <= 512 {
            results.append(.init(severity: .warning, messageKey: "validation.lowResolution.warning"))
        }

        return results
    }

    func generate(content: String, settings: QRCodeSettings, outputSize: Int? = nil) throws -> QRCodeRenderOutput {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty == false else {
            throw QRCodeGeneratorError.emptyContent
        }
        
        #if DEBUG
        ContactQRPayloadDiagnostics.logQRCodeInput(
            trimmedContent,
            source: "QRCodeGeneratorService.generate"
        )
        #endif

        let settings = settings.normalized()
        let finalPixelSize = max(outputSize ?? settings.outputSize, 256)
        let effectPadding = settings.visualEffect == .none ? 0 : max(Int(Double(finalPixelSize) * 0.06), 28)
        let qrPixelSize = max(finalPixelSize - (effectPadding * 2), 256)

        do {
            let generator = try EFQRCode.Generator(
                trimmedContent,
                errorCorrectLevel: settings.errorCorrectionLevel.efCorrectionLevel,
                style: try makeStyle(from: settings)
            )
            let qrImage = try generator.toImage(width: CGFloat(qrPixelSize))
            let finalImage = applyVisualEffect(
                to: qrImage,
                settings: settings,
                finalPixelSize: finalPixelSize,
                padding: effectPadding
            )
            guard let pngData = finalImage.pngData() else {
                throw QRCodeGeneratorError.exportFailed
            }
            return QRCodeRenderOutput(image: finalImage, pngData: pngData)
        } catch let error as QRCodeGeneratorError {
            throw error
        } catch {
            
         #if DEBUG
          ContactQRPayloadDiagnostics.logQRCodeFailure(
              error,
              content: trimmedContent,
              source: "QRCodeGeneratorService.generate"
          )
          #endif
            
            throw QRCodeGeneratorError.underlying(error)
        }
    }

    private func makeStyle(from settings: QRCodeSettings) throws -> EFQRCodeStyle {
        let foregroundColor = settings.foregroundColor.uiColor.cgColor
        let backgroundColor = settings.backgroundColor.uiColor.cgColor
        let quietZone = settings.quietZone.fraction
        let style = settings.moduleStyle
        let icon = try makeIcon(from: settings, borderColor: backgroundColor)
        let backdrop = EFStyleParamBackdrop(
            color: backgroundColor,
            quietzone: EFEdgeInsets(top: quietZone, left: quietZone, bottom: quietZone, right: quietZone)
        )

        return .basic(
            params: EFStyleBasicParams(
                icon: icon,
                backdrop: backdrop,
                position: EFStyleBasicParamsPosition(
                    style: style.positionStyle,
                    size: 1,
                    color: foregroundColor
                ),
                data: EFStyleBasicParamsData(
                    style: style.dataStyle,
                    scale: 1,
                    color: foregroundColor
                ),
                align: EFStyleBasicParamsAlign(
                    style: style.alignStyle,
                    size: 1,
                    color: foregroundColor
                ),
                timing: EFStyleBasicParamsTiming(
                    style: style.timingStyle,
                    size: 1,
                    color: foregroundColor
                )
            )
        )
    }

    private func makeIcon(from settings: QRCodeSettings, borderColor: CGColor) throws -> EFStyleParamIcon? {
        guard settings.hasCenterIcon else {
            return nil
        }
        guard
            let data = settings.centerIconImageData,
            let image = normalizedCGImage(from: data)
        else {
            throw QRCodeGeneratorError.iconDecodeFailed
        }
        return EFStyleParamIcon(
            image: .static(image: image),
            borderColor: borderColor,
            percentage: min(CGFloat(settings.centerIconScale), 0.24)
        )
    }

    private func normalizedCGImage(from data: Data) -> CGImage? {
        guard let image = UIImage(data: data) else {
            return nil
        }
        if let cgImage = image.cgImage {
            return cgImage
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return renderedImage.cgImage
    }

    private func applyVisualEffect(
        to qrImage: UIImage,
        settings: QRCodeSettings,
        finalPixelSize: Int,
        padding: Int
    ) -> UIImage {
        guard settings.visualEffect != .none else {
            return qrImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let size = CGSize(width: finalPixelSize, height: finalPixelSize)
        let qrRect = CGRect(
            x: padding,
            y: padding,
            width: finalPixelSize - (padding * 2),
            height: finalPixelSize - (padding * 2)
        )
        let cardRect = qrRect.insetBy(dx: -CGFloat(padding) * 0.35, dy: -CGFloat(padding) * 0.35)
        let backgroundColor = settings.backgroundColor.uiColor

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let canvasRect = CGRect(origin: .zero, size: size)
            drawCanvasBackground(
                in: context.cgContext,
                rect: canvasRect,
                backgroundColor: backgroundColor,
                foregroundColor: settings.foregroundColor.uiColor,
                effect: settings.visualEffect
            )

            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: max(CGFloat(padding), 20))

            if settings.visualEffect == .subtleCardShadow {
                context.cgContext.saveGState()
                context.cgContext.setShadow(
                    offset: CGSize(width: 0, height: max(CGFloat(padding) * 0.18, 10)),
                    blur: max(CGFloat(padding) * 0.5, 18),
                    color: UIColor.black.withAlphaComponent(0.18).cgColor
                )
                backgroundColor.setFill()
                cardPath.fill()
                context.cgContext.restoreGState()
            } else if settings.visualEffect == .roundedCardBackground {
                backgroundColor.setFill()
                cardPath.fill()
            } else if settings.visualEffect == .softBackgroundGradient {
                backgroundColor.withAlphaComponent(0.96).setFill()
                cardPath.fill()
            }

            qrImage.draw(in: qrRect.integral)
        }
    }

    private func drawCanvasBackground(
        in context: CGContext,
        rect: CGRect,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        effect: QRVisualEffect
    ) {
        switch effect {
        case .none:
            backgroundColor.setFill()
            context.fill(rect)
        case .subtleCardShadow, .roundedCardBackground:
            backgroundColor.mixed(with: foregroundColor, amount: 0.03).setFill()
            context.fill(rect)
        case .softBackgroundGradient:
            let colors = [
                backgroundColor.mixed(with: .white, amount: 0.18).cgColor,
                backgroundColor.mixed(with: foregroundColor, amount: 0.08).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.minY),
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
            } else {
                backgroundColor.setFill()
                context.fill(rect)
            }
        }
    }

    private func contrastRatio(between firstColor: UIColor, and secondColor: UIColor) -> Double {
        let first = relativeLuminance(for: firstColor)
        let second = relativeLuminance(for: secondColor)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(for color: UIColor) -> Double {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func adjust(_ component: CGFloat) -> Double {
            let value = Double(component)
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * adjust(red)) + (0.7152 * adjust(green)) + (0.0722 * adjust(blue))
    }
}

private extension QRCodeErrorCorrectionLevel {
    var efCorrectionLevel: EFCorrectionLevel {
        switch self {
        case .low: .l
        case .medium: .m
        case .quartile: .q
        case .high: .h
        }
    }
}

private extension QRModuleStyle {
    var dataStyle: EFStyleBasicParamsDataStyle {
        switch self {
        case .square: .rectangle
        case .rounded: .roundedRectangle
        case .dots: .round
        }
    }

    var positionStyle: EFStyleParamsPositionStyle {
        switch self {
        case .square: .rectangle
        case .rounded: .roundedRectangle
        case .dots: .round
        }
    }

    var alignStyle: EFStyleParamAlignStyle {
        switch self {
        case .square: .rectangle
        case .rounded: .roundedRectangle
        case .dots: .round
        }
    }

    var timingStyle: EFStyleParamTimingStyle {
        switch self {
        case .square: .rectangle
        case .rounded: .roundedRectangle
        case .dots: .round
        }
    }

}

private extension UIColor {
    func mixed(with color: UIColor, amount: CGFloat) -> UIColor {
        let amount = min(max(amount, 0), 1)
        var leftRed = CGFloat.zero
        var leftGreen = CGFloat.zero
        var leftBlue = CGFloat.zero
        var leftAlpha = CGFloat.zero
        var rightRed = CGFloat.zero
        var rightGreen = CGFloat.zero
        var rightBlue = CGFloat.zero
        var rightAlpha = CGFloat.zero

        getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha)
        color.getRed(&rightRed, green: &rightGreen, blue: &rightBlue, alpha: &rightAlpha)

        return UIColor(
            red: leftRed + ((rightRed - leftRed) * amount),
            green: leftGreen + ((rightGreen - leftGreen) * amount),
            blue: leftBlue + ((rightBlue - leftBlue) * amount),
            alpha: leftAlpha + ((rightAlpha - leftAlpha) * amount)
        )
    }
}
