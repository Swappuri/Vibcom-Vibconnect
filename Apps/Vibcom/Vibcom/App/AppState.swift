//
//  AppState.swift
//  Vibcom
//

import Foundation

@MainActor
final class AppState: ObservableObject {

  @Published private(set) var currentUserID: UUID? {
    didSet {
      persistCurrentUser()
    }
  }

  @Published private(set) var currentUsername: String?

  var isAuthenticated: Bool {
    currentUserID != nil
  }

  @Published var isBrailleModeActive: Bool = true {
    didSet {
      if isBrailleModeActive == false {
        BraillePlaybackEngine.shared.stopAllOutput()
      }
    }
  }
  @Published var isStealthModeEnabled: Bool = false

  private let currentUserKey = "currentUserID"

  func setCurrentUser(_ user: VibcomUser?) {
    currentUserID = user?.id
    currentUsername = user?.username
  }

  func clearCurrentUserIdentity() {
    currentUserID = nil
    currentUsername = nil
  }

  private func persistCurrentUser() {
    if let id = currentUserID?.uuidString {
      UserDefaults.standard.set(id, forKey: currentUserKey)
    } else {
      UserDefaults.standard.removeObject(forKey: currentUserKey)
    }
  }

  func clearPersistedUser() {
    UserDefaults.standard.removeObject(forKey: currentUserKey)
  }

  func logout() {
    clearCurrentUserIdentity()
    isBrailleModeActive = true
    isStealthModeEnabled = false
    clearPersistedUser()
    SharedIdentityStore.clear()
    BraillePlaybackEngine.shared.stopAllOutput()
  }
}
