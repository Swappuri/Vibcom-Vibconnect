import SwiftUI

struct DiscoverView: View {
  @EnvironmentObject private var discoveryService: NearbyDiscoveryService

  @Binding var isBrailleModeActive: Bool
  let onAddToContacts: (NearbyPerson) -> Void
  let onPass: (NearbyPerson) -> Void

  @State private var dragOffset: CGSize = .zero

  private var topCandidate: NearbyPerson? { discoveryService.candidates.first }
  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    VStack(spacing: 14) {
      header

      contentArea
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      gestureHelpBar
    }
    .frame(maxWidth: 520)
    .padding(.horizontal, 18)
    .padding(.top, 12)
    .padding(.bottom, 12)
    .animation(.spring(response: 0.22, dampingFraction: 0.86), value: discoveryService.candidates)
    .onAppear {
      announceCurrentNumber()
    }
    .onChange(of: topCandidate?.id) { _, _ in
      announceCurrentNumber()
    }
    .onChange(of: discoveryService.state) { _, newState in
      guard isBrailleModeActive else { return }
      switch newState {
      case .needsLocationPermission:
        BraillePlaybackEngine.shared.readMessage(
          "Location permission needed", brailleEnabled: isBrailleModeActive)
      case .failed:
        BraillePlaybackEngine.shared.readMessage(
          "Discovery error", brailleEnabled: isBrailleModeActive)
      case .empty:
        BraillePlaybackEngine.shared.readMessage(
          "No nearby users", brailleEnabled: isBrailleModeActive)
      default:
        break
      }
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Braille Mode")
          .font(.footnote.weight(.semibold))
          .foregroundColor(.white.opacity(0.92))
        Text(isBrailleModeActive ? "Gesture input" : "Visual only")
          .font(.caption.weight(.medium))
          .foregroundColor(.white.opacity(0.60))
      }

      SwipeToggleControl(
        isOn: $isBrailleModeActive,
        activeColor: mintGreen,
        width: nil,
        height: 32,
        knobPadding: 3
      )
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.09), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(mintGreen.opacity(0.12), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
  }

  @ViewBuilder
  private var contentArea: some View {
    switch discoveryService.state {
    case .loading:
      stateCard(title: "Finding nearby users", icon: "dot.radiowaves.left.and.right")
    case .needsLocationPermission:
      stateCard(title: "Enable location access in Settings", icon: "location.slash.fill")
    case .failed(let message):
      stateCard(title: message, icon: "exclamationmark.triangle.fill")
    default:
      ZStack {
        if discoveryService.candidates.count > 1 {
          numberCardBack
            .offset(y: 8)
          numberCardBack
            .offset(y: 4)
        }

        if let person = topCandidate {
          numberCard(for: person)
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 32)))
            .gesture(cardGesture(for: person))
        } else {
          emptyCard
        }
      }
    }
  }

  private var numberCardBack: some View {
    RoundedRectangle(cornerRadius: 24)
      .fill(
        LinearGradient(
          colors: [Color.white.opacity(0.05), Color.white.opacity(0.025)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24)
          .stroke(Color.white.opacity(0.07), lineWidth: 1.0)
      )
      .frame(height: 260)
  }

  private func numberCard(for person: NearbyPerson) -> some View {
    Text(person.phoneNumber)
      .font(.system(size: 38, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.64)
      .frame(maxWidth: .infinity)
      .frame(height: 260)
      .padding(.horizontal, 20)
      .background(glassBackground(cornerRadius: 24))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(person.phoneNumber)
      .accessibilityHint("Swipe right to add. Swipe left to skip.")
  }

  private var emptyCard: some View {
    VStack(spacing: 10) {
      Image(systemName: "person.2.slash.fill")
        .font(.system(size: 28, weight: .semibold))
        .foregroundColor(mintGreen.opacity(0.86))
      Text("No nearby users right now")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 260)
    .background(glassBackground(cornerRadius: 24))
  }

  private func cardGesture(for person: NearbyPerson) -> some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        dragOffset = value.translation
      }
      .onEnded { value in
        let threshold: CGFloat = 90
        if value.translation.width > threshold {
          withAnimation(.spring(response: 0.18, dampingFraction: 0.88)) {
            dragOffset = CGSize(width: 640, height: value.translation.height)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            dragOffset = .zero
            HapticsManager.shared.play(.commitSuccess)
            BraillePlaybackEngine.shared.readMessage(
              "Saved \(person.phoneNumber)", brailleEnabled: isBrailleModeActive)
            onAddToContacts(person)
          }
        } else if value.translation.width < -threshold {
          withAnimation(.spring(response: 0.18, dampingFraction: 0.88)) {
            dragOffset = CGSize(width: -640, height: value.translation.height)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            dragOffset = .zero
            HapticsManager.shared.play(.dotOff)
            BraillePlaybackEngine.shared.readMessage(
              "Skipped \(person.phoneNumber)", brailleEnabled: isBrailleModeActive)
            onPass(person)
          }
        } else {
          withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            dragOffset = .zero
          }
        }
      }
  }

  private func stateCard(title: String, icon: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 26, weight: .semibold))
        .foregroundColor(mintGreen.opacity(0.92))
      Text(title)
        .font(.system(size: 19, weight: .semibold, design: .rounded))
        .foregroundColor(.white.opacity(0.92))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity)
    .frame(height: 260)
    .background(glassBackground(cornerRadius: 24))
  }

  private func glassBackground(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(
        LinearGradient(
          colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(Color.white.opacity(0.16), lineWidth: 1.0)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(mintGreen.opacity(0.12), lineWidth: 1.0)
      )
      .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 8)
  }

  private var gestureHelpBar: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Accessibility shortcuts")
        .font(.caption.weight(.bold))
        .foregroundColor(mintGreen.opacity(0.92))
      Text(
        "Left: skip • Right: add • 2-finger up: saved • 2-finger down: nearby • 3-finger tap: output • 4-finger double tap: stealth"
      )
      .font(.caption.weight(.semibold))
      .foregroundColor(.white.opacity(0.78))
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 11)
    .background(
      LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.16), lineWidth: 1.0)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(mintGreen.opacity(0.10), lineWidth: 1.0)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private func announceCurrentNumber() {
    guard let person = topCandidate else { return }
    BraillePlaybackEngine.shared.readMessage(
      person.phoneNumber, brailleEnabled: isBrailleModeActive)
  }
}

struct NearbyExchangeSheet: View {
  @EnvironmentObject private var nearbyExchangeService: NearbyExchangeService

  let isBrailleModeActive: Bool
  let onSave: (NearbyPerson) -> Void
  let onClose: () -> Void

  @State private var dragOffset: CGSize = .zero

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    VStack(spacing: 18) {
      modalHeader(title: "Nearby Exchange", closeLabel: "Done", onClose: onClose)

      statusCard
    }
    .padding(22)
    .frame(maxWidth: 560)
    .background(modalCardBackground(cornerRadius: 28))
    .onAppear {
      nearbyExchangeService.startSearching()
      BraillePlaybackEngine.shared.readMessage(
        "Searching nearby devices", brailleEnabled: isBrailleModeActive)
    }
  }

  @ViewBuilder
  private var statusCard: some View {
    switch nearbyExchangeService.state {
    case .idle, .searching:
      exchangeCard(
        title: "Looking for nearby devices",
        subtitle: "Keep both devices unlocked and in the app."
      )
    case .found:
      if let peer = nearbyExchangeService.nearbyPeer {
        exchangeCard(
          title: "Nearby number found",
          subtitle: peer.person.phoneNumber
        )
        .offset(dragOffset)
        .rotationEffect(.degrees(Double(dragOffset.width / 32)))
        .gesture(foundCardGesture(for: peer.person))
        .accessibilityHint("Swipe right to save. Swipe left to skip and keep searching.")
      }
    case .failed(let message):
      exchangeCard(
        title: "Nearby exchange unavailable",
        subtitle: message
      )
    }
  }

  private func foundCardGesture(for person: NearbyPerson) -> some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        dragOffset = value.translation
      }
      .onEnded { value in
        let threshold: CGFloat = 90
        if value.translation.width > threshold {
          withAnimation(.spring(response: 0.18, dampingFraction: 0.88)) {
            dragOffset = CGSize(width: 640, height: value.translation.height)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            dragOffset = .zero
            HapticsManager.shared.play(.commitSuccess)
            BraillePlaybackEngine.shared.readMessage(
              "Saved \(person.phoneNumber)", brailleEnabled: isBrailleModeActive)
            onSave(person)
            nearbyExchangeService.stopSearching()
            onClose()
          }
        } else if value.translation.width < -threshold {
          withAnimation(.spring(response: 0.18, dampingFraction: 0.88)) {
            dragOffset = CGSize(width: -640, height: value.translation.height)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            dragOffset = .zero
            HapticsManager.shared.play(.dotOff)
            BraillePlaybackEngine.shared.readMessage(
              "Searching for another nearby device", brailleEnabled: isBrailleModeActive)
            nearbyExchangeService.startSearching()
          }
        } else {
          withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            dragOffset = .zero
          }
        }
      }
  }

  private func exchangeCard(title: String, subtitle: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "iphone.gen3.radiowaves.left.and.right")
        .font(.system(size: 28, weight: .semibold))
        .foregroundColor(mintGreen.opacity(0.94))
      Text(title)
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
      Text(subtitle)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.72))
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity)
    .frame(height: 260)
    .background(glassBackground(cornerRadius: 24))
  }

  private func glassBackground(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(
        LinearGradient(
          colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(Color.white.opacity(0.16), lineWidth: 1.0)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(mintGreen.opacity(0.12), lineWidth: 1.0)
      )
      .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 8)
  }

}

struct SavedContactsView: View {
  @EnvironmentObject private var contactsStore: VibconnectContactsStore

  let onClose: () -> Void

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    VStack(spacing: 18) {
      modalHeader(title: "Saved Contacts", closeLabel: "Done", onClose: onClose)

      if contactsStore.saved.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "person.crop.circle.badge.xmark")
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(mintGreen.opacity(0.94))
          Text("No contacts saved yet.")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(modalCardBackground(cornerRadius: 24))
      } else {
        ScrollView {
          VStack(spacing: 12) {
            ForEach(contactsStore.saved) { person in
              HStack {
                Text(person.phoneNumber)
                  .font(.system(size: 20, weight: .semibold, design: .rounded))
                  .foregroundColor(.white)
                Spacer(minLength: 0)
              }
              .padding(.horizontal, 18)
              .padding(.vertical, 18)
              .frame(maxWidth: .infinity)
              .background(modalCardBackground(cornerRadius: 20))
            }
          }
        }
        .scrollIndicators(.hidden)
      }
    }
    .padding(22)
    .frame(maxWidth: 560)
    .background(modalCardBackground(cornerRadius: 28))
  }
}

struct ModalBackdrop<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color.black.opacity(0.88),
          Color(red: 0.01, green: 0.05, blue: 0.04).opacity(0.94),
          Color.black.opacity(0.90),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(24)
    }
    .transition(
      .asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(
          with: .move(edge: .bottom)),
        removal: .opacity.combined(with: .scale(scale: 0.96))
      )
    )
  }
}

private func modalCardBackground(cornerRadius: CGFloat) -> some View {
  RoundedRectangle(cornerRadius: cornerRadius)
    .fill(
      LinearGradient(
        colors: [
          Color(red: 0.08, green: 0.12, blue: 0.11).opacity(0.98),
          Color(red: 0.04, green: 0.06, blue: 0.06).opacity(0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color("MintGreen").opacity(0.16), lineWidth: 1.0)
    )
    .shadow(color: .black.opacity(0.44), radius: 24, x: 0, y: 14)
}

private func modalHeader(title: String, closeLabel: String, onClose: @escaping () -> Void)
  -> some View
{
  HStack(alignment: .center, spacing: 12) {
    Text(title)
      .font(.system(size: 24, weight: .bold, design: .rounded))
      .foregroundColor(.white)

    Spacer(minLength: 0)

    Button(closeLabel, action: onClose)
      .font(.system(size: 16, weight: .semibold, design: .rounded))
      .foregroundColor(Color("MintGreen"))
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(modalCardBackground(cornerRadius: 16))
      .buttonStyle(.plain)
  }
}
