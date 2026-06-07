//
//  ShareExportMetadataBuilder.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

struct ShareExportMetadataBuilder {
    let candidate: SharedInputCandidate

    func exportCardMetadata(createdAt: Date) -> QRCodeExportCardMetadata {
        let summary = exportSafeSummary()

        return QRCodeExportCardMetadata(
            title: AppLocalization.string("export.card.title"),
            titleTypeText: summary.typeText,
            titleIconSystemName: summary.iconSystemName,
            density: exportDensity(),
            detailLine: summary.detailValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string(summary.detailLabelKey),
                    value: $0
                )
            },
            createdLine: QRCodeExportCardLine(
                label: AppLocalization.string("export.card.created"),
                value: QRCodeExportMetadataUtilities.exportDateText(for: createdAt)
            ),
            purposeLine: summary.purposeValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string("export.card.purpose"),
                    value: $0
                )
            }
        )
    }

    func exportSearchMetadata(createdAt: Date) -> QRCodeExportCardSearchMetadata {
        let summary = exportSafeSummary()
        let title = AppLocalization.string("export.card.title")
        let createdText = QRCodeExportMetadataUtilities.exportDateText(for: createdAt)
        var descriptionParts = [
            title,
            QRCodeExportMetadataUtilities.labeledText(
                labelKey: "export.card.type",
                value: summary.typeText
            )
        ]

        if let detailValue = summary.detailValue {
            descriptionParts.append(
                QRCodeExportMetadataUtilities.labeledText(
                    labelKey: summary.detailLabelKey,
                    value: detailValue
                )
            )
        }

        if let purposeValue = summary.purposeValue {
            descriptionParts.append(
                QRCodeExportMetadataUtilities.labeledText(
                    labelKey: "export.card.purpose",
                    value: purposeValue
                )
            )
        }

        descriptionParts.append(
            QRCodeExportMetadataUtilities.labeledText(
                labelKey: "export.card.created",
                value: createdText
            )
        )

        let keywords = QRCodeExportMetadataUtilities.uniqueKeywords(
            [
                title,
                "QR",
                summary.typeText
            ]
            + summary.keywordValues
            + [summary.purposeValue]
        )

        return QRCodeExportCardSearchMetadata(
            title: title,
            description: descriptionParts.joined(separator: " | "),
            keywords: keywords,
            originalFilename: exportOriginalFilename(for: summary, createdAt: createdAt)
        )
    }

    private func exportDensity() -> QRCodeExportCardDensity {
        if candidate.kind == .contact {
            return .dense
        }

        if candidate.content.count <= 120 {
            return .compact
        }

        if candidate.content.count <= 240 {
            return .normal
        }

        return .dense
    }

    private func exportSafeSummary() -> ShareExportSafeSummary {
        switch candidate.kind {
        case .webURL:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string("generate.kind.website"),
                iconSystemName: "globe",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "Website",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .telegramLink:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "paperplane",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "Telegram",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .remoteFileURL:
            let address = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "link",
                detailLabelKey: "export.card.address",
                detailValue: address,
                purposeValue: exportPurposeValue(detailValue: address),
                keywordValues: [address].compactMap { $0 },
                filenameTypeComponent: "RemoteFile",
                filenameHint: urlFilenameHint(from: address) ?? address
            )
        case .text:
            let details = candidate.previewValue.nonEmpty ?? candidate.content.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "doc.text",
                detailLabelKey: "export.card.details",
                detailValue: details,
                purposeValue: nil,
                keywordValues: [details].compactMap { $0 },
                filenameTypeComponent: "Text",
                filenameHint: details
            )
        case .contact:
            let details = candidate.previewValue.nonEmpty ?? candidate.sourceTitle?.nonEmpty
            return ShareExportSafeSummary(
                typeText: AppLocalization.string(candidate.kind.titleKey),
                iconSystemName: "person.crop.circle",
                detailLabelKey: "export.card.details",
                detailValue: details,
                purposeValue: nil,
                keywordValues: [details].compactMap { $0 },
                filenameTypeComponent: "Contact",
                filenameHint: candidate.sourceTitle?.nonEmpty ?? details
            )
        }
    }

    private func exportPurposeValue(detailValue: String?) -> String? {
        guard let purpose = candidate.sourceTitle?.nonEmpty else {
            return nil
        }
        guard purpose != detailValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return purpose
    }

    private func exportOriginalFilename(
        for summary: ShareExportSafeSummary,
        createdAt: Date
    ) -> String {
        let timestamp = QRCodeExportMetadataUtilities.exportFilenameDateText(for: createdAt)
        let components = [
            "QRToGO",
            summary.filenameTypeComponent,
            summary.filenameHint.flatMap(QRCodeExportMetadataUtilities.filenameSlug(from:)),
            timestamp
        ].compactMap { $0 }

        let baseName = components.joined(separator: "-")
        let truncatedBaseName = String(baseName.prefix(92))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(truncatedBaseName).png"
    }

    private func urlFilenameHint(from value: String?) -> String? {
        guard
            let value,
            let url = URL(string: value)
        else {
            return nil
        }

        var components: [String] = []
        if let host = url.host?.nonEmpty {
            components.append(host)
        }
        let pathComponents = url.pathComponents
            .filter { $0 != "/" }
            .prefix(2)
        components.append(contentsOf: pathComponents)

        let hint = components.joined(separator: "-")
        return hint.nonEmpty
    }
}

private struct ShareExportSafeSummary {
    let typeText: String
    let iconSystemName: String?
    let detailLabelKey: String
    let detailValue: String?
    let purposeValue: String?
    let keywordValues: [String]
    let filenameTypeComponent: String
    let filenameHint: String?
}
