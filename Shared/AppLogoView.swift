//
//  AppLogoView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI
import UIKit

struct AppLogoView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if UIImage(named: "AppLogo") != nil {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}
