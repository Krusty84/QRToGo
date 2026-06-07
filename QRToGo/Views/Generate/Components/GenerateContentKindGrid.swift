//
//  GenerateContentKindGrid.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct GenerateContentKindGrid: View {
    let selectedKind: GenerateContentKind
    let onSelect: (GenerateContentKind) -> Void

    private let modeColumns = [
        GridItem(.adaptive(minimum: 60, maximum: 72), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: modeColumns, spacing: 8) {
            ForEach(GenerateContentKind.allCases) { kind in
                Button {
                    onSelect(kind)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: kind.systemImage)
                            .font(.body.weight(.semibold))
                        Text(LocalizedStringKey(kind.titleKey))
                            .font(.caption2.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 4)
                    .foregroundStyle(selectedKind == kind ? .white : .primary)
                    .background(
                        selectedKind == kind
                            ? Color.accentColor
                            : Color(uiColor: .secondarySystemBackground),
                        in: .rect(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
