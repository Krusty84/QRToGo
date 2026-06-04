//
//  ContactQRPayloadDiagnostics.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 03/06/2026.
//

import Foundation

#if DEBUG
enum ContactQRPayloadDiagnostics {
    private static let maxQRCodeByteCapacity: [(level: String, bytes: Int)] = [
        ("L", 2953),
        ("M", 2331),
        ("Q", 1663),
        ("H", 1273)
    ]

    static func logVCardData(
        _ data: Data,
        source: String,
        note: String? = nil
    ) {
        let text = String(decoding: data, as: UTF8.self)
        logVCardText(text, byteCount: data.count, source: source, note: note)
    }

    static func logVCardText(
        _ text: String,
        source: String,
        note: String? = nil
    ) {
        let data = text.data(using: .utf8) ?? Data()
        logVCardText(text, byteCount: data.count, source: source, note: note)
    }

    static func logQRCodeInput(
        _ content: String,
        source: String
    ) {
        let byteCount = content.data(using: .utf8)?.count ?? 0

        print("")
        print("========== QR INPUT DIAGNOSTICS ==========")
        print("Source: \(source)")
        print("UTF-8 bytes: \(byteCount)")
        print("Characters: \(content.count)")
        print("QR byte capacity estimate: \(capacityStatus(for: byteCount))")
        print("Looks like vCard: \(content.uppercased().contains("BEGIN:VCARD"))")
        print("==========================================")
        print("")
    }

    static func logQRCodeFailure(
        _ error: Error,
        content: String,
        source: String
    ) {
        let byteCount = content.data(using: .utf8)?.count ?? 0

        print("")
        print("========== QR GENERATION FAILURE ==========")
        print("Source: \(source)")
        print("Error: \(String(describing: error))")
        print("UTF-8 bytes: \(byteCount)")
        print("Characters: \(content.count)")
        print("QR byte capacity estimate: \(capacityStatus(for: byteCount))")
        print("===========================================")
        print("")
    }

    private static func logVCardText(
        _ text: String,
        byteCount: Int,
        source: String,
        note: String?
    ) {
        let logicalLines = unfoldedVCardLines(from: text)
        let fields = analyzeFields(from: logicalLines)

        print("")
        print("========== CONTACT QR VCARD DIAGNOSTICS ==========")
        print("Source: \(source)")
        if let note {
            print("Note: \(note)")
        }
        print("UTF-8 bytes: \(byteCount)")
        print("Characters: \(text.count)")
        print("Physical lines: \(text.components(separatedBy: .newlines).count)")
        print("Logical unfolded lines: \(logicalLines.count)")
        print("QR byte capacity estimate: \(capacityStatus(for: byteCount))")

        print("")
        print("Suspicious fields:")
        printSuspicious(fields)

        print("")
        print("Top fields by byte size:")
        for field in fields.sorted(by: { $0.totalBytes > $1.totalBytes }).prefix(20) {
            print("- \(field.name): count=\(field.count), bytes=\(field.totalBytes), maxLineBytes=\(field.maxLineBytes)")
        }

        print("===================================================")
        print("")
    }

    private static func capacityStatus(for byteCount: Int) -> String {
        maxQRCodeByteCapacity
            .map { item in
                let status = byteCount <= item.bytes ? "OK" : "TOO LARGE"
                return "\(item.level)=\(item.bytes):\(status)"
            }
            .joined(separator: " | ")
    }

    private static func unfoldedVCardLines(from text: String) -> [String] {
        let physicalLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var logicalLines: [String] = []

        for line in physicalLines {
            guard line.isEmpty == false else {
                continue
            }

            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                if logicalLines.isEmpty == false {
                    logicalLines[logicalLines.count - 1] += String(line.dropFirst())
                } else {
                    logicalLines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else {
                logicalLines.append(line)
            }
        }

        return logicalLines
    }

    private static func analyzeFields(from lines: [String]) -> [FieldStats] {
        var stats: [String: FieldStats] = [:]

        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else {
                continue
            }

            let propertyPart = String(line[..<colonIndex])
            let fieldName = normalizedFieldName(from: propertyPart)
            let byteCount = line.data(using: .utf8)?.count ?? 0

            var current = stats[fieldName] ?? FieldStats(
                name: fieldName,
                count: 0,
                totalBytes: 0,
                maxLineBytes: 0
            )

            current.count += 1
            current.totalBytes += byteCount
            current.maxLineBytes = max(current.maxLineBytes, byteCount)

            stats[fieldName] = current
        }

        return Array(stats.values)
    }

    private static func normalizedFieldName(from propertyPart: String) -> String {
        // Handles forms like:
        // TEL;TYPE=CELL
        // item1.TEL;TYPE=CELL
        // item2.X-ABLabel
        let withoutGroup = propertyPart
            .split(separator: ".")
            .last
            .map(String.init) ?? propertyPart

        let name = withoutGroup
            .split(separator: ";")
            .first
            .map(String.init) ?? withoutGroup

        return name.uppercased()
    }

    private static func printSuspicious(_ fields: [FieldStats]) {
        let suspiciousPrefixes = [
            "PHOTO",
            "LOGO",
            "SOUND",
            "NOTE",
            "ADR",
            "URL",
            "BDAY",
            "ANNIVERSARY",
            "IMPP",
            "SOCIALPROFILE",
            "X-"
        ]

        let suspicious = fields.filter { field in
            suspiciousPrefixes.contains { prefix in
                field.name.hasPrefix(prefix)
            }
        }
        .sorted(by: { $0.totalBytes > $1.totalBytes })

        if suspicious.isEmpty {
            print("- none")
            return
        }

        for field in suspicious {
            print("- \(field.name): count=\(field.count), bytes=\(field.totalBytes), maxLineBytes=\(field.maxLineBytes)")
        }
    }
}

private struct FieldStats {
    let name: String
    var count: Int
    var totalBytes: Int
    var maxLineBytes: Int
}
#endif
