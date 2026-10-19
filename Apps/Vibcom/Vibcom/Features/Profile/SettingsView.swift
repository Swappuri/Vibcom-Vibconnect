//
//  SettingsView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 12/2/25.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var appState: AppState

  @Query private var settingsRecords: [AccessibilitySettings]

  let currentUser: VibcomUser

  @State private var brailleModeOn: Bool = true
  @State private var locationAccessOn: Bool = false
  @State private var speechSpeed: Double = 100
  @State private var vibrationSpeed: Double = 1.0
  @State private var feedbackMode: BrailleFeedbackMode = .speechOnly
  @State private var selectedStatus: PresenceStatus = .active

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var errorMessage: String?

  @ObservedObject private var locationManager = LocationManager.shared
  @State private var showLocationSettingsAlert = false

  private var mintGreen: Color { Color("MintGreen") }

  private var settings: AccessibilitySettings {
    if let existing = settingsRecords.first {
      return existing
    } else {
      let created = AccessibilitySettings()
      modelContext.insert(created)
      do { try modelContext.save() } catch {
        print("Failed to save initial settings: \(error)")
      }
      return created
    }
  }

  private var vibrationSpeedFormatted: String {
    String(format: "%.1f", vibrationSpeed)
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 24) {
        header

        ScrollView {
          VStack(spacing: 24) {
            profileSection
            togglesAndSlidersSection
            signOutButton
          }
          .frame(maxWidth: 360)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.bottom, 24)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundColor(.red)
            .padding(.bottom, 6)
            .vibcomAccessible(
              label: "Error.",
              hint: errorMessage
            )
        }
      }
      .padding(.horizontal, 24)
    }
    .onAppear(perform: loadValues)
    .onChange(of: locationManager.authorizationStatus) { _, _ in
      syncLocationToggleWithSystem()
    }
    .alert(
      "Manage Location in Settings",
      isPresented: $showLocationSettingsAlert
    ) {
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
      Button("Cancel", role: .cancel) {
        syncLocationToggleWithSystem()
      }
    } message: {
      Text("To change Vibcom’s location access, use the iOS Settings app.")
    }
    .overlay(
      TwoFingerBackTapCatcher {
        dismiss()
      }
      .ignoresSafeArea()
    )
  }

  private var header: some View {
    HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.title2.weight(.medium))
          .foregroundColor(mintGreen)
      }
      .vibcomAccessible(
        label: "Back button.",
        hint: "Close settings and return to messages."
      )

      Text("Settings")
        .font(.title2.weight(.semibold))
        .foregroundColor(.white)
        .vibcomAccessible(
          label: "Settings screen.",
          hint:
            "Adjust braille mode, location, speech speed, vibration speed, and your presence status."
        )

      Spacer()
    }
    .padding(.top, 20)
  }

  private var profileSection: some View {
    VStack(spacing: 12) {

      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        ZStack {
          Circle()
            .stroke(mintGreen, lineWidth: 3)
            .frame(width: 120, height: 120)

          profileImage
            .clipShape(Circle())
            .frame(width: 112, height: 112)
        }
      }
      .onChange(of: selectedPhotoItem) { _, newItem in
        Task { await loadProfileImage(from: newItem) }
      }
      .vibcomAccessible(
        label: "Profile picture.",
        hint: "Long press to hear this is your profile image. Double tap to change it."
      )

      Text(currentUser.username)
        .font(.headline)
        .foregroundColor(.white)
        .vibcomAccessible(
          label: "Username \(currentUser.username).",
          hint: "Your Vibcom username."
        )

      Menu {
        Button {
          changeStatus(to: .active)
        } label: {
          Label("Active", systemImage: "circle.fill")
            .foregroundColor(PresenceStyle.color(for: .active))
        }

        Button {
          changeStatus(to: .busy)
        } label: {
          Label("Busy", systemImage: "circle.fill")
            .foregroundColor(PresenceStyle.color(for: .busy))
        }

        Button {
          changeStatus(to: .dnd)
        } label: {
          Label("Do Not Disturb", systemImage: "circle.fill")
            .foregroundColor(PresenceStyle.color(for: .dnd))
        }
      } label: {
        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: selectedStatus))
            .frame(width: 8, height: 8)
          Text(PresenceStyle.text(for: selectedStatus))
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
          Image(systemName: "chevron.down")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        }
      }
      .vibcomAccessible(
        label: "Status: \(PresenceStyle.text(for: selectedStatus)).",
        hint: "Double tap to change your status to Active, Busy, or Do Not Disturb."
      )
    }
    .padding(.top, 8)
  }

  @ViewBuilder
  private var profileImage: some View {
    if let data = currentUser.profileImageData,
      let uiImage = UIImage(data: data)
    {
      Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
    } else {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .scaledToFit()
        .foregroundColor(mintGreen)
    }
  }

  private func changeStatus(to newStatus: PresenceStatus) {
    selectedStatus = newStatus
    currentUser.presence = newStatus
    do {
      try modelContext.save()
    } catch {
      print("Failed to save presence: \(error)")
    }
    Task {
      do {
        try await FirebaseUserStore.shared.updatePresence(newStatus)
      } catch {
        print("Failed to update remote presence: \(error)")
      }
    }
  }

  private var togglesAndSlidersSection: some View {
    VStack(spacing: 16) {
      settingCard {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Braille Mode")
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.white)
            Text("Enable gesture-based braille interaction.")
              .font(.caption)
              .foregroundColor(.white.opacity(0.8))
          }
          Spacer()
          SwipeToggleControl(
            isOn: $brailleModeOn,
            activeColor: mintGreen
          )
        }
      }
      .onChange(of: brailleModeOn) { _, newValue in
        settings.brailleModeEnabled = newValue
        appState.isBrailleModeActive = newValue
        saveSettings()
      }
      .vibcomAccessible(
        label: "Braille Mode.",
        hint: "Swipe right to enable braille mode, or swipe left to disable it."
      )

      settingCard {
        Menu {
          ForEach(BrailleFeedbackMode.allCases, id: \.rawValue) { mode in
            Button {
              feedbackMode = mode
              BrailleFeedbackPreferences.mode = mode
              BraillePlaybackEngine.shared.feedbackMode = mode
            } label: {
              Text(mode.displayName)
            }
          }
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Braille Output")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
              Text("3-finger tap in braille mode cycles speech, tones, or both.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text(feedbackMode.displayName)
              .font(.caption.weight(.semibold))
              .foregroundColor(mintGreen)
          }
        }
      }
      .vibcomAccessible(
        label: "Braille output mode.",
        hint: "Choose speech only, tones only, or both."
      )

      settingCard {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Location Access")
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.white)
            Text("Connect with people near you.")
              .font(.caption)
              .foregroundColor(.white.opacity(0.8))
          }
          Spacer()
          Toggle("", isOn: $locationAccessOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(mintGreen)
        }
      }
      .onChange(of: locationAccessOn) { _, newValue in
        settings.locationAccessEnabled = newValue
        saveSettings()

        let status = locationManager.authorizationStatus

        if newValue {
          switch status {
          case .notDetermined:
            LocationManager.shared.requestWhenInUse()
          case .denied, .restricted:
            settings.locationAccessEnabled = false
            saveSettings()
            locationAccessOn = false
            showLocationSettingsAlert = true
          default:
            Task {
              do {
                if let location = try await LocationManager.shared
                  .requestCurrentLocationIfAuthorized()
                {
                  try await FirebaseUserStore.shared.updateNearbyDiscoveryLocation(
                    phoneE164: currentUser.username,
                    location: location,
                    isDiscoverableNearby: true
                  )
                } else {
                  try await FirebaseUserStore.shared.setNearbyDiscoveryEnabled(false)
                }
              } catch {
                print("Failed to enable nearby discovery location: \(error)")
              }
            }
            break
          }
        } else {
          Task {
            do {
              try await FirebaseUserStore.shared.setNearbyDiscoveryEnabled(false)
            } catch {
              print("Failed to disable nearby discovery location: \(error)")
            }
          }
        }
      }
      .vibcomAccessible(
        label: "Location access.",
        hint:
          "Toggle whether Vibcom can use your location to suggest nearby friends. Real permission is controlled in iOS Settings."
      )

      settingCard {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Speech Speed")
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.white)
              .vibcomAccessible(
                label: "Speech speed.",
                hint:
                  "Adjust how fast Vibcom reads text aloud. Currently \(Int(speechSpeed)) words per minute."
              )

            Spacer()

            Text("\(Int(speechSpeed)) WPM")
              .font(.caption)
              .foregroundColor(.white.opacity(0.8))
          }

          Slider(
            value: $speechSpeed,
            in: 50...250,
            step: 10
          )
          .tint(mintGreen)
        }
      }
      .onChange(of: speechSpeed) { _, newValue in
        settings.speechSpeedWPM = newValue
        saveSettings()
        applySpeechSpeed(newValue)
      }

      settingCard {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Vibration Speed")
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.white)
              .vibcomAccessible(
                label: "Vibration speed.",
                hint:
                  "Adjust how quickly braille tones play. Currently \(vibrationSpeedFormatted) times normal speed."
              )

            Spacer()

            Text("\(vibrationSpeedFormatted)x")
              .font(.caption)
              .foregroundColor(.white.opacity(0.8))
          }

          Slider(
            value: $vibrationSpeed,
            in: 0.35...1.25,
            step: 0.05
          )
          .tint(mintGreen)
        }
      }
      .onChange(of: vibrationSpeed) { _, newValue in
        let clamped = min(max(newValue, 0.35), 1.25)
        settings.vibrationSpeedMultiplier = clamped
        saveSettings()
        applyVibrationSpeed(clamped)
      }
    }
  }

  private func settingCard<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(mintGreen, lineWidth: 2)
      )
  }

  private var signOutButton: some View {
    Button {
      signOut()
    } label: {
      Text("SIGN OUT")
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(mintGreen)
        .foregroundColor(.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.top, 8)
    .vibcomAccessible(
      label: "Sign out.",
      hint: "Signs out of your Vibcom account and sets your status to offline."
    )
  }

  private func signOut() {
    currentUser.presence = .offline
    do {
      try modelContext.save()
    } catch {
      print("Failed to save presence on sign out: \(error)")
    }

    Task {
      do {
        try await FirebaseUserStore.shared.updatePresence(.offline)
      } catch {
        print("Failed to update remote presence on sign out: \(error)")
      }
    }

    UserDefaults.standard.removeObject(forKey: "currentUserID")
    SharedIdentityStore.clear()
    appState.clearCurrentUserIdentity()
    dismiss()
  }

  private func loadValues() {
    let s = settings
    selectedStatus = currentUser.presence

    brailleModeOn = s.brailleModeEnabled
    appState.isBrailleModeActive = s.brailleModeEnabled
    feedbackMode = BrailleFeedbackPreferences.mode
    BraillePlaybackEngine.shared.feedbackMode = feedbackMode

    let loadedSpeech = (s.speechSpeedWPM == 0) ? 100 : s.speechSpeedWPM
    speechSpeed = loadedSpeech
    applySpeechSpeed(loadedSpeech)

    var loadedVibration = s.vibrationSpeedMultiplier

    if loadedVibration == 0 {
      let legacy = s.vibrationFrequencyHz

      if legacy > 0, legacy <= 5 {
        loadedVibration = legacy
      } else {
        loadedVibration = 0.6
      }

      s.vibrationSpeedMultiplier = loadedVibration
      saveSettings()
    }

    vibrationSpeed = loadedVibration
    applyVibrationSpeed(loadedVibration)

    syncLocationToggleWithSystem()
  }

  private func syncLocationToggleWithSystem() {
    let status = locationManager.authorizationStatus
    let authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    locationAccessOn = settings.locationAccessEnabled && authorized
  }

  private func saveSettings() {
    do {
      try modelContext.save()
    } catch {
      print("Failed to save settings: \(error)")
    }
  }

  private func applySpeechSpeed(_ wpm: Double) {
    let clamped = min(max(wpm, 50), 250)
    let t = (clamped - 50) / (250 - 50)
    let rate = Float(0.3 + t * 0.4)

    VibcomAccessibilityEngine.shared.speechRate = rate
    SpeechManager.shared.configure(wordsPerMinute: Int(clamped.rounded()))
  }

  private func applyVibrationSpeed(_ speed: Double) {
    let clamped = min(max(speed, 0.35), 1.25)
    BraillePlaybackEngine.shared.vibrationSpeedMultiplier = clamped
  }

  private func loadProfileImage(from item: PhotosPickerItem?) async {
    guard let item else { return }

    do {
      if let data = try await item.loadTransferable(type: Data.self) {
        await MainActor.run {
          currentUser.profileImageData = data
          do {
            try modelContext.save()
          } catch {
            errorMessage = "Could not save profile image."
            print("Profile image save error: \(error)")
          }
        }
      }
    } catch {
      await MainActor.run {
        errorMessage = "Could not load selected image."
      }
      print("Photo picker error: \(error)")
    }
  }
}
