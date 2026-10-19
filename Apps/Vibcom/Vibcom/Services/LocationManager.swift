//
//  LocationManager.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/29/25.
//

import Combine
import CoreLocation
import Foundation

final class LocationManager: NSObject, ObservableObject {

  static let shared = LocationManager()

  private let manager = CLLocationManager()
  private var locationContinuation: CheckedContinuation<CLLocation?, Error>?

  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
  @Published var currentLocation: CLLocation?

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func requestWhenInUse() {
    manager.requestWhenInUseAuthorization()
  }

  func requestCurrentLocationIfAuthorized() async throws -> CLLocation? {
    let status = manager.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways else {
      return nil
    }

    if let existingContinuation = locationContinuation {
      locationContinuation = nil
      existingContinuation.resume(throwing: NSError(domain: "Vibcom.Location", code: 2))
    }

    return try await withCheckedThrowingContinuation { continuation in
      locationContinuation = continuation
      manager.requestLocation()
    }
  }
}

extension LocationManager: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus

    if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
      guard let continuation = locationContinuation else { return }
      locationContinuation = nil
      continuation.resume(returning: nil)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let location = locations.last
    currentLocation = location

    guard let continuation = locationContinuation else { return }
    locationContinuation = nil

    if let location {
      continuation.resume(returning: location)
    } else {
      continuation.resume(throwing: NSError(domain: "Vibcom.Location", code: 1))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let continuation = locationContinuation else { return }
    locationContinuation = nil
    continuation.resume(throwing: error)
  }
}
