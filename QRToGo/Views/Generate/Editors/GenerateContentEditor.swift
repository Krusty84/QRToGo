//
//  GenerateContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct GenerateContentEditor: View {
    @Binding var draft: GenerateContentDraft
    let selectedLocation: GenerateLocationSelection?
    let wifiSecurity: Binding<GenerateWiFiSecurity>
    let onPickContact: () -> Void
    let onRemoveContact: () -> Void
    let onSelectLocation: (GenerateLocationSelection) -> Void
    let onOpenFullScreenMap: () -> Void
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        switch draft.kind {
        case .website:
            WebsiteContentEditor(
                websiteURL: $draft.websiteURL,
                focusedField: $focusedField
            )
        case .contact:
            ContactContentEditor(
                contact: draft.contact,
                onPickContact: onPickContact,
                onRemoveContact: onRemoveContact
            )
        case .wifi:
            WiFiContentEditor(
                wifiSSID: $draft.wifiSSID,
                wifiPassword: $draft.wifiPassword,
                wifiSecurity: wifiSecurity,
                wifiIsHidden: $draft.wifiIsHidden,
                focusedField: $focusedField
            )
        case .email:
            EmailContentEditor(
                emailTo: $draft.emailTo,
                emailSubject: $draft.emailSubject,
                emailBody: $draft.emailBody,
                focusedField: $focusedField
            )
        case .sms:
            SMSContentEditor(
                smsNumber: $draft.smsNumber,
                smsBody: $draft.smsBody,
                focusedField: $focusedField
            )
        case .call:
            CallContentEditor(
                callNumber: $draft.callNumber,
                focusedField: $focusedField
            )
        case .event:
            EventContentEditor(
                eventTitle: $draft.eventTitle,
                eventLocation: $draft.eventLocation,
                eventNotes: $draft.eventNotes,
                eventStartDate: $draft.eventStartDate,
                eventEndDate: $draft.eventEndDate,
                focusedField: $focusedField
            )
        case .location:
            LocationContentEditor(
                latitude: $draft.locationLatitude,
                longitude: $draft.locationLongitude,
                label: $draft.locationLabel,
                selectedLocation: selectedLocation,
                onSelectLocation: onSelectLocation,
                onOpenFullScreenMap: onOpenFullScreenMap,
                focusedField: $focusedField
            )
        }
    }
}
