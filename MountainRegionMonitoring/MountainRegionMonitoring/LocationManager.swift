//
//  LocationManager.swift
//  MountainRegionMonitoring
//
//  Created by Jason Sanchez on 8/9/24.
//

import Foundation
import MapKit
import Observation

enum LocationError: LocalizedError {
    case authorizationDenied
    case authorizationRestricted
    case unknownLocation
    case accessDenied
    case network
    case operationFailed
    
    var errorDescription: String? {
        switch self {
            case .authorizationDenied:
                return NSLocalizedString("Location access denied.", comment: "")
            case .authorizationRestricted:
                return NSLocalizedString("Location access restricted.", comment: "")
            case .unknownLocation:
                return NSLocalizedString("Unknown location.", comment: "")
            case .accessDenied:
                return NSLocalizedString("Access denied.", comment: "")
            case .network:
                return NSLocalizedString("Network failed.", comment: "")
            case .operationFailed:
                return NSLocalizedString("Operation failed.", comment: "")
        }
    }
}

struct LocationEvent: Identifiable {
    let id = UUID()
    let indentifier: String
}

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    
    let manager = CLLocationManager()
    static let shared = LocationManager()
    var error: LocationError? = nil
    var monitor: CLMonitor?
    var locationEvent: LocationEvent?
    
    var region: MKCoordinateRegion = MKCoordinateRegion()
    
    private override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.manager.delegate = self
    }
    
    func startRegionMonitoring() async {
        monitor = await CLMonitor("MountainRegionMonitor")
        await monitor?.add(CLMonitor.CircularGeographicCondition.beaverCreekResort, identifier: "beaverCreekResort", assuming: .unsatisfied)
        await monitor?.add(CLMonitor.CircularGeographicCondition.vailMountainVillage, identifier: "vailMountainVillage", assuming: .unsatisfied)

        Task {
            for try await event in await monitor!.events {
                switch event.state {
                    case .satisfied:
                        guard let lastEvent = await monitor!.record(for: event.identifier)?.lastEvent else { continue }
                        locationEvent = LocationEvent(indentifier: lastEvent.identifier)
                    case .unknown, .unsatisfied, .unmonitored:
                        print("unknown or unsatisfied or unmonitored")
                    @unknown default:
                        print("unknown default")
                }
            }
        }
    }
}

extension LocationManager {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.last.map {
            region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied:
                error = .authorizationDenied
            case .restricted:
                error = .authorizationRestricted
            @unknown default:
                break
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
                case .locationUnknown:
                    self.error = .unknownLocation
                case .denied:
                    self.error = .accessDenied
                case .network:
                    self.error = .network
                default:
                    self.error = .operationFailed
            }
        }
    }
}
