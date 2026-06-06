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
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                centerPin
            }
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
            .onMapCameraChange(frequency: .onEnd) { context in
                let coordinate = context.region.center

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
    
    private var centerPin: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin")
                .font(.system(size: 30, weight: .semibold))

            Circle()
                .frame(width: 5, height: 5)
        }
        .offset(y: -16)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
