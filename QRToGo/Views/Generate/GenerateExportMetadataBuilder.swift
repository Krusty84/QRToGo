//
//  GenerateExportMetadataBuilder.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

struct GenerateExportMetadataBuilder {
    let draft: GenerateContentDraft
    let exportPurposeDraft: String

    func exportCardMetadata(
        createdAt: Date,
        payload: String
    ) -> QRCodeExportCardMetadata {
        let safeSummary = exportSafeSummary()
        return QRCodeExportCardMetadata(
            title: AppLocalization.string("export.card.title"),
            titleTypeText: AppLocalization.string(draft.kind.titleKey),
            titleIconSystemName: draft.kind.systemImage,
            density: exportDensity(for: payload),
            detailLine: safeSummary.detailValue.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string(safeSummary.detailLabelKey),
                    value: $0
                )
            },
            createdLine: QRCodeExportCardLine(
                label: AppLocalization.string("export.card.created"),
                value: QRCodeExportMetadataUtilities.exportDateText(for: createdAt)
            ),
            purposeLine: exportPurposeDraft.nonEmpty.map {
                QRCodeExportCardLine(
                    label: AppLocalization.string("export.card.purpose"),
                    value: $0
                )
            }
        )
    }

    func exportSearchMetadata(createdAt: Date) -> QRCodeExportCardSearchMetadata {
        let safeSummary = exportSafeSummary()
        let title = AppLocalization.string("export.card.title")
        let createdText = QRCodeExportMetadataUtilities.exportDateText(for: createdAt)
        var descriptionParts = [
            title,
            QRCodeExportMetadataUtilities.labeledText(
                labelKey: "export.card.type",
                value: AppLocalization.string(draft.kind.titleKey)
            )
        ]

        if let detailValue = safeSummary.detailValue {
            descriptionParts.append(
                QRCodeExportMetadataUtilities.labeledText(
                    labelKey: safeSummary.detailLabelKey,
                    value: detailValue
                )
            )
        }

        if let purpose = exportPurposeDraft.nonEmpty {
            descriptionParts.append(
                QRCodeExportMetadataUtilities.labeledText(
                    labelKey: "export.card.purpose",
                    value: purpose
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
                AppLocalization.string(draft.kind.titleKey)
            ]
            + safeSummary.keywordValues
            + [exportPurposeDraft.nonEmpty]
        )

        return QRCodeExportCardSearchMetadata(
            title: title,
            description: descriptionParts.joined(separator: " | "),
            keywords: keywords,
            originalFilename: exportOriginalFilename(createdAt: createdAt)
        )
    }

    private func exportDensity(for payload: String) -> QRCodeExportCardDensity {
        if draft.kind == .contact {
            return .dense
        }

        if draft.kind == .email, draft.emailBody.nonEmpty != nil {
            return payload.count <= 240 ? .normal : .dense
        }

        if draft.kind == .sms, draft.smsBody.nonEmpty != nil {
            return payload.count <= 240 ? .normal : .dense
        }

        if draft.kind == .event,
           draft.eventLocation.nonEmpty != nil || draft.eventNotes.nonEmpty != nil
        {
            return payload.count <= 240 ? .normal : .dense
        }

        if payload.count <= 120 {
            return .compact
        }

        if payload.count <= 240 {
            return .normal
        }

        return .dense
    }

    private func exportSafeSummary() -> ExportSafeSummary {
        switch draft.kind {
        case .website:
            let payloadBuilder = GeneratePayloadBuilder(draft: draft)
            let address = ((try? payloadBuilder.websitePayload()) ?? draft.websiteURL).nonEmpty
            let host = address.flatMap { URL(string: $0)?.host }
            return ExportSafeSummary(
                detailLabelKey: "export.card.address",
                detailValue: address,
                keywordValues: [address].compactMap { $0 },
                filenameHint: host ?? address
            )
        case .contact:
            let displayName = draft.contact.flatMap { $0.displayName.nonEmpty }
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: displayName,
                keywordValues: [displayName].compactMap { $0 },
                filenameHint: displayName
            )
        case .wifi:
            guard let ssid = draft.wifiSSID.nonEmpty else {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.details",
                    detailValue: nil,
                    keywordValues: [],
                    filenameHint: nil
                )
            }
            let security = AppLocalization.string(draft.wifiSecurity.titleKey)
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: "\(ssid) • \(security)",
                keywordValues: [ssid, security],
                filenameHint: ssid
            )
        case .email:
            let recipient = draft.emailTo.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: recipient,
                keywordValues: [recipient].compactMap { $0 },
                filenameHint: recipient
            )
        case .sms:
            let number = draft.smsNumber.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: number,
                keywordValues: [number].compactMap { $0 },
                filenameHint: number
            )
        case .call:
            let number = draft.callNumber.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: number,
                keywordValues: [number].compactMap { $0 },
                filenameHint: number
            )
        case .event:
            let title = draft.eventTitle.nonEmpty
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: title,
                keywordValues: [title].compactMap { $0 },
                filenameHint: title
            )
        case .location:
            if let label = draft.locationLabel.nonEmpty {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.address",
                    detailValue: label,
                    keywordValues: [label],
                    filenameHint: label
                )
            }
            guard
                let latitude = GeneratePayloadBuilder.parsedCoordinate(from: draft.locationLatitude),
                let longitude = GeneratePayloadBuilder.parsedCoordinate(from: draft.locationLongitude)
            else {
                return ExportSafeSummary(
                    detailLabelKey: "export.card.details",
                    detailValue: nil,
                    keywordValues: [],
                    filenameHint: "location"
                )
            }
            let coordinates = "\(GeneratePayloadBuilder.formattedCoordinate(latitude)), \(GeneratePayloadBuilder.formattedCoordinate(longitude))"
            return ExportSafeSummary(
                detailLabelKey: "export.card.details",
                detailValue: coordinates,
                keywordValues: [coordinates],
                filenameHint: "location"
            )
        }
    }

    private func exportOriginalFilename(createdAt: Date) -> String {
        let safeSummary = exportSafeSummary()
        let timestamp = QRCodeExportMetadataUtilities.exportFilenameDateText(for: createdAt)
        let components = [
            "QRToGO",
            exportFilenameTypeComponent(),
            safeSummary.filenameHint.flatMap(QRCodeExportMetadataUtilities.filenameSlug(from:)),
            timestamp
        ].compactMap { $0 }

        let baseName = components.joined(separator: "-")
        let truncatedBaseName = String(baseName.prefix(92))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(truncatedBaseName).png"
    }

    private func exportFilenameTypeComponent() -> String {
        switch draft.kind {
        case .website:
            "Website"
        case .contact:
            "Contact"
        case .wifi:
            "WiFi"
        case .email:
            "Email"
        case .sms:
            "SMS"
        case .call:
            "Call"
        case .event:
            "Event"
        case .location:
            "Location"
        }
    }
}

private struct ExportSafeSummary {
    let detailLabelKey: String
    let detailValue: String?
    let keywordValues: [String]
    let filenameHint: String?
}
