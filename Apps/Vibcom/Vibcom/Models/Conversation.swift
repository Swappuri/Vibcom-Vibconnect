//
//  Conversation.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import Foundation
import SwiftData

@Model
final class Conversation {

  @Attribute(.unique) var id: UUID
  var title: String
  var createdAt: Date
  var updatedAt: Date

  var participants: [VibcomUser]

  @Relationship(deleteRule: .cascade)
  var messages: [Message]

  init(
    id: UUID = UUID(),
    title: String,
    participants: [VibcomUser] = [],
    createdAt: Date = .now,
    updatedAt: Date = .now,
    messages: [Message] = []
  ) {
    self.id = id
    self.title = title
    self.participants = participants
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.messages = messages
  }

  convenience init(participants: [VibcomUser]) {
    let usernames = participants.map { $0.username }.joined(separator: ", ")
    let defaultTitle = "Chat with \(usernames)"

    self.init(
      title: defaultTitle,
      participants: participants
    )
  }

  func recordActivity() {
    updatedAt = .now
  }
}
