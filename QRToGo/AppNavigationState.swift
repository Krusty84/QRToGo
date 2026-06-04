//
//  AppNavigationState.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import Foundation
import Observation

enum MainTab: Hashable {
    case generate
    case favorites
    case settings
    case about
}

@Observable
@MainActor
final class AppNavigationState {
    var selectedTab: MainTab = .generate
    var requestedFavoriteID: UUID?
}
