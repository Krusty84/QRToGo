//
//  GenerateQRQualityView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct GenerateQRQualityView: View {
    let validationResults: [QRValidationResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("settings.scannability", systemImage: "checkmark.shield")
                .font(.headline)

            if validationResults.isEmpty {
                Text("settings.scannability.safe")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                ForEach(validationResults) { result in
                    Label {
                        Text(LocalizedStringKey(result.messageKey))
                    } icon: {
                        Image(systemName: result.severity == .error ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                            .foregroundStyle(result.severity == .error ? .orange : .yellow)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
