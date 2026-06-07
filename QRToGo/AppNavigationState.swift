//
//  AppNavigationState.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 04/06/2026.
//

import Foundation
import Observation

enum MainTab: Hashable {
    case generate
    case favorites
    case settings
}

enum AppLaunchMode: Equatable {
    case normal
    case favoriteQuickAction(UUID)
}

@Observable
@MainActor
final class AppNavigationState {
    var launchMode: AppLaunchMode = .normal
    var selectedTab: MainTab = .generate
    var requestedFavoriteID: UUID?

    init(launchMode: AppLaunchMode = .normal) {
        self.launchMode = launchMode
    }
}
