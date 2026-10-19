//
//  OnboardingFlowView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/29/25.
//

import SwiftData
import SwiftUI
import UIKit

struct OnboardingFlowView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @EnvironmentObject private var appState: AppState

  let currentUser: VibcomUser

  @ObservedObject private var locationManager = LocationManager.shared
  @State private var showLocationSettingsAlert = false
  @State private var isFinishing = false

  private var mintGreen: Color { Color("MintGreen") }

  private var isCompactLayout: Bool {
    horizontalSizeClass == .compact
  }

  private var contentInset: CGFloat {
    isCompactLayout ? 16 : 22
  }

  private var isAuthorized: Bool {
    let status = locationManager.authorizationStatus
    return status == .authorizedWhenInUse || status == .authorizedAlways
  }

  var body: some View {
    ZStack {
      background

      VStack(spacing: 0) {
        header
          .padding(.horizontal, contentInset)
          .padding(.top, isCompactLayout ? 12 : 18)
          .padding(.bottom, isCompactLayout ? 10 : 14)

        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 14) {
            mainCard
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, contentInset)
          .padding(.top, 2)
          .padding(.bottom, isCompactLayout ? 12 : 20)
        }

        actionBar
          .padding(.horizontal, contentInset)
      }
    }
    .onAppear {
      if isAuthorized {
        finishOnboarding()
      }
    }
    .onChange(of: locationManager.authorizationStatus) { _, _ in
      if isAuthorized {
        finishOnboarding()
      }
    }
    .alert("Enable Location in Settings", isPresented: $showLocationSettingsAlert) {
      Button("Open Settings") {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Allow location so nearby discovery can work in Vibconnect.")
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

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      Image("Vibcom Main Logo")
        .resizable()
        .scaledToFit()
        .frame(width: isCompactLayout ? 54 : 64, height: isCompactLayout ? 54 : 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))

      Spacer(minLength: 0)

      brailleModePill
    }
  }

  private var brailleModePill: some View {
    HStack(spacing: 10) {
      VStack(alignment: .trailing, spacing: 2) {
        Text("Braille Mode")
          .font(.footnote.weight(.semibold))
          .foregroundColor(.white.opacity(0.92))

        Text(appState.isBrailleModeActive ? "Gesture input" : "Keyboard input")
          .font(.caption.weight(.medium))
          .foregroundColor(.white.opacity(0.60))
      }

      SwipeToggleControl(
        isOn: $appState.isBrailleModeActive,
        activeColor: mintGreen
      )
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.white.opacity(0.08))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private var mainCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      stepIndicator

      VStack(alignment: .leading, spacing: 4) {
        Text("Enable location")
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundColor(.white)

        Text("Allow Vibcom to make you discoverable nearby in Vibconnect.")
          .font(.subheadline.weight(.medium))
          .foregroundColor(.white.opacity(0.74))
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Location access")
          .font(.headline)
          .foregroundColor(.white)

        statusRow
      }
    }
    .padding(isCompactLayout ? 16 : 20)
    .background(glassBackground(cornerRadius: 26))
  }

  private var stepIndicator: some View {
    HStack(spacing: 10) {
      StepPip(isOn: true, mint: mintGreen)
      StepPip(isOn: true, mint: mintGreen)
      StepPip(isOn: true, mint: mintGreen)
      Spacer(minLength: 0)
    }
    .accessibilityHidden(true)
  }

  private var statusRow: some View {
    HStack(spacing: 12) {
      Image(systemName: statusIconName)
        .foregroundColor(mintGreen)
        .frame(width: 24, alignment: .center)

      Text(statusText)
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(Color.white.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.18), lineWidth: 1.0)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }

  private var statusIconName: String {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      return "location.fill"
    case .denied, .restricted:
      return "gearshape.fill"
    case .notDetermined:
      return "location.circle.fill"
    @unknown default:
      return "location.circle.fill"
    }
  }

  private var statusText: String {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      return "Location enabled"
    case .denied, .restricted:
      return "Open Settings to allow"
    case .notDetermined:
      return "Permission required"
    @unknown default:
      return "Permission required"
    }
  }

  private var actionBar: some View {
    VStack(spacing: 0) {
      Divider().opacity(0.08)

      Button {
        primaryAction()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: primaryIconName)
          Text(primaryActionTitle)
            .font(.headline)

          Spacer()
        }
        .foregroundColor(.black)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(mintGreen)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 10)
        .padding(.bottom, 14)
      }
      .disabled(isFinishing)
    }
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.84), Color.black.opacity(0.98)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea(edges: .bottom)
    )
  }

  private var primaryActionTitle: String {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      return "Continue"
    case .denied, .restricted:
      return "Open Settings"
    case .notDetermined:
      return "Enable Location"
    @unknown default:
      return "Enable Location"
    }
  }

  private var primaryIconName: String {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      return "arrow.right.circle.fill"
    case .denied, .restricted:
      return "gearshape.fill"
    case .notDetermined:
      return "location.fill"
    @unknown default:
      return "location.fill"
    }
  }

  private func primaryAction() {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      finishOnboarding()
    case .denied, .restricted:
      showLocationSettingsAlert = true
    case .notDetermined:
      LocationManager.shared.requestWhenInUse()
    @unknown default:
      LocationManager.shared.requestWhenInUse()
    }
  }

  private func finishOnboarding() {
    guard !isFinishing else { return }
    isFinishing = true
    currentUser.hasCompletedOnboarding = true
    try? modelContext.save()
    isFinishing = false
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

private struct StepPip: View {
  let isOn: Bool
  let mint: Color

  var body: some View {
    Capsule()
      .fill(isOn ? mint : Color.white.opacity(0.16))
      .frame(width: isOn ? 30 : 14, height: 10)
      .overlay(
        Capsule()
          .stroke(mint.opacity(isOn ? 0.45 : 0.18), lineWidth: 1.0)
      )
      .animation(.snappy(duration: 0.18), value: isOn)
      .accessibilityHidden(true)
  }
}
