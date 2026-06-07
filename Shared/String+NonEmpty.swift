//
//  String+NonEmpty.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import Foundation

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
