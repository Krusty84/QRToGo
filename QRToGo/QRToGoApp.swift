//
//  QRToGoApp.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

@main
struct QRToGoApp: App {
    @UIApplicationDelegateAdaptor(QRToGoAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
