//
//  WiFiContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct WiFiContentEditor: View {
    @Binding var wifiSSID: String
    @Binding var wifiPassword: String
    let wifiSecurity: Binding<GenerateWiFiSecurity>
    @Binding var wifiIsHidden: Bool
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.wifiSSID", text: $wifiSSID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .wifiSSID)

            Picker("generate.wifiSecurity", selection: wifiSecurity) {
                ForEach(GenerateWiFiSecurity.allCases) { security in
                    Text(LocalizedStringKey(security.titleKey)).tag(security)
                }
            }

            if wifiSecurity.wrappedValue != .none {
                SecureField("generate.wifiPassword", text: $wifiPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .wifiPassword)
            }

            Toggle("generate.wifiHidden", isOn: $wifiIsHidden)
        }
    }
}
