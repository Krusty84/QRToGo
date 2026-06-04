//
//  VCardPayloadSanitizer.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import Foundation

enum VCardPayloadSanitizer {
    static func sanitize(_ vCard: String) -> String {
        let physicalLines = vCard
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var result: [String] = []
        var skippingFoldedLine = false

        for line in physicalLines {
            guard line.isEmpty == false else {
                continue
            }

            let isContinuationLine = line.hasPrefix(" ") || line.hasPrefix("\t")

            if isContinuationLine {
                if skippingFoldedLine {
                    continue
                }

                result.append(line)
                continue
            }

            let shouldRemove = shouldRemoveVCardLine(line)
            skippingFoldedLine = shouldRemove

            if shouldRemove {
                continue
            }

            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    private static func shouldRemoveVCardLine(_ line: String) -> Bool {
        let propertyName = normalizedPropertyName(from: line)

        if propertyName.hasPrefix("X-") {
            return true
        }

        if propertyName.hasPrefix("VND-") {
            return true
        }

        if propertyName == "PHOTO" {
            return true
        }

        if propertyName == "LOGO" {
            return true
        }

        if propertyName == "SOUND" {
            return true
        }

        return false
    }

    private static func normalizedPropertyName(from line: String) -> String {
        let propertyPart = line
            .split(separator: ":", maxSplits: 1)
            .first
            .map(String.init) ?? line

        // Handles grouped vCard properties like:
        // item1.TEL;TYPE=CELL
        // item2.X-ABLabel
        let withoutGroup = propertyPart
            .split(separator: ".")
            .last
            .map(String.init) ?? propertyPart

        let propertyName = withoutGroup
            .split(separator: ";")
            .first
            .map(String.init) ?? withoutGroup

        return propertyName.uppercased()
    }
}
