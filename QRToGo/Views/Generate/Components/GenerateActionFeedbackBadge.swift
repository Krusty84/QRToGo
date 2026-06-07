//
//  GenerateActionFeedbackBadge.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct GenerateActionFeedbackBadge: View {
    let feedback: ActionFeedback?

    var body: some View {
        Group {
            if let feedback {
                Image(systemName: feedback.systemImage)
                    .foregroundStyle(feedback.color)
                    .font(.headline)
                    .accessibilityHidden(true)
            }
        }
    }
}

enum ActionFeedback: Equatable {
    case success
    case failure

    var systemImage: String {
        switch self {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success:
            .green
        case .failure:
            .red
        }
    }
}
