//
//  WebsiteContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct WebsiteContentEditor: View {
    @Binding var websiteURL: String
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        TextField("generate.websiteURL", text: $websiteURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .textContentType(.URL)
            .focused($focusedField, equals: .websiteURL)
    }
}
