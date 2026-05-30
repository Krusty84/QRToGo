//
//  LocalFilePayload.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import Foundation

struct LocalFilePayload: Codable, Equatable {
    let type: String
    let fileName: String
    let contentType: String
    let size: Int64
    let importId: String
}
