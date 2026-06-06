//
//  CurrentLocationProvider.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 06/06/2026.
//

import CoreLocation
import Foundation
import Combine

final class CurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentSelection: GenerateLocationSelection?
    @Published var errorMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var pendingLocationRequest = false

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone

        authorizationStatus = manager.authorizationStatus
    }

    func requestCurrentLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = AppLocalization.string("generate.locationServicesDisabled")
            return
        }

        errorMessage = nil
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            pendingLocationRequest = true
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            pendingLocationRequest = false
            manager.requestLocation()

        case .denied, .restricted:
            pendingLocationRequest = false
            errorMessage = AppLocalization.string("generate.locationPermissionDenied")

        @unknown default:
            pendingLocationRequest = false
            errorMessage = AppLocalization.string("generate.locationUnavailable")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            guard self.pendingLocationRequest else {
                return
            }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.pendingLocationRequest = false
                manager.requestLocation()

            case .denied, .restricted:
                self.pendingLocationRequest = false
                self.errorMessage = AppLocalization.string("generate.locationPermissionDenied")

            default:
                break
            }
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            DispatchQueue.main.async {
                self.errorMessage = AppLocalization.string("generate.locationUnavailable")
            }
            return
        }

        let coordinate = location.coordinate

        DispatchQueue.main.async {
            self.errorMessage = nil
            self.currentSelection = GenerateLocationSelection(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        DispatchQueue.main.async {
            self.errorMessage = AppLocalization.string("generate.locationUnavailable")
        }
    }
}
