//
//  EventContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct EventContentEditor: View {
    @Binding var eventTitle: String
    @Binding var eventLocation: String
    @Binding var eventNotes: String
    @Binding var eventStartDate: Date
    @Binding var eventEndDate: Date
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.eventTitle", text: $eventTitle)
                .focused($focusedField, equals: .eventTitle)

            TextField("generate.eventLocation", text: $eventLocation)
                .focused($focusedField, equals: .eventLocation)

            TextField("generate.eventNotes", text: $eventNotes, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .eventNotes)

            DatePicker("generate.eventStart", selection: $eventStartDate)
            DatePicker("generate.eventEnd", selection: $eventEndDate)
        }
    }
}
