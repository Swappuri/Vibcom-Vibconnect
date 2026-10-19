//
//  VibcomUser.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class VibcomUser {

  @Attribute(.unique) var id: UUID
  @Attribute(.unique) var email: String
  @Attribute(.unique) var username: String

  var displayName: String
  var createdAt: Date
  var passwordHash: String
  var hasCompletedOnboarding: Bool = false
  var profileImageData: Data?
  var presenceStatus: String

  init(
    id: UUID = UUID(),
    email: String,
    username: String,
    displayName: String,
    passwordHash: String,
    createdAt: Date = .now,
    presenceStatus: String = "offline"
  ) {
    self.id = id
    self.email = email.lowercased()
    self.username = username
    self.displayName = displayName
    self.passwordHash = passwordHash
    self.createdAt = createdAt
    self.presenceStatus = presenceStatus
  }
}

enum PresenceStatus: String {
  case active
  case busy
  case dnd
  case offline
}

extension VibcomUser {
  var presence: PresenceStatus {
    get { PresenceStatus(rawValue: presenceStatus) ?? .offline }
    set { presenceStatus = newValue.rawValue }
  }
}

struct PresenceStyle {
  static func displayedStatus(for user: VibcomUser, currentUserID: UUID?) -> PresenceStatus {
    user.presence
  }

  static func color(for status: PresenceStatus) -> Color {
    switch status {
    case .active: return Color("MintGreen")
    case .busy: return .yellow
    case .dnd: return .red
    case .offline: return .gray
    }
  }

  static func text(for status: PresenceStatus) -> String {
    switch status {
    case .active: return "Active now"
    case .busy: return "Busy"
    case .dnd: return "Do Not Disturb"
    case .offline: return "Offline"
    }
  }
}
