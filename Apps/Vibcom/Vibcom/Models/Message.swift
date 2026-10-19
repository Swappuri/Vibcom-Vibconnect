//
//  Message.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import Foundation
import SwiftData

@Model
final class Message {

  @Attribute(.unique) var id: UUID
  var text: String
  var createdAt: Date

  var isIncoming: Bool

  var brailleEncoded: String?

  var seenByOtherUser: Bool

  @Relationship(inverse: \Conversation.messages)
  var conversation: Conversation?

  var author: VibcomUser?

  init(
    id: UUID = UUID(),
    text: String,
    createdAt: Date = .now,
    isIncoming: Bool = false,
    brailleEncoded: String? = nil,
    seenByOtherUser: Bool = false,
    conversation: Conversation? = nil,
    author: VibcomUser? = nil
  ) {
    self.id = id
    self.text = text
    self.createdAt = createdAt
    self.isIncoming = isIncoming
    self.brailleEncoded = brailleEncoded
    self.seenByOtherUser = seenByOtherUser
    self.conversation = conversation
    self.author = author
  }

  func isIncoming(for user: VibcomUser) -> Bool {
    guard let author else { return true }
    return author.id != user.id
  }
}
