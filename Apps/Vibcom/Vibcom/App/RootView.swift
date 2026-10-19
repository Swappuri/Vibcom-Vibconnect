//
//  RootView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import FirebaseAuth
import SwiftData
import SwiftUI

struct RootView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @Query private var settingsRecords: [AccessibilitySettings]
  @Query private var allUsers: [VibcomUser]

  @State private var didAttemptRestore = false
  @State private var firebaseAuthUID: String?
  @State private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

  private func log(_ message: String) {
    print("[RootView] \(message)")
  }

  var body: some View {
    ZStack {
      Group {
        if let user = resolvedCurrentUser {
          MainAppView(currentUser: user)
        } else {
          AuthRootView()
        }
      }

      if appState.isStealthModeEnabled {
        Color.black
          .ignoresSafeArea()
          .allowsHitTesting(false)
      }

      StealthModeGestureCatcher {
        appState.isStealthModeEnabled.toggle()
        VibcomAccessibilityEngine.shared.announceElement(
          label: "Stealth Mode",
          hint: appState.isStealthModeEnabled ? "Enabled." : "Disabled.",
          brailleEnabled: appState.isBrailleModeActive
        )
      }
      .ignoresSafeArea()

      BrailleFeedbackModeGestureCatcher {
        guard appState.isBrailleModeActive else { return }
        BraillePlaybackEngine.shared.cycleFeedbackMode()
      }
      .ignoresSafeArea()
    }
    .task {
      await restorePersistedUserIfNeeded()
    }
    .onAppear {
      let authUser = Auth.auth().currentUser
      firebaseAuthUID = authUser?.uid
      log(
        "onAppear authUID=\(authUser?.uid ?? "nil") authPhone=\(authUser?.phoneNumber ?? "nil") sharedPhone=\(SharedIdentityStore.currentPhoneE164 ?? "nil") localUser=\(resolvedCurrentUser?.username ?? appState.currentUsername ?? "nil")"
      )
      if appState.currentUserID != nil && resolvedCurrentUser == nil {
        log("stored current user missing from live store, clearing session identity")
        appState.clearCurrentUserIdentity()
      }
      if authStateListenerHandle == nil {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
          firebaseAuthUID = user?.uid
          log("auth state changed uid=\(user?.uid ?? "nil") phone=\(user?.phoneNumber ?? "nil")")
        }
      }
    }
    .onDisappear {
      if let authStateListenerHandle {
        Auth.auth().removeStateDidChangeListener(authStateListenerHandle)
        self.authStateListenerHandle = nil
      }
    }
    .task(id: cloudSyncIdentityKey) {
      guard let user = resolvedCurrentUser, firebaseAuthUID != nil else {
        log(
          "cloud sync blocked localUser=\(resolvedCurrentUser?.username ?? appState.currentUsername ?? "nil") authUID=\(firebaseAuthUID ?? "nil")"
        )
        ContactsLiveSyncCoordinator.shared.stop()
        ChatRealtimeCoordinator.shared.stop()
        return
      }
      log(
        "cloud sync starting localUser=\(user.username) authUID=\(firebaseAuthUID ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil")"
      )
      ChatRealtimeCoordinator.shared.start(currentUser: user, modelContext: modelContext)
      ContactsLiveSyncCoordinator.shared.start(currentUser: user, modelContext: modelContext)
      user.presence = .active
      try? modelContext.save()
      Task { try? await FirebaseUserStore.shared.updatePresence(.active) }
      FirestoreChatStore.shared.warmConnection(for: user.username)
      Task(priority: .utility) {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await syncNearbyDiscoveryLocationIfNeeded(for: user)
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard let user = resolvedCurrentUser else { return }

      if newPhase == .background || newPhase == .inactive {
        if user.presence == .active {
          user.presence = .offline
          try? modelContext.save()
          Task { try? await FirebaseUserStore.shared.updatePresence(.offline) }
        }
      } else if newPhase == .active {
        user.presence = .active
        try? modelContext.save()
        FirestoreChatStore.shared.warmConnection(for: user.username)
        Task(priority: .utility) {
          try? await Task.sleep(nanoseconds: 900_000_000)
          ContactsLiveSyncCoordinator.shared.triggerNow()
        }
        Task { try? await FirebaseUserStore.shared.updatePresence(.active) }
        Task(priority: .utility) {
          try? await Task.sleep(nanoseconds: 1_500_000_000)
          await syncNearbyDiscoveryLocationIfNeeded(for: user)
        }
      }
    }
  }

  @MainActor
  private func restorePersistedUserIfNeeded() async {
    guard !didAttemptRestore else { return }
    didAttemptRestore = true
    log(
      "restore start authUID=\(Auth.auth().currentUser?.uid ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") sharedPhone=\(SharedIdentityStore.currentPhoneE164 ?? "nil")"
    )

    guard appState.currentUserID == nil else { return }

    do {
      if let restoredUser = try restoreUserFromPersistedUUID() {
        log("restored from UUID username=\(restoredUser.username) id=\(restoredUser.id.uuidString)")
        appState.setCurrentUser(restoredUser)
        return
      }

      if let restoredUser = try restoreUserFromPhoneIdentity() {
        log(
          "restored from phone identity username=\(restoredUser.username) id=\(restoredUser.id.uuidString)"
        )
        appState.setCurrentUser(restoredUser)
        return
      }
      log("restore found no persisted user")
    } catch {
      log("restore failed error=\(error)")
    }
  }

  @MainActor
  private func restoreUserFromPersistedUUID() throws -> VibcomUser? {
    let key = "currentUserID"
    guard let idString = UserDefaults.standard.string(forKey: key),
      let uuid = UUID(uuidString: idString)
    else {
      log("UUID restore skipped storedID=nil")
      return nil
    }
    log("UUID restore trying storedID=\(idString)")

    var descriptor = FetchDescriptor<VibcomUser>(
      predicate: #Predicate { user in
        user.id == uuid
      }
    )
    descriptor.fetchLimit = 1

    let users = try modelContext.fetch(descriptor)
    if let user = users.first {
      return user
    }

    log("UUID restore missed storedID=\(idString), clearing persisted ID")
    UserDefaults.standard.removeObject(forKey: key)
    return nil
  }

  @MainActor
  private func restoreUserFromPhoneIdentity() throws -> VibcomUser? {
    let firebasePhone = Auth.auth().currentUser?.phoneNumber
    let sharedPhone = SharedIdentityStore.currentPhoneE164
    let phone = firebasePhone ?? sharedPhone

    guard let phone, phone.isEmpty == false else {
      log("phone restore skipped authPhone=nil sharedPhone=\(sharedPhone ?? "nil")")
      return nil
    }
    log(
      "phone restore trying phone=\(phone) authPhone=\(firebasePhone ?? "nil") sharedPhone=\(sharedPhone ?? "nil")"
    )

    var descriptor = FetchDescriptor<VibcomUser>(
      predicate: #Predicate { user in
        user.username == phone
      }
    )
    descriptor.fetchLimit = 1

    let users = try modelContext.fetch(descriptor)
    guard let user = users.first else {
      log("phone restore missed phone=\(phone)")
      return nil
    }

    SharedIdentityStore.save(
      uid: Auth.auth().currentUser?.uid ?? SharedIdentityStore.currentUID ?? "",
      phoneE164: phone
    )
    UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserID")
    return user
  }

  private var settings: AccessibilitySettings? {
    settingsRecords.first
  }

  private var cloudSyncIdentityKey: String {
    "\(appState.currentUserID?.uuidString ?? "none")|\(firebaseAuthUID ?? "unauthenticated")"
  }

  private var resolvedCurrentUser: VibcomUser? {
    guard let currentUserID = appState.currentUserID else { return nil }
    return allUsers.first(where: { $0.id == currentUserID })
  }

  @MainActor
  private func syncNearbyDiscoveryLocationIfNeeded(for user: VibcomUser) async {
    let isEnabled = settings?.locationAccessEnabled ?? false
    let phone = user.username

    guard isEnabled else {
      try? await FirebaseUserStore.shared.setNearbyDiscoveryEnabled(false)
      return
    }

    do {
      guard let location = try await LocationManager.shared.requestCurrentLocationIfAuthorized()
      else {
        try? await FirebaseUserStore.shared.setNearbyDiscoveryEnabled(false)
        return
      }

      try await FirebaseUserStore.shared.updateNearbyDiscoveryLocation(
        phoneE164: phone,
        location: location,
        isDiscoverableNearby: true
      )
    } catch {
      print("Failed to sync nearby discovery location: \(error)")
    }
  }
}
