//
//  FavoriteQuickActionPresentationView.swift
//  QRToGo
//
//  Created by Codex on 04/06/2026.
//

import SwiftUI
import UIKit

struct FavoriteQuickActionPresentationView: View {
    let favorite: FavoriteQRCode
    let onClose: () -> Void

    @State private var previewImage: UIImage?
    @State private var hasPreviewError = false
    @State private var isGeneratingPreview = true

    private let generatorService = QRCodeGeneratorService()

    var body: some View {
        QuickActionPresentationContainer {
            VStack(spacing: 16) {
                qrPreview

                Text(favorite.name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Label {
                    Text(LocalizedStringKey(favorite.kind.titleKey))
                } icon: {
                    Image(systemName: favorite.kind.systemImage)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button("favorites.quickAction.close", action: onClose)
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding()
        }
        .task(id: favorite) {
            generatePreview()
        }
    }

    @ViewBuilder
    private var qrPreview: some View {
        if isGeneratingPreview {
            ProgressView("favorites.quickAction.loading")
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        } else if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(12)
                .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 20))
                .accessibilityLabel(Text("favorites.quickAction.preview"))
        } else if hasPreviewError {
            ContentUnavailableView(
                "favorites.quickAction.error",
                systemImage: "qrcode"
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        } else {
            ProgressView("favorites.quickAction.loading")
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private func generatePreview() {
        isGeneratingPreview = true
        hasPreviewError = false

        do {
            previewImage = try generatorService.generate(
                content: favorite.payload,
                settings: favorite.settings.normalized(),
                outputSize: min(max(favorite.settings.outputSize, 360), 768)
            ).image
        } catch {
            previewImage = nil
            hasPreviewError = true
        }

        isGeneratingPreview = false
    }
}

struct FavoriteQuickActionMissingView: View {
    let onClose: () -> Void

    var body: some View {
        QuickActionPresentationContainer {
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("favorites.quickAction.missing")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Button("favorites.quickAction.close", action: onClose)
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding()
        }
    }
}

private struct QuickActionPresentationContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            Color.black.opacity(0.08)
                .ignoresSafeArea()

            content
        }
    }
}

#Preview {
    FavoriteQuickActionMissingView { }
}
