//
//  Friendship.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/29/25.
//

import Foundation
import SwiftData

@Model
final class Friendship {

  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var isAccepted: Bool

  var fromUser: VibcomUser
  var toUser: VibcomUser

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    isAccepted: Bool = false,
    fromUser: VibcomUser,
    toUser: VibcomUser
  ) {
    self.id = id
    self.createdAt = createdAt
    self.isAccepted = isAccepted
    self.fromUser = fromUser
    self.toUser = toUser
  }
}
