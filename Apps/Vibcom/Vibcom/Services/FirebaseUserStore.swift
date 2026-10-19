//
//  FirebaseUserStore.swift
//  Vibcom
//

import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Foundation

struct VibcomRemoteUser: Identifiable, Hashable {
  let id: String
  let phoneE164: String
  let displayName: String
  let presenceStatus: PresenceStatus
}

final class FirebaseUserStore {

  static let shared = FirebaseUserStore()

  private lazy var db: Firestore = {
    AppDelegate.configureFirebaseIfNeeded()
    return Firestore.firestore()
  }()

  private init() {
    AppDelegate.configureFirebaseIfNeeded()
  }

  func upsertCurrentUserProfile(phoneE164: String, displayName: String?) async throws {
    guard let user = Auth.auth().currentUser else { return }

    let name =
      (displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
      ? displayName!.trimmingCharacters(in: .whitespacesAndNewlines)
      : phoneE164

    let ref = db.collection("users").document(user.uid)

    try await ref.setData(
      [
        "phoneE164": phoneE164,
        "displayName": name,
        "presenceStatus": "offline",
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      ], merge: true)
  }

  func updateNearbyDiscoveryLocation(
    phoneE164: String,
    location: CLLocation,
    isDiscoverableNearby: Bool
  ) async throws {
    guard let user = Auth.auth().currentUser else { return }

    let ref = db.collection("users").document(user.uid)
    let coordinate = location.coordinate

    try await ref.setData(
      [
        "phoneE164": phoneE164,
        "location": GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
        "latitude": coordinate.latitude,
        "longitude": coordinate.longitude,
        "geoCell": Self.geoCell(for: coordinate),
        "locationUpdatedAt": FieldValue.serverTimestamp(),
        "isDiscoverableNearby": isDiscoverableNearby,
        "updatedAt": FieldValue.serverTimestamp(),
      ], merge: true)
  }

  func setNearbyDiscoveryEnabled(_ isEnabled: Bool) async throws {
    guard let user = Auth.auth().currentUser else { return }

    let ref = db.collection("users").document(user.uid)
    try await ref.setData(
      [
        "isDiscoverableNearby": isEnabled,
        "updatedAt": FieldValue.serverTimestamp(),
      ], merge: true)
  }

  func fetchUsersByPhoneE164(_ phones: [String]) async throws -> [VibcomRemoteUser] {
    let cleaned = Array(Set(phones)).sorted()
    if cleaned.isEmpty { return [] }

    let chunks = cleaned.chunked(into: 30)
    var results: [VibcomRemoteUser] = []

    for chunk in chunks {
      let snap = try await db.collection("users")
        .whereField("phoneE164", in: chunk)
        .getDocuments()

      for doc in snap.documents {
        let data = doc.data()
        let phone = (data["phoneE164"] as? String) ?? ""
        let rawName =
          (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (rawName.isEmpty || rawName == "Vibcom User") ? phone : rawName
        if phone.isEmpty { continue }

        results.append(
          VibcomRemoteUser(
            id: doc.documentID,
            phoneE164: phone,
            displayName: name,
            presenceStatus: PresenceStatus(
              rawValue: (data["presenceStatus"] as? String) ?? "offline") ?? .offline
          )
        )
      }
    }

    if let currentUID = Auth.auth().currentUser?.uid {
      results.removeAll { $0.id == currentUID }
    }

    return Array(Set(results)).sorted {
      $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }
  }

  func addFriend(friendUID: String) async throws {
    guard let uid = Auth.auth().currentUser?.uid else { return }

    let myRef = db.collection("users").document(uid).collection("friends").document(friendUID)
    let theirRef = db.collection("users").document(friendUID).collection("friends").document(uid)

    async let a: Void = myRef.setData(
      [
        "friendUID": friendUID,
        "createdAt": FieldValue.serverTimestamp(),
      ], merge: true)

    async let b: Void = theirRef.setData(
      [
        "friendUID": uid,
        "createdAt": FieldValue.serverTimestamp(),
      ], merge: true)

    _ = try await (a, b)
  }

  func updatePresence(_ status: PresenceStatus) async throws {
    guard let user = Auth.auth().currentUser else { return }

    try await db.collection("users").document(user.uid).setData(
      [
        "presenceStatus": status.rawValue,
        "presenceUpdatedAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      ], merge: true)
  }

  @discardableResult
  func listenToUsersByPhoneE164(
    _ phones: [String],
    onChange: @escaping (Result<[VibcomRemoteUser], Error>) -> Void
  ) -> [ListenerRegistration] {
    let cleaned = Array(Set(phones)).sorted()
    guard cleaned.isEmpty == false else {
      onChange(.success([]))
      return []
    }

    let chunks = cleaned.chunked(into: 30)
    var registrations: [ListenerRegistration] = []
    var latestByID: [String: VibcomRemoteUser] = [:]

    for chunk in chunks {
      let registration = db.collection("users")
        .whereField("phoneE164", in: chunk)
        .addSnapshotListener { snapshot, error in
          if let error {
            onChange(.failure(error))
            return
          }

          for document in snapshot?.documents ?? [] {
            let data = document.data()
            let phone = (data["phoneE164"] as? String) ?? ""
            guard phone.isEmpty == false else { continue }

            latestByID[document.documentID] = VibcomRemoteUser(
              id: document.documentID,
              phoneE164: phone,
              displayName: {
                let rawName =
                  (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                  ?? ""
                return (rawName.isEmpty || rawName == "Vibcom User") ? phone : rawName
              }(),
              presenceStatus: PresenceStatus(
                rawValue: (data["presenceStatus"] as? String) ?? "offline") ?? .offline
            )
          }

          let values = latestByID.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
          }
          onChange(.success(values))
        }

      registrations.append(registration)
    }

    return registrations
  }
}

extension Array {
  fileprivate func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    var result: [[Element]] = []
    result.reserveCapacity((count + size - 1) / size)
    var index = 0
    while index < count {
      let end = Swift.min(index + size, count)
      result.append(Array(self[index..<end]))
      index += size
    }
    return result
  }
}

extension FirebaseUserStore {
  fileprivate static func geoCell(for coordinate: CLLocationCoordinate2D) -> String {
    let gridSize = 40.0
    let latCell = Int((coordinate.latitude + 90.0) * gridSize)
    let lonCell = Int((coordinate.longitude + 180.0) * gridSize)
    return "\(latCell)_\(lonCell)"
  }
}
