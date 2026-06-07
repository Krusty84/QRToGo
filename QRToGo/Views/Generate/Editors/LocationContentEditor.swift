//
//  LocationContentEditor.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct LocationContentEditor: View {
    @Binding var label: String
    let selectedLocation: GenerateLocationSelection?
    let isResolvingCurrentLocation: Bool
    let onSelectLocation: (GenerateLocationSelection) -> Void
    let onOpenFullScreenMap: () -> Void
    @FocusState.Binding var focusedField: GenerateFocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedLocation {
                HStack(spacing: 12) {
                    LocationCoordinateValueView(
                        titleKey: "generate.locationLatitude",
                        value: LocationCoordinateFormatter.display(selectedLocation.latitude)
                    )

                    LocationCoordinateValueView(
                        titleKey: "generate.locationLongitude",
                        value: LocationCoordinateFormatter.display(selectedLocation.longitude)
                    )
                }
            }

            LocationInlineMapView(
                selection: selectedLocation,
                isResolvingCurrentLocation: isResolvingCurrentLocation,
                currentLabel: label,
                onSelect: onSelectLocation,
                onOpenFullScreen: onOpenFullScreenMap
            )

            TextField("generate.locationLabel", text: $label)
                .focused($focusedField, equals: .locationLabel)
        }
    }
}
