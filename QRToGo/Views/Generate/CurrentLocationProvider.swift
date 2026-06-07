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

    func requestAuthorizationIfNeeded() {
        errorMessage = nil
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            break

        case .denied, .restricted:
            errorMessage = AppLocalization.string("generate.locationPermissionDenied")

        @unknown default:
            errorMessage = AppLocalization.string("generate.locationUnavailable")
        }
    }
    
    func requestCurrentLocation() {
        errorMessage = nil
        authorizationStatus = manager.authorizationStatus

        #if DEBUG
        print("Location authorization status:", authorizationStatus.rawValue)
        #endif

        switch authorizationStatus {
        case .notDetermined:
            pendingLocationRequest = true
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            pendingLocationRequest = false
            requestLocationAfterServicesCheck()

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

            #if DEBUG
            print("Location authorization changed:", manager.authorizationStatus.rawValue)
            #endif

            guard self.pendingLocationRequest else {
                return
            }

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.pendingLocationRequest = false
                self.requestLocationAfterServicesCheck()

            case .denied, .restricted:
                self.pendingLocationRequest = false
                self.errorMessage = AppLocalization.string("generate.locationPermissionDenied")

            case .notDetermined:
                break

            @unknown default:
                self.pendingLocationRequest = false
                self.errorMessage = AppLocalization.string("generate.locationUnavailable")
            }
        }
    }

    private func requestLocationAfterServicesCheck() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let servicesEnabled = CLLocationManager.locationServicesEnabled()

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                guard servicesEnabled else {
                    self.errorMessage = AppLocalization.string("generate.locationServicesDisabled")
                    return
                }

                self.manager.requestLocation()
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

            #if DEBUG
            print("Current location:", coordinate.latitude, coordinate.longitude)
            #endif
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        DispatchQueue.main.async {
            #if DEBUG
            print("Location error:", error.localizedDescription)
            #endif

            self.errorMessage = AppLocalization.string("generate.locationUnavailable")
        }
    }
}
