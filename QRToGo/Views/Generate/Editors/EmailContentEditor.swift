//
//  EmailContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct EmailContentEditor: View {
    @Binding var emailTo: String
    @Binding var emailSubject: String
    @Binding var emailBody: String
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.emailRecipient", text: $emailTo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .emailRecipient)

            TextField("generate.emailSubject", text: $emailSubject, axis: .vertical)
                .focused($focusedField, equals: .emailSubject)

            TextField("generate.emailBody", text: $emailBody, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .emailBody)
        }
    }
}
