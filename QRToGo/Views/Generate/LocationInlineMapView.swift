//
//  LocationInlineMapView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 06/06/2026.
//

import MapKit
import SwiftUI

struct LocationInlineMapView: View {
    let selection: GenerateLocationSelection?
    let currentLabel: String
    let onSelect: (GenerateLocationSelection) -> Void
    let onOpenFullScreen: () -> Void

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                UserAnnotation()

                if let selection {
                    Marker(
                        selection.label.isEmpty
                            ? AppLocalization.string("generate.locationSelected")
                            : selection.label,
                        coordinate: CLLocationCoordinate2D(
                            latitude: selection.latitude,
                            longitude: selection.longitude
                        )
                    )
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                Button {
                    onOpenFullScreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.headline)
                        .padding(10)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel(Text("generate.locationOpenFullScreen"))
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else {
                    return
                }

                onSelect(
                    GenerateLocationSelection(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        label: currentLabel
                    )
                )
            }
            .onAppear {
                centerMapOnSelection()
            }
            .onChange(of: selection) { _, _ in
                centerMapOnSelection()
            }
        }
    }

    private func centerMapOnSelection() {
        guard let selection else {
            return
        }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: selection.latitude,
                    longitude: selection.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    }
}
