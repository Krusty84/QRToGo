//
//  LocationCenterPinView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct LocationCenterPinView: View {
    let iconSize: CGFloat
    let dotSize: CGFloat
    let yOffset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin")
                .font(.system(size: iconSize, weight: .semibold))

            Circle()
                .frame(width: dotSize, height: dotSize)
        }
        .offset(y: yOffset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
