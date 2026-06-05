//
//  QRCodeExportCardRenderer.swift
//  QRToGo
//
//  Created by Codex on 31/05/2026.
//

import ImageIO
import UniformTypeIdentifiers
import UIKit

enum QRCodeExportCardDensity {
    case compact
    case normal
    case dense
}

struct QRCodeExportCardMetadata {
    let title: String
    let titleTypeText: String
    let titleIconSystemName: String?
    let density: QRCodeExportCardDensity
    let detailLine: QRCodeExportCardLine?
    let createdLine: QRCodeExportCardLine
    let purposeLine: QRCodeExportCardLine?
}

struct QRCodeExportCardSearchMetadata {
    let title: String
    let description: String
    let keywords: [String]
    let originalFilename: String
}

struct QRCodeExportCardLine {
    let label: String
    let value: String
}

struct QRCodeExportCardRenderer {
    func render(
        qrImage: UIImage,
        metadata: QRCodeExportCardMetadata,
        searchMetadata: QRCodeExportCardSearchMetadata? = nil
    ) throws -> QRCodeRenderOutput {
        let layout = QRCodeExportCardLayout(metadata: metadata)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: layout.canvasSize, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            layout.backgroundColor.setFill()
            cgContext.fill(CGRect(origin: .zero, size: layout.canvasSize))

            drawTitle(
                metadata: metadata,
                in: layout.titleRect,
                layout: layout
            )

            if let detailLine = metadata.detailLine, let detailLineRect = layout.detailLineRect {
                drawAttributedText(
                    attributedLine(for: detailLine, alignment: .center, layout: layout),
                    in: detailLineRect
                )
            }

            cgContext.saveGState()
            cgContext.interpolationQuality = .none
            qrImage.draw(in: layout.qrRect)
            cgContext.restoreGState()

            let infoCardPath = UIBezierPath(
                roundedRect: layout.infoCardRect,
                cornerRadius: layout.infoCardCornerRadius
            )
            layout.infoCardColor.setFill()
            infoCardPath.fill()
            layout.infoCardBorderColor.setStroke()
            infoCardPath.lineWidth = 1
            infoCardPath.stroke()

            drawAttributedText(
                attributedLine(for: metadata.createdLine, alignment: .left, layout: layout),
                in: layout.createdLineRect
            )

            if let purposeLine = metadata.purposeLine, let purposeLineRect = layout.purposeLineRect {
                drawAttributedText(
                    attributedLine(for: purposeLine, alignment: .right, layout: layout),
                    in: purposeLineRect
                )
            }
        }

        guard let pngData = pngData(for: image, searchMetadata: searchMetadata) else {
            throw QRCodeGeneratorError.exportFailed
        }

        return QRCodeRenderOutput(image: image, pngData: pngData)
    }

    private func drawTitle(
        metadata: QRCodeExportCardMetadata,
        in rect: CGRect,
        layout: QRCodeExportCardLayout
    ) {
        drawAttributedText(
            attributedTitle(for: metadata, layout: layout),
            in: rect
        )
    }

    private func attributedTitle(
        for metadata: QRCodeExportCardMetadata,
        layout: QRCodeExportCardLayout
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let title = NSMutableAttributedString(
            string: metadata.title,
            attributes: [
                .font: layout.titleFont,
                .foregroundColor: layout.primaryTextColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        title.append(
            NSAttributedString(
                string: " (",
                attributes: [
                    .font: layout.titleAccessoryFont,
                    .foregroundColor: layout.primaryTextColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        )

        if let iconImage = titleIconImage(systemName: metadata.titleIconSystemName, layout: layout) {
            let attachment = NSTextAttachment()
            attachment.image = iconImage
            attachment.bounds = CGRect(
                x: 0,
                y: layout.titleIconVerticalOffset,
                width: layout.titleIconSize,
                height: layout.titleIconSize
            )
            title.append(NSAttributedString(attachment: attachment))
            title.append(
                NSAttributedString(
                    string: " ",
                    attributes: [
                        .font: layout.titleAccessoryFont,
                        .foregroundColor: layout.primaryTextColor,
                        .paragraphStyle: paragraphStyle
                    ]
                )
            )
        }

        title.append(
            NSAttributedString(
                string: "\(metadata.titleTypeText))",
                attributes: [
                    .font: layout.titleAccessoryFont,
                    .foregroundColor: layout.primaryTextColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        )

        return title
    }

    private func titleIconImage(
        systemName: String?,
        layout: QRCodeExportCardLayout
    ) -> UIImage? {
        guard let systemName else {
            return nil
        }
        let configuration = UIImage.SymbolConfiguration(
            pointSize: layout.titleIconSize,
            weight: .semibold
        )
        return UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(layout.primaryTextColor, renderingMode: .alwaysOriginal)
    }

    private func attributedLine(
        for line: QRCodeExportCardLine,
        alignment: NSTextAlignment,
        layout: QRCodeExportCardLayout
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributedText = NSMutableAttributedString(
            string: "\(line.label): ",
            attributes: [
                .font: layout.infoLabelFont,
                .foregroundColor: layout.secondaryTextColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedText.append(
            NSAttributedString(
                string: line.value,
                attributes: [
                    .font: layout.infoValueFont,
                    .foregroundColor: layout.primaryTextColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        )
        return attributedText
    }

    private func drawAttributedText(
        _ text: NSAttributedString,
        in rect: CGRect
    ) {
        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }

    private func pngData(
        for image: UIImage,
        searchMetadata: QRCodeExportCardSearchMetadata?
    ) -> Data? {
        guard let searchMetadata, let cgImage = image.cgImage else {
            return image.pngData()
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return image.pngData()
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            pngProperties(for: searchMetadata) as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            return image.pngData()
        }

        return data as Data
    }

    private func pngProperties(
        for searchMetadata: QRCodeExportCardSearchMetadata
    ) -> [CFString: Any] {
        let pngMetadata: [CFString: Any] = [
            kCGImagePropertyPNGTitle: searchMetadata.title,
            kCGImagePropertyPNGDescription: searchMetadata.description,
            kCGImagePropertyPNGSoftware: searchMetadata.title,
            kCGImagePropertyPNGComment: searchMetadata.description
        ]

        let tiffMetadata: [CFString: Any] = [
            kCGImagePropertyTIFFDocumentName: searchMetadata.originalFilename,
            kCGImagePropertyTIFFImageDescription: searchMetadata.description,
            kCGImagePropertyTIFFSoftware: searchMetadata.title
        ]

        var properties: [CFString: Any] = [
            kCGImagePropertyPNGDictionary: pngMetadata,
            kCGImagePropertyTIFFDictionary: tiffMetadata
        ]

        if searchMetadata.keywords.isEmpty == false {
            properties[kCGImagePropertyIPTCDictionary] = [
                kCGImagePropertyIPTCObjectName: searchMetadata.title,
                kCGImagePropertyIPTCCaptionAbstract: searchMetadata.description,
                kCGImagePropertyIPTCKeywords: searchMetadata.keywords
            ]
        }

        return properties
    }
}

private struct QRCodeExportCardLayout {
    let canvasSize: CGSize
    let titleRect: CGRect
    let detailLineRect: CGRect?
    let qrRect: CGRect
    let infoCardRect: CGRect
    let createdLineRect: CGRect
    let purposeLineRect: CGRect?

    let backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    let infoCardColor = UIColor.white
    let infoCardBorderColor = UIColor(red: 0.87, green: 0.89, blue: 0.93, alpha: 1)
    let primaryTextColor = UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
    let secondaryTextColor = UIColor(red: 0.38, green: 0.42, blue: 0.50, alpha: 1)

    let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
    let titleAccessoryFont = UIFont.systemFont(ofSize: 48, weight: .semibold)
    let infoLabelFont = UIFont.systemFont(ofSize: 24, weight: .semibold)
    let infoValueFont = UIFont.systemFont(ofSize: 28, weight: .regular)

    let infoCardCornerRadius: CGFloat = 34
    var titleIconSize: CGFloat { 44 }
    var titleIconVerticalOffset: CGFloat { -6 }

    init(metadata: QRCodeExportCardMetadata) {
        let canvasWidth: CGFloat = 1080
        let horizontalPadding: CGFloat = 72
        let topPadding: CGFloat = 78
        let titleDetailSpacing: CGFloat = 10
        let detailQRSpacing: CGFloat = 34
        let qrBottomSpacing: CGFloat = 56
        let bottomPadding: CGFloat = 84
        let infoInnerPadding: CGFloat = 36
        let topRowSpacing: CGFloat = 24

        let contentWidth = canvasWidth - (horizontalPadding * 2)
        let titleRect = CGRect(
            x: horizontalPadding,
            y: topPadding,
            width: contentWidth,
            height: ceil(max(titleFont.lineHeight, titleAccessoryFont.lineHeight))
        ).integral

        var detailLineRect: CGRect?
        var qrOriginY = titleRect.maxY
        if metadata.detailLine != nil {
            detailLineRect = CGRect(
                x: horizontalPadding,
                y: titleRect.maxY + titleDetailSpacing,
                width: contentWidth,
                height: ceil(max(infoLabelFont.lineHeight, infoValueFont.lineHeight))
            ).integral
            qrOriginY = detailLineRect!.maxY
        }
        qrOriginY += detailQRSpacing

        let qrSize = Self.qrSize(for: metadata.density, contentWidth: contentWidth)
        let qrRect = CGRect(
            x: (canvasWidth - qrSize) / 2,
            y: qrOriginY,
            width: qrSize,
            height: qrSize
        ).integral

        let infoCardWidth = canvasWidth - (horizontalPadding * 2)
        let infoTextWidth = infoCardWidth - (infoInnerPadding * 2)
        let infoCardOriginY = qrRect.maxY + qrBottomSpacing
        
        let topRowY = infoCardOriginY + infoInnerPadding
        let topRowHeight = ceil(max(infoLabelFont.lineHeight, infoValueFont.lineHeight))
        let leadingColumnWidth = floor(infoTextWidth * 0.38)
        let trailingColumnWidth = infoTextWidth - leadingColumnWidth - topRowSpacing

        let createdLineRect = CGRect(
            x: horizontalPadding + infoInnerPadding,
            y: topRowY,
            width: leadingColumnWidth,
            height: topRowHeight
        ).integral

        let purposeLineRect: CGRect?
        if metadata.purposeLine != nil {
            purposeLineRect = CGRect(
                x: createdLineRect.maxX + topRowSpacing,
                y: topRowY,
                width: trailingColumnWidth,
                height: topRowHeight
            ).integral
        } else {
            purposeLineRect = nil
        }

        let currentY = topRowY + topRowHeight

        let infoCardRect = CGRect(
            x: horizontalPadding,
            y: infoCardOriginY,
            width: infoCardWidth,
            height: (currentY - infoCardOriginY) + infoInnerPadding
        ).integral

        canvasSize = CGSize(
            width: canvasWidth,
            height: infoCardRect.maxY + bottomPadding
        )
        self.titleRect = titleRect
        self.detailLineRect = detailLineRect
        self.qrRect = qrRect
        self.infoCardRect = infoCardRect
        self.createdLineRect = createdLineRect
        self.purposeLineRect = purposeLineRect
    }

    private static func qrSize(
        for density: QRCodeExportCardDensity,
        contentWidth: CGFloat
    ) -> CGFloat {
        switch density {
        case .compact:
            min(contentWidth, 820)
        case .normal:
            min(contentWidth, 740)
        case .dense:
            min(contentWidth, 680)
        }
    }
}
