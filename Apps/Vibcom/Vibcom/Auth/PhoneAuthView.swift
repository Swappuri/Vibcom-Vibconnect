//
//  PhoneAuthView.swift
//  Vibcom
//

import Contacts
import CoreLocation
import FirebaseAuth
import SwiftData
import SwiftUI
import UIKit

struct PhoneAuthView: View {

  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @ObservedObject private var locationManager = LocationManager.shared
  @Query private var settingsRecords: [AccessibilitySettings]

  private enum Step {
    case phone
    case code
    case contacts
    case location
  }

  @State private var step: Step = .phone

  @State private var phoneDigits: String = ""
  @State private var verificationCodeDigits: String = ""
  @State private var verificationID: String = ""

  @State private var isLoading: Bool = false
  @State private var errorMessage: String?

  @State private var matchedUsers: [VibcomRemoteUser] = []
  @State private var isSyncingContacts: Bool = false
  @State private var didAutoFinishAfterContacts: Bool = false

  // Maps remote phoneE164 to the local contact name
  @State private var contactNameByPhoneE164: [String: String] = [:]

  // Used to enter app after contacts step
  @State private var pendingLocalUser: VibcomUser?

  @FocusState private var keyboardFocus: KeyboardField?
  private enum KeyboardField { case phone, code }

  private var mintGreen: Color { Color("MintGreen") }

  private let contactsPromptedKey = "didPromptContactsPermission"
  private let locationPromptedKey = "didPromptLocationPermission"
  private let didSetDefaultBrailleKey = "didSetDefaultBraille"

  private var settings: AccessibilitySettings {
    if let existing = settingsRecords.first { return existing }
    let created = AccessibilitySettings()
    // Default to Braille Mode for a brand new settings record.
    created.brailleModeEnabled = true
    modelContext.insert(created)
    try? modelContext.save()
    return created
  }

  private var isCompactLayout: Bool {
    horizontalSizeClass == .compact
  }

  private var authContentMaxWidth: CGFloat {
    .infinity
  }

  private var authContentHorizontalInset: CGFloat {
    isCompactLayout ? 16 : 22
  }

  var body: some View {
    ZStack {
      background

      VStack(spacing: 0) {
        header
          .padding(.horizontal, authContentHorizontalInset)
          .padding(.top, isCompactLayout ? 12 : 18)
          .padding(.bottom, isCompactLayout ? 10 : 14)

        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 14) {
            if let errorMessage {
              errorBanner(errorMessage)
            }

            mainCard
            authSupportPanel
          }
          .frame(maxWidth: authContentMaxWidth)
          .frame(maxWidth: .infinity)
          .padding(.horizontal, authContentHorizontalInset)
          .padding(.bottom, isCompactLayout ? 12 : 20)
          .padding(.top, 2)
          .frame(maxWidth: .infinity, minHeight: 0)
        }

        if step != .contacts && step != .location {
          if appState.isBrailleModeActive {
            authBrailleInputArea
              .frame(maxWidth: authContentMaxWidth)
              .padding(.horizontal, authContentHorizontalInset)
          } else {
            keyboardActionBar
              .frame(maxWidth: authContentMaxWidth)
              .padding(.horizontal, authContentHorizontalInset)
          }
        } else {
          Color.clear.frame(height: 12)
        }
      }
    }
    .onAppear {
      // Make Braille Mode the default for first-time launch, but keep user preference after.
      let didSetDefault = UserDefaults.standard.bool(forKey: didSetDefaultBrailleKey)
      if didSetDefault == false {
        settings.brailleModeEnabled = true
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: didSetDefaultBrailleKey)
      }

      appState.isBrailleModeActive = settings.brailleModeEnabled
      applyInitialFocusIfNeeded()
    }
    .onChange(of: step) { _, newStep in
      applyInitialFocusIfNeeded()
      if newStep == .contacts {
        handleContactsStepEntry()
      } else if newStep == .location {
        handleLocationStepEntry()
      }
    }
    .onChange(of: appState.isBrailleModeActive) { _, _ in
      applyInitialFocusIfNeeded()
    }
    .onChange(of: locationManager.authorizationStatus) { _, newStatus in
      guard step == .location else { return }
      guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else { return }
      completeLocationStepAndEnterApp()
    }
  }

  // MARK: - UI

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
      VStack(alignment: .leading, spacing: 6) {
        Image("Vibcom Main Logo")
          .resizable()
          .scaledToFit()
          .frame(width: isCompactLayout ? 54 : 64, height: isCompactLayout ? 54 : 64)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }

      brailleModePill
        .frame(maxWidth: .infinity)
    }
  }

  private var brailleModePill: some View {
    BrailleModeTogglePill(
      isOn: Binding(
        get: { appState.isBrailleModeActive },
        set: { setBrailleMode($0) }
      ),
      activeColor: mintGreen
    )
  }

  private var mainCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      stepIndicator

      VStack(alignment: .leading, spacing: 4) {
        Text(stepTitle)
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text(stepSubtitle)
          .font(.subheadline.weight(.medium))
          .foregroundColor(.white.opacity(0.74))
          .fixedSize(horizontal: false, vertical: true)
      }

      switch step {
      case .phone:
        phoneSection
      case .code:
        codeSection
      case .contacts:
        contactsSection
      case .location:
        locationSection
      }
    }
    .padding(isCompactLayout ? 16 : 20)
    .background(glassBackground(cornerRadius: 26))
  }

  private var stepIndicator: some View {
    HStack(spacing: 10) {
      StepPip(isOn: step == .phone, mint: mintGreen)
      StepPip(isOn: step == .code, mint: mintGreen)
      StepPip(isOn: step == .contacts, mint: mintGreen)
      StepPip(isOn: step == .location, mint: mintGreen)
      Spacer(minLength: 0)
    }
    .accessibilityHidden(true)
  }

  private var phoneSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Phone number")
        .font(.headline)
        .foregroundColor(.white)

      ZStack {
        valueRow(
          icon: "phone.fill",
          value: PhoneDisplayFormatter.usPretty(digits: phoneDigits),
          isPlaceholder: phoneDigits.isEmpty
        )

        if appState.isBrailleModeActive == false {
          KeyboardOverlayPhoneField(digits: $phoneDigits)
            .focused($keyboardFocus, equals: .phone)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        if appState.isBrailleModeActive == false {
          keyboardFocus = .phone
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Phone number")
    .accessibilityValue(
      phoneDigits.isEmpty ? "Empty." : phoneDigits.map(String.init).joined(separator: " "))
  }

  private var codeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Verification code")
        .font(.headline)
        .foregroundColor(.white)

      ZStack {
        valueRow(
          icon: "number.circle.fill",
          value: displayCode,
          isPlaceholder: verificationCodeDigits.isEmpty
        )

        if appState.isBrailleModeActive == false {
          KeyboardOverlayCodeField(code: $verificationCodeDigits)
            .focused($keyboardFocus, equals: .code)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        if appState.isBrailleModeActive == false {
          keyboardFocus = .code
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Verification code")
    .accessibilityValue(
      verificationCodeDigits.isEmpty
        ? "Empty." : verificationCodeDigits.map(String.init).joined(separator: " "))
  }

  private var contactsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Contacts")
        .font(.headline)
        .foregroundColor(.white)

      contactsPrimaryButton
      contactsStatusSummary
    }
  }

  private var locationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Location")
        .font(.headline)
        .foregroundColor(.white)

      locationPrimaryButton
      locationStatusSummary
    }
  }

  private var contactsStatusSummary: some View {
    VStack(alignment: .leading, spacing: 6) {
      if isSyncingContacts {
        HStack(spacing: 10) {
          ProgressView().tint(mintGreen)
          Text("Syncing contacts")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.85))
          Spacer(minLength: 0)
        }
      } else {
        let count = matchedUsers.count
        if count == 0 {
          Text(
            "Allow contacts to prepopulate your chats with people from your contacts who are already on Vibcom."
          )
          .font(.footnote)
          .foregroundColor(.white.opacity(0.70))
          .fixedSize(horizontal: false, vertical: true)
        } else {
          let suffix = (count == 1) ? "" : "s"
          Text("Found \(count) contact\(suffix) on Vibcom. Chats will be created automatically.")
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private var contactsPrimaryButton: some View {
    let status = CNContactStore.authorizationStatus(for: .contacts)

    if status == .denied || status == .restricted {
      return AnyView(
        Button {
          openSystemSettings()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
            Text("Open Settings to allow contacts")
              .font(.headline)
            Spacer()
          }
          .foregroundColor(.black)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(mintGreen)
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
      )
    }

    if status == .authorized {
      return AnyView(
        Button {
          requestContactsAccessAndSync(shouldAutoFinish: true)
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "arrow.clockwise")
            Text(isSyncingContacts ? "Syncing" : "Sync contacts")
              .font(.headline)
            Spacer()
            if isSyncingContacts {
              ProgressView().tint(.black)
            }
          }
          .foregroundColor(.black)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(mintGreen)
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(isSyncingContacts)
      )
    }

    return AnyView(
      Button {
        requestContactsAccessAndSync(shouldAutoFinish: true)
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "person.2.fill")
          Text(isSyncingContacts ? "Syncing" : "Allow contacts")
            .font(.headline)
          Spacer()
          if isSyncingContacts {
            ProgressView().tint(.black)
          }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(mintGreen)
        .clipShape(RoundedRectangle(cornerRadius: 18))
      }
      .disabled(isSyncingContacts)
    )
  }

  private var locationPrimaryButton: some View {
    let status = locationManagerStatus

    if status == .denied || status == .restricted {
      return AnyView(
        Button {
          openSystemSettings()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
            Text("Open Settings to allow location")
              .font(.headline)
            Spacer()
          }
          .foregroundColor(.black)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(mintGreen)
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
      )
    }

    if status == .authorizedWhenInUse || status == .authorizedAlways {
      return AnyView(
        Button {
          completeLocationStepAndEnterApp()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
            Text("Continue")
              .font(.headline)
            Spacer()
          }
          .foregroundColor(.black)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(mintGreen)
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }
      )
    }

    return AnyView(
      Button {
        requestLocationPermission()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "location.fill")
          Text("Enable location")
            .font(.headline)
          Spacer()
        }
        .foregroundColor(.black)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(mintGreen)
        .clipShape(RoundedRectangle(cornerRadius: 18))
      }
    )
  }

  private var locationStatusSummary: some View {
    VStack(alignment: .leading, spacing: 6) {
      switch locationManagerStatus {
      case .authorizedAlways, .authorizedWhenInUse:
        Text("Location enabled. Nearby discovery is ready.")
          .font(.footnote.weight(.semibold))
          .foregroundColor(.white.opacity(0.82))
          .fixedSize(horizontal: false, vertical: true)
      case .denied, .restricted:
        Text("Location access is blocked. Open Settings to continue.")
          .font(.footnote)
          .foregroundColor(.white.opacity(0.70))
          .fixedSize(horizontal: false, vertical: true)
      case .notDetermined:
        Text("Allow location access to appear in nearby discovery.")
          .font(.footnote)
          .foregroundColor(.white.opacity(0.70))
          .fixedSize(horizontal: false, vertical: true)
      @unknown default:
        Text("Allow location access to continue.")
          .font(.footnote)
          .foregroundColor(.white.opacity(0.70))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func valueRow(icon: String, value: String, isPlaceholder: Bool) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(mintGreen)
        .frame(width: 24, alignment: .center)

      Text(value)
        .font(.system(size: 24, weight: .semibold, design: .rounded))
        .foregroundColor(isPlaceholder ? .white.opacity(0.35) : .white)

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

  private func errorBanner(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.red)

      Text(text)
        .font(.footnote.weight(.semibold))
        .foregroundColor(.white.opacity(0.92))

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(Color.red.opacity(0.12))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.red.opacity(0.35), lineWidth: 1.2)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private var keyboardActionBar: some View {
    VStack(spacing: 0) {
      Divider().opacity(0.08)

      Button {
        primaryAction()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: primaryIconName)
          Text(primaryActionLabel)
            .font(.headline)

          Spacer()

          if isLoading {
            ProgressView().tint(.black)
          }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
          keyboardPrimaryEnabled ? mintGreen : Color.white.opacity(0.28)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 0)
        .padding(.top, 10)
        .padding(.bottom, 14)
      }
      .disabled(isLoading || keyboardPrimaryEnabled == false)
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

  private var authBrailleInputArea: some View {
    VStack(spacing: 0) {
      GestureBrailleInputView(
        text: authBrailleDigitsBinding,
        onSend: primaryAction,
        showComposePreview: false,
        usesNumericInput: true,
        contentHorizontalPadding: 0,
        padFillColor: Color.white.opacity(0.02),
        showsContainerBackground: false
      )
      .padding(.top, 6)
      .padding(.bottom, 10)
    }
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.70), Color.black.opacity(0.88)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea(edges: .bottom)
    )
  }

  private var authSupportPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Accessibility shortcuts", systemImage: "sparkles")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(mintGreen)

      Text(
        "Braille mode: swipe toggle right or left. Use gesture input in braille mode and keyboard entry when braille mode is off."
      )
      .font(.footnote)
      .foregroundColor(.white.opacity(0.76))
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(Color.white.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    )
  }

  private var stepTitle: String {
    switch step {
    case .phone: return "Verify your phone"
    case .code: return "Enter verification code"
    case .contacts: return "Connect your contacts"
    case .location: return "Enable location"
    }
  }

  private var stepSubtitle: String {
    switch step {
    case .phone: return "Use your phone number to securely sign in."
    case .code: return "Type the 6-digit code sent to your phone."
    case .contacts: return "Find people you know and auto-create chats."
    case .location: return "Allow nearby discovery so people around you can find you."
    }
  }

  // MARK: - Computed

  private var primaryIconName: String {
    switch step {
    case .phone: return "paperplane.fill"
    case .code: return "checkmark.circle.fill"
    case .contacts: return "checkmark.circle.fill"
    case .location: return "arrow.right.circle.fill"
    }
  }

  private var keyboardPrimaryEnabled: Bool {
    switch step {
    case .phone:
      return PhoneDisplayFormatter.usE164(digits: phoneDigits) != nil
    case .code:
      return verificationCodeDigits.count == 6 && verificationID.isEmpty == false
    case .contacts:
      return false
    case .location:
      return false
    }
  }

  private var bindingForCurrentStep: Binding<String> {
    switch step {
    case .phone: return $phoneDigits
    case .code: return $verificationCodeDigits
    case .contacts: return .constant("")
    case .location: return .constant("")
    }
  }

  private var authBrailleDigitsBinding: Binding<String> {
    Binding(
      get: {
        switch step {
        case .phone:
          return phoneDigits
        case .code:
          return verificationCodeDigits
        case .contacts:
          return ""
        case .location:
          return ""
        }
      },
      set: { newValue in
        let onlyDigits = newValue.filter { $0.isNumber }
        switch step {
        case .phone:
          phoneDigits = String(onlyDigits.prefix(10))
        case .code:
          verificationCodeDigits = String(onlyDigits.prefix(6))
        case .contacts:
          break
        case .location:
          break
        }
      }
    )
  }

  private var primaryActionLabel: String {
    switch step {
    case .phone: return "Send code"
    case .code: return "Verify"
    case .contacts: return ""
    case .location: return "Continue"
    }
  }

  private var displayCode: String {
    if verificationCodeDigits.isEmpty { return "• • • • • •" }
    let padded = verificationCodeDigits.padding(toLength: 6, withPad: "•", startingAt: 0)
    return padded.map { String($0) }.joined(separator: " ")
  }

  // MARK: - Actions

  private func primaryAction() {
    switch step {
    case .phone:
      requestCode()
    case .code:
      verifyCode()
    case .contacts:
      break
    case .location:
      primaryLocationAction()
      break
    }
  }

  private func setBrailleMode(_ enabled: Bool) {
    guard appState.isBrailleModeActive != enabled else { return }
    appState.isBrailleModeActive = enabled
    settings.brailleModeEnabled = enabled
    try? modelContext.save()

    if enabled == false {
      focusCurrentKeyboardFieldImmediately()
    } else {
      keyboardFocus = nil
    }
  }

  private func requestCode() {
    errorMessage = nil

    guard let e164 = PhoneDisplayFormatter.usE164(digits: phoneDigits) else {
      errorMessage = "Enter a valid 10 digit phone number."
      HapticsManager.shared.play(.commitFailure)
      return
    }

    isLoading = true
    PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
      DispatchQueue.main.async {
        isLoading = false

        if let error {
          errorMessage = error.localizedDescription
          HapticsManager.shared.play(.commitFailure)
          return
        }

        verificationID = id ?? ""
        if verificationID.isEmpty {
          errorMessage = "Could not start verification."
          HapticsManager.shared.play(.commitFailure)
          return
        }

        step = .code
        verificationCodeDigits = ""
        HapticsManager.shared.play(.commitSuccess)
      }
    }
  }

  private func verifyCode() {
    errorMessage = nil

    let code = verificationCodeDigits.trimmingCharacters(in: .whitespacesAndNewlines)
    guard code.count == 6 else {
      errorMessage = "Enter the 6 digit code."
      HapticsManager.shared.play(.commitFailure)
      return
    }

    guard verificationID.isEmpty == false else {
      errorMessage = "Missing verification session. Try again."
      HapticsManager.shared.play(.commitFailure)
      step = .phone
      return
    }

    isLoading = true

    let credential = PhoneAuthProvider.provider().credential(
      withVerificationID: verificationID,
      verificationCode: code
    )

    Auth.auth().signIn(with: credential) { result, error in
      DispatchQueue.main.async {
        isLoading = false

        if let error {
          errorMessage = error.localizedDescription
          HapticsManager.shared.play(.commitFailure)
          return
        }

        guard let firebaseUser = result?.user else {
          errorMessage = "Sign in failed."
          HapticsManager.shared.play(.commitFailure)
          return
        }

        let phoneE164 = firebaseUser.phoneNumber ?? ("+1" + phoneDigits.filter { $0.isNumber })
        SharedIdentityStore.save(uid: firebaseUser.uid, phoneE164: phoneE164)

        Task { @MainActor in
          do {
            try await FirebaseUserStore.shared.upsertCurrentUserProfile(
              phoneE164: phoneE164,
              displayName: nil
            )
          } catch {
            print("Firestore upsert failed: \(error)")
          }
        }

        do {
          var descriptor = FetchDescriptor<VibcomUser>(
            predicate: #Predicate { user in
              user.username == phoneE164
            }
          )
          descriptor.fetchLimit = 1

          let existing = try modelContext.fetch(descriptor).first
          let localUser: VibcomUser

          if let existing {
            localUser = existing
          } else {
            localUser = VibcomUser(
              email: "\(phoneE164)@vibcom.local",
              username: phoneE164,
              displayName: phoneE164,
              passwordHash: "firebase"
            )
            modelContext.insert(localUser)
            try modelContext.save()
          }

          pendingLocalUser = localUser

          // Returning users skip contacts and enter immediately.
          if localUser.hasCompletedOnboarding {
            finishAuthAndEnterApp()
            HapticsManager.shared.play(.commitSuccess)
            return
          }

          // New users go to contacts once.
          didAutoFinishAfterContacts = false
          step = .contacts
          HapticsManager.shared.play(.commitSuccess)
        } catch {
          errorMessage = "Signed in, but could not create local profile."
          HapticsManager.shared.play(.commitFailure)
        }
      }
    }
  }

  private func handleContactsStepEntry() {
    guard let user = pendingLocalUser else { return }
    guard user.hasCompletedOnboarding == false else { return }

    let status = CNContactStore.authorizationStatus(for: .contacts)
    let alreadyPrompted = UserDefaults.standard.bool(forKey: contactsPromptedKey)

    if status == .authorized {
      requestContactsAccessAndSync(shouldAutoFinish: true)
      return
    }

    if status == .notDetermined && alreadyPrompted == false {
      UserDefaults.standard.set(true, forKey: contactsPromptedKey)
      requestContactsAccessAndSync(shouldAutoFinish: true)
    }
  }

  private func requestContactsAccessAndSync(shouldAutoFinish: Bool = false) {
    errorMessage = nil

    Task { @MainActor in
      isSyncingContacts = true
      defer { isSyncingContacts = false }

      do {
        let granted = try await ContactsSyncService.shared.requestAccessIfNeeded()
        guard granted else {
          HapticsManager.shared.play(.commitFailure)
          return
        }

        // Fetch contacts off the main thread.
        let candidates = try await Task.detached(priority: .userInitiated) {
          try ContactsSyncService.shared.fetchContactPhoneCandidatesUS()
        }.value

        contactNameByPhoneE164 = Dictionary(
          uniqueKeysWithValues: candidates.map { ($0.phoneE164, $0.displayName) }
        )

        let phones = candidates.map { $0.phoneE164 }
        let remote = try await FirebaseUserStore.shared.fetchUsersByPhoneE164(phones)
        matchedUsers = remote

        if let me = pendingLocalUser {
          try ContactsSyncService.shared.materializeRemoteMatches(
            matchedUsers,
            contactNameByPhoneE164: contactNameByPhoneE164,
            for: me,
            in: modelContext
          )
        }

        if shouldAutoFinish && didAutoFinishAfterContacts == false {
          didAutoFinishAfterContacts = true
          step = .location
        }

        HapticsManager.shared.play(.commitSuccess)
      } catch {
        errorMessage = error.localizedDescription
        HapticsManager.shared.play(.commitFailure)
      }
    }
  }

  private func finishAuthAndEnterApp() {
    guard let user = pendingLocalUser else { return }
    user.hasCompletedOnboarding = true
    try? modelContext.save()
    appState.setCurrentUser(user)
    pendingLocalUser = nil
  }

  private func applyInitialFocusIfNeeded() {
    guard appState.isBrailleModeActive == false else {
      keyboardFocus = nil
      return
    }

    focusCurrentKeyboardFieldImmediately()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
      focusCurrentKeyboardFieldImmediately()
    }
  }

  private func focusCurrentKeyboardFieldImmediately() {
    switch step {
    case .phone:
      keyboardFocus = .phone
    case .code:
      keyboardFocus = .code
    case .contacts:
      keyboardFocus = nil
    case .location:
      keyboardFocus = nil
    }
  }

  private var locationManagerStatus: CLAuthorizationStatus {
    locationManager.authorizationStatus
  }

  private func handleLocationStepEntry() {
    guard pendingLocalUser != nil else { return }

    if locationManagerStatus == .authorizedWhenInUse || locationManagerStatus == .authorizedAlways {
      settings.locationAccessEnabled = true
      try? modelContext.save()
      return
    }

    let alreadyPrompted = UserDefaults.standard.bool(forKey: locationPromptedKey)
    if locationManagerStatus == .notDetermined && alreadyPrompted == false {
      UserDefaults.standard.set(true, forKey: locationPromptedKey)
      requestLocationPermission()
    }
  }

  private func primaryLocationAction() {
    switch locationManagerStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      completeLocationStepAndEnterApp()
    case .denied, .restricted:
      openSystemSettings()
    case .notDetermined:
      requestLocationPermission()
    @unknown default:
      requestLocationPermission()
    }
  }

  private func requestLocationPermission() {
    locationManager.requestWhenInUse()
  }

  private func completeLocationStepAndEnterApp() {
    settings.locationAccessEnabled =
      (locationManagerStatus == .authorizedWhenInUse || locationManagerStatus == .authorizedAlways)
    try? modelContext.save()
    finishAuthAndEnterApp()
  }

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

// MARK: - Small UI helpers

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

private struct KeyboardOverlayPhoneField: View {
  @Binding var digits: String

  var body: some View {
    TextField(
      "",
      text: Binding(
        get: { PhoneDisplayFormatter.usPrettyTyped(digits: digits) },
        set: { newValue in
          digits = String(newValue.filter { $0.isNumber }.prefix(10))
        }
      )
    )
    .keyboardType(.phonePad)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .foregroundColor(.clear)
    .accentColor(.clear)
    .tint(.clear)
    .opacity(0.02)
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(Color.clear)
  }
}

private struct KeyboardOverlayCodeField: View {
  @Binding var code: String

  var body: some View {
    TextField(
      "",
      text: Binding(
        get: { code },
        set: { newValue in
          code = String(newValue.filter { $0.isNumber }.prefix(6))
        }
      )
    )
    .keyboardType(.numberPad)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .foregroundColor(.clear)
    .accentColor(.clear)
    .tint(.clear)
    .opacity(0.02)
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(Color.clear)
  }
}

private enum PhoneDisplayFormatter {

  static func usPretty(digits: String) -> String {
    let d = digits.filter { $0.isNumber }
    let ten = String(d.prefix(10))

    if ten.isEmpty { return "(___) ___ ____" }
    if ten.count <= 3 { return "(\(ten)) ___ ____" }
    if ten.count <= 6 {
      let a = ten.prefix(3)
      let b = ten.dropFirst(3)
      return "(\(a)) \(b) ____"
    }

    let a = ten.prefix(3)
    let b = ten.dropFirst(3).prefix(3)
    let c = ten.dropFirst(6)
    return "(\(a)) \(b) \(c)"
  }

  static func usPrettyTyped(digits: String) -> String {
    let d = digits.filter { $0.isNumber }
    let ten = String(d.prefix(10))

    if ten.isEmpty { return "" }
    if ten.count <= 3 { return ten }
    if ten.count <= 6 {
      let a = ten.prefix(3)
      let b = ten.dropFirst(3)
      return "(\(a)) \(b)"
    }

    let a = ten.prefix(3)
    let b = ten.dropFirst(3).prefix(3)
    let c = ten.dropFirst(6)
    return "(\(a)) \(b) \(c)"
  }

  static func usE164(digits: String) -> String? {
    let d = digits.filter { $0.isNumber }
    if d.count == 10 { return "+1" + d }
    if d.count == 11, d.first == "1" { return "+" + d }
    return nil
  }
}
