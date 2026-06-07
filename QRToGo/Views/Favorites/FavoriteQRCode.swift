//
//  FavoriteQRCode.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import Foundation

struct FavoriteQRCode: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var kind: GenerateContentKind
    var payload: String
    var settings: QRCodeSettings
    var exportPurpose: String?
    var createdAt: Date
    var updatedAt: Date
}
