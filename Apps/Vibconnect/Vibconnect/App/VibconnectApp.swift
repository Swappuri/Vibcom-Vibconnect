import SwiftUI

@main
struct VibconnectApp: App {
  @UIApplicationDelegateAdaptor(VibconnectAppDelegate.self) private var appDelegate
  @StateObject private var discoveryService: NearbyDiscoveryService
  @StateObject private var contactsStore: VibconnectContactsStore
  @StateObject private var nearbyExchangeService: NearbyExchangeService

  init() {
    _discoveryService = StateObject(wrappedValue: NearbyDiscoveryService())
    _contactsStore = StateObject(wrappedValue: VibconnectContactsStore())
    _nearbyExchangeService = StateObject(wrappedValue: NearbyExchangeService())
  }

  var body: some Scene {
    WindowGroup {
      VibconnectRootView()
        .environmentObject(discoveryService)
        .environmentObject(contactsStore)
        .environmentObject(nearbyExchangeService)
    }
  }
}
