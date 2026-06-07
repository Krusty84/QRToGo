//
//  LocationCoordinateFormatter.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

enum LocationCoordinateFormatter {
    static func display(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func storage(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    static func parse(_ value: String) -> Double? {
        Double(
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
        )
    }
}
