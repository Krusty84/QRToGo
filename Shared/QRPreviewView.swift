import SwiftUI
import UIKit

struct QRPreviewView: View {
    let image: UIImage?
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))

            if isLoading {
                ProgressView()
                    .controlSize(.large)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(18)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("settings.previewUnavailable", comment: "Preview unavailable"),
                    systemImage: "qrcode",
                    description: errorMessage.map { Text(verbatim: $0) }
                )
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    QRPreviewView(image: nil, isLoading: false, errorMessage: nil)
}
