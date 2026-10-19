import FirebaseAuth
import Foundation
import MultipeerConnectivity
import UIKit

struct NearbyExchangePeer: Identifiable, Equatable {
  let id: String
  let peerID: MCPeerID
  let person: NearbyPerson
}

@MainActor
final class NearbyExchangeService: NSObject, ObservableObject {
  enum State: Equatable {
    case idle
    case searching
    case found
    case failed(String)
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var nearbyPeer: NearbyExchangePeer?

  private let serviceType = "vibconnect-x"
  private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
  private lazy var session: MCSession = {
    let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
    session.delegate = self
    return session
  }()
  private lazy var advertiser: MCNearbyServiceAdvertiser = {
    let advertiser = MCNearbyServiceAdvertiser(
      peer: myPeerID,
      discoveryInfo: nil,
      serviceType: serviceType
    )
    advertiser.delegate = self
    return advertiser
  }()
  private lazy var browser: MCNearbyServiceBrowser = {
    let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
    browser.delegate = self
    return browser
  }()

  private var discoveredPeerIDs: Set<MCPeerID> = []
  private var connectedPeerIDs: Set<MCPeerID> = []

  func startSearching() {
    guard let payload = Self.localProfilePayload(),
      payload.phoneE164.isEmpty == false
    else {
      nearbyPeer = nil
      state = .failed("Open Vibcom on this device first so your number is available")
      return
    }

    nearbyPeer = nil
    state = .searching
    discoveredPeerIDs.removeAll()
    connectedPeerIDs.removeAll()
    session.disconnect()
    advertiser.startAdvertisingPeer()
    browser.startBrowsingForPeers()
  }

  func stopSearching() {
    advertiser.stopAdvertisingPeer()
    browser.stopBrowsingForPeers()
    session.disconnect()
    discoveredPeerIDs.removeAll()
    connectedPeerIDs.removeAll()
    nearbyPeer = nil
    state = .idle
  }

  func saveDiscoveredPeer() -> NearbyPerson? {
    let person = nearbyPeer?.person
    stopSearching()
    return person
  }

  private func sendProfileIfNeeded(to peerID: MCPeerID) {
    guard connectedPeerIDs.contains(peerID) == false else { return }
    connectedPeerIDs.insert(peerID)

    guard let localProfile = Self.localProfilePayload(),
      localProfile.phoneE164.isEmpty == false,
      let payload = try? JSONEncoder().encode(localProfile)
    else {
      state = .failed("Couldn't prepare nearby profile")
      return
    }

    do {
      try session.send(payload, toPeers: [peerID], with: .reliable)
    } catch {
      state = .failed("Couldn't exchange nearby profile")
    }
  }

  private static func localProfilePayload() -> NearbyExchangePayload? {
    let user = Auth.auth().currentUser
    let sharedUID = SharedIdentityStore.currentUID
    let sharedPhone = SharedIdentityStore.currentPhoneE164
    let phone = user?.phoneNumber ?? sharedPhone ?? ""
    guard phone.isEmpty == false else { return nil }
    return NearbyExchangePayload(
      uid: user?.uid ?? sharedUID ?? UUID().uuidString,
      phoneE164: phone,
      displayName: UIDevice.current.name
    )
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
}

private struct NearbyExchangePayload: Codable {
  let uid: String
  let phoneE164: String
  let displayName: String
}

extension NearbyExchangeService: MCSessionDelegate {
  nonisolated func session(
    _ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState
  ) {
    Task { @MainActor in
      switch state {
      case .connected:
        sendProfileIfNeeded(to: peerID)
      case .notConnected:
        connectedPeerIDs.remove(peerID)
      case .connecting:
        break
      @unknown default:
        break
      }
    }
  }

  nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    Task { @MainActor in
      guard let payload = try? JSONDecoder().decode(NearbyExchangePayload.self, from: data),
        payload.phoneE164.isEmpty == false
      else {
        state = .failed("Nearby device sent an invalid number")
        return
      }

      let myUID = Auth.auth().currentUser?.uid ?? SharedIdentityStore.currentUID
      let myPhone = Self.normalizedUSNumber(
        Auth.auth().currentUser?.phoneNumber ?? SharedIdentityStore.currentPhoneE164 ?? ""
      )
      let incomingPhone = Self.normalizedUSNumber(payload.phoneE164)
      if payload.uid == myUID || (myPhone.isEmpty == false && incomingPhone == myPhone) {
        return
      }

      nearbyPeer = NearbyExchangePeer(
        id: payload.uid,
        peerID: peerID,
        person: NearbyPerson(
          id: payload.uid,
          phoneE164: payload.phoneE164,
          latitude: nil,
          longitude: nil,
          distanceMeters: nil
        )
      )
      state = .found
    }
  }

  nonisolated func session(
    _ session: MCSession,
    didReceive stream: InputStream,
    withName streamName: String,
    fromPeer peerID: MCPeerID
  ) {}

  nonisolated func session(
    _ session: MCSession,
    didStartReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    with progress: Progress
  ) {}

  nonisolated func session(
    _ session: MCSession,
    didFinishReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID,
    at localURL: URL?,
    withError error: Error?
  ) {}

  nonisolated func session(
    _ session: MCSession,
    didReceiveCertificate certificate: [Any]?,
    fromPeer peerID: MCPeerID,
    certificateHandler: @escaping (Bool) -> Void
  ) {
    certificateHandler(true)
  }
}

extension NearbyExchangeService: MCNearbyServiceAdvertiserDelegate {
  nonisolated func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didReceiveInvitationFromPeer peerID: MCPeerID,
    withContext context: Data?,
    invitationHandler: @escaping (Bool, MCSession?) -> Void
  ) {
    Task { @MainActor in
      invitationHandler(true, session)
    }
  }

  nonisolated func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didNotStartAdvertisingPeer error: Error
  ) {
    Task { @MainActor in
      state = .failed("Couldn't advertise nearby exchange")
    }
  }
}

extension NearbyExchangeService: MCNearbyServiceBrowserDelegate {
  nonisolated func browser(
    _ browser: MCNearbyServiceBrowser,
    foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String: String]?
  ) {
    Task { @MainActor in
      guard peerID != myPeerID else { return }
      guard discoveredPeerIDs.contains(peerID) == false else { return }
      discoveredPeerIDs.insert(peerID)
      browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
  }

  nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    Task { @MainActor in
      discoveredPeerIDs.remove(peerID)
      connectedPeerIDs.remove(peerID)
    }
  }

  nonisolated func browser(
    _ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error
  ) {
    Task { @MainActor in
      state = .failed("Couldn't search nearby devices")
    }
  }
}
