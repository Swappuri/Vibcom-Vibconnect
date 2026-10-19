import Contacts
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Foundation

enum DiscoveryState: Equatable {
  case idle
  case loading
  case ready
  case empty
  case needsLocationPermission
  case failed(String)
}

@MainActor
final class NearbyDiscoveryService: NSObject, ObservableObject {
  @Published private(set) var candidates: [NearbyPerson] = []
  @Published private(set) var state: DiscoveryState = .idle

  private let skippedDefaultsKey = "vibconnect.skipped.phoneNumbers"
  private let locationGridSize = 40.0
  private let maxDiscoveryDistanceMeters: CLLocationDistance = 25_000
  private let maxLocationAge: TimeInterval = 60 * 60

  private var db: Firestore { Firestore.firestore() }
  private let locationManager = CLLocationManager()
  private var skippedPhoneNumbers: Set<String>

  private var locationContinuation: CheckedContinuation<CLLocation, Error>?
  private var permissionContinuation: CheckedContinuation<Bool, Never>?

  override init() {
    if let stored = UserDefaults.standard.array(forKey: skippedDefaultsKey) as? [String] {
      skippedPhoneNumbers = Set(stored)
    } else {
      skippedPhoneNumbers = []
    }
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func refresh() async {
    state = .loading

    do {
      guard let location = try await fetchCurrentLocation() else {
        state = .needsLocationPermission
        candidates = []
        return
      }

      let people = try await fetchNearbyUsers(around: location)
      let filtered = await filterOutExistingContacts(from: people)
      candidates = filtered
      state = filtered.isEmpty ? .empty : .ready
    } catch {
      candidates = []
      state = mappedFailureState(for: error)
    }
  }

  func markDecision(_ decision: NearbyDecision, for person: NearbyPerson) {
    switch decision {
    case .passed:
      skippedPhoneNumbers.insert(Self.normalizedUSNumber(person.phoneE164))
      UserDefaults.standard.set(Array(skippedPhoneNumbers).sorted(), forKey: skippedDefaultsKey)
    case .accepted:
      break
    }
    candidates.removeAll { $0.id == person.id }
  }

  private func fetchCurrentLocation() async throws -> CLLocation? {
    let status = locationManager.authorizationStatus
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      return try await requestOneShotLocation()
    case .notDetermined:
      let granted = await requestWhenInUsePermission()
      guard granted else { return nil }
      return try await requestOneShotLocation()
    default:
      return nil
    }
  }

  private func requestWhenInUsePermission() async -> Bool {
    let status = locationManager.authorizationStatus
    if status == .authorizedAlways || status == .authorizedWhenInUse { return true }
    if status == .denied || status == .restricted { return false }

    return await withCheckedContinuation { continuation in
      // Avoid leaking an older continuation if this is called twice.
      if let existing = permissionContinuation {
        existing.resume(returning: false)
        permissionContinuation = nil
      }
      permissionContinuation = continuation
      locationManager.requestWhenInUseAuthorization()

      // Failsafe: if iOS never calls back, don't leave task suspended forever.
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
        guard let self else { return }
        guard let pending = self.permissionContinuation else { return }
        self.permissionContinuation = nil
        let current = self.locationManager.authorizationStatus
        pending.resume(returning: current == .authorizedAlways || current == .authorizedWhenInUse)
      }
    }
  }

  private func requestOneShotLocation() async throws -> CLLocation {
    if let cached = locationManager.location,
      abs(cached.timestamp.timeIntervalSinceNow) < maxLocationAge
    {
      return cached
    }

    return try await withCheckedThrowingContinuation { continuation in
      if let existing = locationContinuation {
        existing.resume(throwing: NSError(domain: "Vibconnect.Location", code: 2))
        locationContinuation = nil
      }
      locationContinuation = continuation
      locationManager.requestLocation()

      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
        guard let self else { return }
        guard let pending = self.locationContinuation else { return }
        self.locationContinuation = nil
        pending.resume(throwing: NSError(domain: "Vibconnect.Location", code: 3))
      }
    }
  }

  private func mappedFailureState(for error: Error) -> DiscoveryState {
    if let clError = error as? CLError {
      switch clError.code {
      case .denied:
        return .needsLocationPermission
      case .locationUnknown:
        return .failed("Couldn't determine your current location yet")
      default:
        break
      }
    }

    let nsError = error as NSError
    if nsError.domain == "Vibconnect.Location", nsError.code == 3 {
      return .failed("Location request timed out")
    }

    return .failed(error.localizedDescription)
  }

  private func fetchNearbyUsers(
    around location: CLLocation
  ) async throws -> [NearbyPerson] {
    let centerCell = Self.locationCell(for: location.coordinate, gridSize: locationGridSize)
    let cells = Self.adjacentCells(around: centerCell)
    let earliestAllowedDate = Timestamp(date: Date().addingTimeInterval(-maxLocationAge))

    // First try true nearby lookup if Vibcom profiles are publishing geoCell.
    let nearbySnap = try await db.collection("users")
      .whereField("isDiscoverableNearby", isEqualTo: true)
      .whereField("geoCell", in: cells)
      .whereField("locationUpdatedAt", isGreaterThanOrEqualTo: earliestAllowedDate)
      .limit(to: 80)
      .getDocuments()

    var users = nearbySnap.documents.compactMap { Self.person(from: $0, relativeTo: location) }
    if users.isEmpty == false {
      return Self.deduplicatedAndSorted(users, maxDistanceMeters: maxDiscoveryDistanceMeters)
    }

    // Fallback for existing user docs that may have coordinates but not geoCell yet.
    let fallbackSnap = try await db.collection("users")
      .whereField("isDiscoverableNearby", isEqualTo: true)
      .whereField("locationUpdatedAt", isGreaterThanOrEqualTo: earliestAllowedDate)
      .limit(to: 80)
      .getDocuments()
    users = fallbackSnap.documents.compactMap { Self.person(from: $0, relativeTo: location) }
    return Self.deduplicatedAndSorted(users, maxDistanceMeters: maxDiscoveryDistanceMeters)
  }

  private static func person(from doc: QueryDocumentSnapshot, relativeTo location: CLLocation)
    -> NearbyPerson?
  {
    let data = doc.data()
    guard let phoneE164 = data["phoneE164"] as? String, phoneE164.isEmpty == false else {
      return nil
    }
    let coordinate = coordinate(from: data)
    let distanceMeters = coordinate.map { candidateCoordinate in
      CLLocation(latitude: candidateCoordinate.latitude, longitude: candidateCoordinate.longitude)
        .distance(from: location)
    }

    return NearbyPerson(
      id: doc.documentID,
      phoneE164: phoneE164,
      latitude: coordinate?.latitude,
      longitude: coordinate?.longitude,
      distanceMeters: distanceMeters
    )
  }

  private func filterOutExistingContacts(from people: [NearbyPerson]) async -> [NearbyPerson] {
    let existing = await fetchExistingContactPhoneSet()
    let selfNumbers = await fetchSelfPhoneSet()
    let currentUserID = Auth.auth().currentUser?.uid ?? SharedIdentityStore.currentUID
    return people.filter { person in
      if person.id == currentUserID { return false }
      let normalized = Self.normalizedUSNumber(person.phoneE164)
      if selfNumbers.contains(normalized) { return false }
      if existing.contains(normalized) { return false }
      if skippedPhoneNumbers.contains(normalized) { return false }
      return true
    }
  }

  private func fetchExistingContactPhoneSet() async -> Set<String> {
    let store = CNContactStore()
    let status = CNContactStore.authorizationStatus(for: .contacts)

    if status == .notDetermined {
      _ = try? await store.requestAccess(for: .contacts)
    }

    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return [] }

    let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
    var numbers: Set<String> = []
    let request = CNContactFetchRequest(keysToFetch: keys)

    try? store.enumerateContacts(with: request) { contact, _ in
      for value in contact.phoneNumbers {
        let raw = value.value.stringValue
        numbers.insert(Self.normalizedUSNumber(raw))
      }
    }
    return numbers
  }

  private func fetchSelfPhoneSet() async -> Set<String> {
    var numbers: Set<String> = []

    if let authPhone = Auth.auth().currentUser?.phoneNumber, authPhone.isEmpty == false {
      numbers.insert(Self.normalizedUSNumber(authPhone))
    }

    if let sharedPhone = SharedIdentityStore.currentPhoneE164, sharedPhone.isEmpty == false {
      numbers.insert(Self.normalizedUSNumber(sharedPhone))
    }

    return numbers
  }

  private static func normalizedUSNumber(_ raw: String) -> String {
    let digits = raw.filter(\.isNumber)
    if digits.count == 11, digits.first == "1" {
      return "+" + digits
    }
    if digits.count == 10 {
      return "+1" + digits
    }
    return "+" + digits
  }

  private static func coordinate(from data: [String: Any]) -> CLLocationCoordinate2D? {
    if let geoPoint = data["location"] as? GeoPoint {
      return CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
    }

    if let latitude = data["latitude"] as? Double, let longitude = data["longitude"] as? Double {
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    if let latitude = data["lat"] as? Double, let longitude = data["lng"] as? Double {
      return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    return nil
  }

  private static func deduplicatedAndSorted(
    _ users: [NearbyPerson],
    maxDistanceMeters: CLLocationDistance
  ) -> [NearbyPerson] {
    var uniqueByPhone: [String: NearbyPerson] = [:]

    for person in users {
      guard let distance = person.distanceMeters, distance <= maxDistanceMeters else { continue }
      let normalizedPhone = normalizedUSNumber(person.phoneE164)
      if let existing = uniqueByPhone[normalizedPhone] {
        let existingDistance = existing.distanceMeters ?? .greatestFiniteMagnitude
        if distance < existingDistance {
          uniqueByPhone[normalizedPhone] = person
        }
      } else {
        uniqueByPhone[normalizedPhone] = person
      }
    }

    return uniqueByPhone.values.sorted {
      let leftDistance = $0.distanceMeters ?? .greatestFiniteMagnitude
      let rightDistance = $1.distanceMeters ?? .greatestFiniteMagnitude
      if leftDistance == rightDistance {
        return $0.phoneE164 < $1.phoneE164
      }
      return leftDistance < rightDistance
    }
  }

  private static func locationCell(for coordinate: CLLocationCoordinate2D, gridSize: Double)
    -> String
  {
    let latCell = Int((coordinate.latitude + 90.0) * gridSize)
    let lonCell = Int((coordinate.longitude + 180.0) * gridSize)
    return "\(latCell)_\(lonCell)"
  }

  private static func adjacentCells(around center: String) -> [String] {
    let parts = center.split(separator: "_")
    guard parts.count == 2, let lat = Int(parts[0]), let lon = Int(parts[1]) else {
      return [center]
    }

    var cells: [String] = []
    for dLat in -1...1 {
      for dLon in -1...1 {
        cells.append("\(lat + dLat)_\(lon + dLon)")
      }
    }
    return cells
  }

}

extension NearbyDiscoveryService: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      guard let permissionContinuation else { return }
      self.permissionContinuation = nil
      let status = manager.authorizationStatus
      permissionContinuation.resume(
        returning: status == .authorizedAlways || status == .authorizedWhenInUse)
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    Task { @MainActor in
      guard let continuation = locationContinuation else { return }
      locationContinuation = nil
      if let location = locations.last {
        continuation.resume(returning: location)
      } else {
        continuation.resume(throwing: NSError(domain: "Vibconnect.Location", code: 1))
      }
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      guard let continuation = locationContinuation else { return }
      locationContinuation = nil
      continuation.resume(throwing: error)
    }
  }
}
