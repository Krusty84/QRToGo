//
//  QRValidationResult.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Foundation

struct QRValidationResult: Identifiable, Equatable {
    enum Severity: String, Equatable {
        case warning
        case error
    }

    let severity: Severity
    let messageKey: String

    var id: String {
        "\(severity.rawValue)-\(messageKey)"
    }
}
