//
//  ContactContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct ContactContentEditor: View {
    let contact: GenerateSelectedContact?
    let onPickContact: () -> Void
    let onRemoveContact: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("generate.contactPick", systemImage: "person.crop.circle.badge.plus") {
                onPickContact()
            }

            if let contact {
                Label(contact.displayName, systemImage: "person.crop.circle")
                    .font(.headline)

                Button("generate.contactRemove", role: .destructive) {
                    onRemoveContact()
                }
            } else {
                GeneratePlaceholderCard(
                    titleKey: "generate.contactPlaceholder",
                    systemImage: "person.text.rectangle"
                )
            }
        }
    }
}
