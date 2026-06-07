//
//  CallContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct CallContentEditor: View {
    @Binding var callNumber: String
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        TextField("generate.callNumber", text: $callNumber)
            .keyboardType(.phonePad)
            .focused($focusedField, equals: .callNumber)
    }
}
