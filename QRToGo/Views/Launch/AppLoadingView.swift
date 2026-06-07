//
//  AppLoadingView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct AppLoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                AppLogoView(size: 96)

                Text("QR2Go")
                    .font(.title2.weight(.semibold))

                ProgressView()
                    .padding(.top, 6)

                Text("app.loading")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

#Preview {
    AppLoadingView()
}
