//
//  ImageCropView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 01/06/2026.
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    private let image: UIImage
    private let outputSize: Int
    private let onCancel: () -> Void
    private let onUseImage: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropSide: CGFloat = 1

    init(
        image: UIImage,
        outputSize: Int,
        onCancel: @escaping () -> Void,
        onUseImage: @escaping (Data) -> Void
    ) {
        self.image = image.normalizedForCrop()
        self.outputSize = outputSize
        self.onCancel = onCancel
        self.onUseImage = onUseImage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("settings.crop.hint")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GeometryReader { proxy in
                    let side = max(min(proxy.size.width, proxy.size.height), 1)

                    cropCanvas(cropSide: side)
                        .frame(width: side, height: side)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .aspectRatio(1, contentMode: .fit)

                Button("settings.crop.reset", systemImage: "arrow.counterclockwise", action: resetCrop)
                    .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("settings.crop.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("settings.crop.cancel", role: .cancel, action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.crop.useImage", action: useImage)
                        .disabled(cropSide <= 1)
                }
            }
        }
    }

    private func cropCanvas(cropSide: CGFloat) -> some View {
        let displaySize = displaySize(cropSide: cropSide, scale: scale)
        let visibleOffset = clampedOffset(offset, cropSide: cropSide, scale: scale)

        return ZStack {
            Color(uiColor: .secondarySystemBackground)

            Image(uiImage: image)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(visibleOffset)
        }
        .frame(width: cropSide, height: cropSide)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.35), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(cropSide: cropSide))
        .simultaneousGesture(zoomGesture(cropSide: cropSide))
        .onAppear {
            updateCropSide(cropSide)
        }
        .onChange(of: cropSide) { _, newValue in
            updateCropSide(newValue)
        }
    }

    private func dragGesture(cropSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposedOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposedOffset, cropSide: cropSide, scale: scale)
            }
            .onEnded { value in
                let proposedOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposedOffset, cropSide: cropSide, scale: scale)
                lastOffset = offset
            }
    }

    private func zoomGesture(cropSide: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = clampedScale(lastScale * value)
                offset = clampedOffset(offset, cropSide: cropSide, scale: scale)
            }
            .onEnded { value in
                scale = clampedScale(lastScale * value)
                offset = clampedOffset(offset, cropSide: cropSide, scale: scale)
                lastScale = scale
                lastOffset = offset
            }
    }

    private func useImage() {
        guard let data = croppedPNGData() else {
            return
        }
        onUseImage(data)
    }

    private func resetCrop() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private func updateCropSide(_ newValue: CGFloat) {
        cropSide = newValue
        offset = clampedOffset(offset, cropSide: newValue, scale: scale)
        lastOffset = offset
    }

    private func clampedScale(_ proposedScale: CGFloat) -> CGFloat {
        min(max(proposedScale, 1), 6)
    }

    private func clampedOffset(_ proposedOffset: CGSize, cropSide: CGFloat, scale: CGFloat) -> CGSize {
        let displaySize = displaySize(cropSide: cropSide, scale: scale)
        let maxX = max((displaySize.width - cropSide) / 2, 0)
        let maxY = max((displaySize.height - cropSide) / 2, 0)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }

    private func displaySize(cropSide: CGFloat, scale: CGFloat) -> CGSize {
        let imageSize = image.size
        let imageWidth = max(imageSize.width, 1)
        let imageHeight = max(imageSize.height, 1)
        let baseScale = max(cropSide / imageWidth, cropSide / imageHeight)

        return CGSize(
            width: imageWidth * baseScale * scale,
            height: imageHeight * baseScale * scale
        )
    }

    private func croppedPNGData() -> Data? {
        let outputSide = CGFloat(outputSize)
        let imageSize = image.size
        guard outputSide > 0, imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let previewToOutputScale = outputSide / max(cropSide, 1)
        let baseScale = max(outputSide / imageSize.width, outputSide / imageSize.height)
        let drawSize = CGSize(
            width: imageSize.width * baseScale * scale,
            height: imageSize.height * baseScale * scale
        )
        let drawOffset = CGSize(
            width: offset.width * previewToOutputScale,
            height: offset.height * previewToOutputScale
        )
        let drawRect = CGRect(
            x: ((outputSide - drawSize.width) / 2) + drawOffset.width,
            y: ((outputSide - drawSize.height) / 2) + drawOffset.height,
            width: drawSize.width,
            height: drawSize.height
        )

        let renderedImage = UIGraphicsImageRenderer(
            size: CGSize(width: outputSide, height: outputSide),
            format: format
        ).image { _ in
            image.draw(in: drawRect)
        }

        return renderedImage.pngData()
    }
}

private extension UIImage {
    func normalizedForCrop() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    ImageCropView(
        image: UIImage(systemName: "photo") ?? UIImage(),
        outputSize: 512,
        onCancel: {},
        onUseImage: { _ in }
    )
}
