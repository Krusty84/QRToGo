//
//  LocationContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct LocationContentEditor: View {
    @Binding var latitude: String
    @Binding var longitude: String
    @Binding var label: String
    let selectedLocation: GenerateLocationSelection?
    let onSelectLocation: (GenerateLocationSelection) -> Void
    let onOpenFullScreenMap: () -> Void
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("generate.locationLatitude", text: $latitude)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .locationLatitude)

                TextField("generate.locationLongitude", text: $longitude)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .locationLongitude)
            }

            LocationInlineMapView(
                selection: selectedLocation,
                currentLabel: label,
                onSelect: onSelectLocation,
                onOpenFullScreen: onOpenFullScreenMap
            )

            TextField("generate.locationLabel", text: $label)
                .focused($focusedField, equals: .locationLabel)
        }
    }
}
