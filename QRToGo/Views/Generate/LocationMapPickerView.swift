//
//  LocationMapPickerView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 06/06/2026.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

struct LocationMapPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = CurrentLocationProvider()

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var label: String

    let onSelect: (GenerateLocationSelection) -> Void

    init(
        initialSelection: GenerateLocationSelection?,
        onSelect: @escaping (GenerateLocationSelection) -> Void
    ) {
        self.onSelect = onSelect

        let initialCoordinate = initialSelection.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        } ?? CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)

        _selectedCoordinate = State(initialValue: initialCoordinate)

        _label = State(initialValue: initialSelection?.label ?? "")

        _cameraPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: initialCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $cameraPosition, interactionModes: .all) {
                        UserAnnotation()
                    }
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .overlay {
                        LocationCenterPinView(iconSize: 34, dotSize: 6, yOffset: -18)
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        selectedCoordinate = context.region.center
                    }
                }

                locationControlPanel
            }
            .navigationTitle("generate.locationChooseOnMap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label(
                            "generate.locationBackToForm",
                            systemImage: "arrow.down.right.and.arrow.up.left"
                        )
                    }
                }
            }
            .onReceive(locationProvider.$currentSelection.compactMap { $0 }) { selection in
                let coordinate = CLLocationCoordinate2D(
                    latitude: selection.latitude,
                    longitude: selection.longitude
                )

                selectedCoordinate = coordinate
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
            .alert(
                "generate.locationUnavailableTitle",
                isPresented: Binding(
                    get: { locationProvider.errorMessage != nil },
                    set: { newValue in
                        if newValue == false {
                            locationProvider.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("share.close", role: .cancel) {}
            } message: {
                Text(locationProvider.errorMessage ?? "")
            }
        }
    }

    private func useSelectedLocation() {
        guard let selectedCoordinate else {
            return
        }

        onSelect(
            GenerateLocationSelection(
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
                label: label
            )
        )
    }
    
    private var locationControlPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    locationProvider.requestCurrentLocation()
                } label: {
                    if locationProvider.isRequestingLocation {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)

                            Text("generate.locationLoadingShort")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("generate.locationGetCurrent", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(locationProvider.isRequestingLocation)

                Button {
                    useSelectedLocation()
                } label: {
                    Label("generate.locationUseCurrent", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCoordinate == nil)
            }

            if locationProvider.isRequestingLocation {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("generate.locationLoading")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            if let selectedCoordinate {
                HStack(spacing: 12) {
                    coordinateValueView(
                        titleKey: "generate.locationLatitude",
                        value: LocationCoordinateFormatter.display(selectedCoordinate.latitude)
                    )

                    coordinateValueView(
                        titleKey: "generate.locationLongitude",
                        value: LocationCoordinateFormatter.display(selectedCoordinate.longitude)
                    )
                }
            }

            TextField("generate.locationLabel", text: $label)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .animation(.snappy, value: locationProvider.isRequestingLocation)
    }
    
    private func coordinateValueView(titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
