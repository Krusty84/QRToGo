//
//  SMSContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct SMSContentEditor: View {
    @Binding var smsNumber: String
    @Binding var smsBody: String
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.smsNumber", text: $smsNumber)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .smsNumber)

            TextField("generate.smsMessage", text: $smsBody, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .smsBody)
        }
    }
}
