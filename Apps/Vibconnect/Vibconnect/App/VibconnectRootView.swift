import SwiftUI

struct VibconnectRootView: View {
  @EnvironmentObject private var discoveryService: NearbyDiscoveryService
  @EnvironmentObject private var contactsStore: VibconnectContactsStore
  @EnvironmentObject private var nearbyExchangeService: NearbyExchangeService
  @Environment(\.scenePhase) private var scenePhase

  @State private var isStealthModeEnabled = false
  @State private var showingSaved = false
  @State private var showingNearbyExchange = false
  @State private var isBrailleModeActive = true

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    ZStack {
      background

      DiscoverView(
        isBrailleModeActive: $isBrailleModeActive,
        onAddToContacts: { person in
          contactsStore.add(person)
          discoveryService.markDecision(.accepted, for: person)
        },
        onPass: { person in
          discoveryService.markDecision(.passed, for: person)
        }
      )
      .blur(radius: isStealthModeEnabled ? 50 : 0)
      .opacity(isStealthModeEnabled ? 0 : 1)

      if isStealthModeEnabled {
        Color.black.ignoresSafeArea()
      }

      if showingSaved {
        ModalBackdrop {
          SavedContactsView(onClose: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
              showingSaved = false
            }
          })
          .environmentObject(contactsStore)
        }
        .zIndex(20)
      }

      if showingNearbyExchange {
        ModalBackdrop {
          NearbyExchangeSheet(
            isBrailleModeActive: isBrailleModeActive,
            onSave: { person in
              contactsStore.add(person)
              discoveryService.markDecision(.accepted, for: person)
              withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                showingNearbyExchange = false
              }
            },
            onClose: {
              nearbyExchangeService.stopSearching()
              withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                showingNearbyExchange = false
              }
            }
          )
          .environmentObject(nearbyExchangeService)
        }
        .zIndex(21)
      }

      ZStack {
        StealthModeGestureCatcher {
          isStealthModeEnabled.toggle()
          let phrase = isStealthModeEnabled ? "Stealth mode on" : "Stealth mode off"
          BraillePlaybackEngine.shared.readMessage(phrase, brailleEnabled: isBrailleModeActive)
        }
        TwoFingerOpenSavedCatcher {
          let willOpenSaved = showingSaved == false
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingNearbyExchange = false
            showingSaved = willOpenSaved
          }
          if willOpenSaved {
            nearbyExchangeService.stopSearching()
            BraillePlaybackEngine.shared.readMessage(
              "Saved contacts", brailleEnabled: isBrailleModeActive)
          } else {
            BraillePlaybackEngine.shared.readMessage(
              "Saved contacts closed", brailleEnabled: isBrailleModeActive)
          }
        }
        TwoFingerOpenNearbyExchangeCatcher {
          let willOpenNearbyExchange = showingNearbyExchange == false
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingSaved = false
            showingNearbyExchange = willOpenNearbyExchange
          }
          if willOpenNearbyExchange {
            BraillePlaybackEngine.shared.readMessage(
              "Nearby exchange", brailleEnabled: isBrailleModeActive)
          } else {
            nearbyExchangeService.stopSearching()
            BraillePlaybackEngine.shared.readMessage(
              "Nearby exchange closed", brailleEnabled: isBrailleModeActive)
          }
        }
        BrailleFeedbackModeGestureCatcher {
          guard isBrailleModeActive else { return }
          BraillePlaybackEngine.shared.cycleFeedbackMode()
        }
      }
      .allowsHitTesting(false)
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showingSaved)
    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showingNearbyExchange)
    .task {
      await discoveryService.refresh()
      BraillePlaybackEngine.shared.readMessage(
        "Vibconnect ready", brailleEnabled: isBrailleModeActive)
    }
    .onChange(of: isBrailleModeActive) { _, newValue in
      if newValue == false {
        BraillePlaybackEngine.shared.stopAllOutput()
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active else { return }
      Task { await discoveryService.refresh() }
    }
  }

  private var background: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color.black, Color(red: 0.02, green: 0.08, blue: 0.07), Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      RadialGradient(
        gradient: Gradient(colors: [
          mintGreen.opacity(0.18),
          Color.black.opacity(0.0),
        ]),
        center: .topTrailing,
        startRadius: 20,
        endRadius: 520
      )
      .ignoresSafeArea()

      LinearGradient(
        colors: [
          Color.white.opacity(0.05),
          Color.white.opacity(0.0),
          Color.white.opacity(0.0),
          Color.white.opacity(0.03),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
  }
}
