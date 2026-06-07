//
//  AppLoadingView.swift
//  QRToGo
//
//  Created by Codex on 07/06/2026.
//

import SwiftUI

struct AppLoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

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
