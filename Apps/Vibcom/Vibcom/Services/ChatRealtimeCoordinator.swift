//
//  ChatRealtimeCoordinator.swift
//  Vibcom
//

import FirebaseFirestore
import Foundation
import SwiftData

@MainActor
final class ChatRealtimeCoordinator {

  static let shared = ChatRealtimeCoordinator()

  private var activeUserID: UUID?
  private var activeUsername: String?
  private var activeContext: ModelContext?

  private var summaryListener: ListenerRegistration?
  private var messageListeners: [String: ListenerRegistration] = [:]

  private init() {}

  func start(currentUser: VibcomUser, modelContext: ModelContext) {
    activeUserID = currentUser.id
    activeUsername = currentUser.username
    activeContext = modelContext
    installSummaryListener(for: currentUser)
  }

  func stop() {
    summaryListener?.remove()
    summaryListener = nil
    for listener in messageListeners.values {
      listener.remove()
    }
    messageListeners.removeAll()
    activeUserID = nil
    activeUsername = nil
    activeContext = nil
  }

  private func installSummaryListener(for currentUser: VibcomUser) {
    summaryListener?.remove()
    summaryListener = FirestoreChatStore.shared.listenForConversationSummaries(
      for: currentUser.username
    ) { [weak self] result in
      guard let self else { return }
      DispatchQueue.main.async {
        switch result {
        case .success(let summaries):
          self.updateMessageListeners(with: summaries)
        case .failure(let error):
          print("Realtime summary listener failed: \(error)")
        }
      }
    }
  }

  private func updateMessageListeners(with summaries: [RemoteConversationSummary]) {
    guard let me = activeUsername.map(FirestoreChatStore.canonicalUsername) else { return }

    let targetConversationIDs = Set(
      summaries.compactMap { summary -> String? in
        guard summary.participants.count == 2 else { return nil }
        guard summary.participants.contains(me) else { return nil }
        return summary.id
      }
    )

    for (conversationID, listener) in messageListeners
    where targetConversationIDs.contains(conversationID) == false {
      listener.remove()
      messageListeners.removeValue(forKey: conversationID)
    }

    for summary in summaries {
      guard summary.participants.count == 2 else { continue }
      guard messageListeners[summary.id] == nil else { continue }

      let registration = FirestoreChatStore.shared.listenForMessages(
        participants: summary.participants
      ) { [weak self] result in
        guard let self else { return }
        DispatchQueue.main.async {
          switch result {
          case .success(let remoteMessages):
            self.mergeRemoteMessages(remoteMessages, participants: summary.participants)
          case .failure(let error):
            print("Realtime message listener failed: \(error)")
          }
        }
      }

      if let registration {
        messageListeners[summary.id] = registration
      }
    }
  }

  private func mergeRemoteMessages(_ remoteMessages: [RemoteChatMessage], participants: [String]) {
    guard
      let context = activeContext,
      let currentUserID = activeUserID,
      let activeUsername
    else { return }

    let allUsers = (try? context.fetch(FetchDescriptor<VibcomUser>())) ?? []
    let allConversations = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
    let allMessages = (try? context.fetch(FetchDescriptor<Message>())) ?? []

    guard let currentUser = allUsers.first(where: { $0.id == currentUserID }) else { return }

    let canonicalParticipants = participants.map(FirestoreChatStore.canonicalUsername)
    guard canonicalParticipants.count == 2 else { return }

    guard
      let friendUsername = canonicalParticipants.first(where: {
        $0 != FirestoreChatStore.canonicalUsername(activeUsername)
      })
    else {
      return
    }

    let friendUser: VibcomUser
    if let existing = allUsers.first(where: {
      FirestoreChatStore.canonicalUsername($0.username) == friendUsername
    }) {
      friendUser = existing
    } else {
      let created = VibcomUser(
        email: "\(friendUsername)@vibcom.remote",
        username: friendUsername,
        displayName: friendUsername,
        passwordHash: "remote"
      )
      context.insert(created)
      friendUser = created
    }

    let conversation: Conversation
    if let existingConversation = allConversations.first(where: { conv in
      let ids = conv.participants.map(\.id)
      return ids.count == 2 && ids.contains(currentUser.id) && ids.contains(friendUser.id)
    }) {
      conversation = existingConversation
    } else {
      let createdConversation = Conversation(participants: [currentUser, friendUser])
      context.insert(createdConversation)
      conversation = createdConversation
    }

    let localSignatures = Set(
      allMessages
        .filter { $0.conversation?.id == conversation.id }
        .map(Self.messageSignature)
    )

    let normalizedCurrent = FirestoreChatStore.canonicalUsername(currentUser.username)
    var didChange = false

    for remoteMessage in remoteMessages {
      let normalizedAuthor = FirestoreChatStore.canonicalUsername(remoteMessage.authorUsername)
      let signature = Self.messageSignature(
        text: remoteMessage.text,
        createdAt: remoteMessage.createdAt,
        normalizedAuthor: normalizedAuthor
      )
      guard localSignatures.contains(signature) == false else { continue }

      let author: VibcomUser? = normalizedAuthor == normalizedCurrent ? currentUser : friendUser
      let restored = Message(
        text: remoteMessage.text,
        createdAt: remoteMessage.createdAt,
        isIncoming: normalizedAuthor != normalizedCurrent,
        brailleEncoded: nil,
        seenByOtherUser: false,
        conversation: conversation,
        author: author
      )
      context.insert(restored)
      didChange = true
    }

    if let latest = remoteMessages.last?.createdAt, conversation.updatedAt < latest {
      conversation.updatedAt = latest
      didChange = true
    }

    if didChange {
      try? context.save()
    }
  }

  private static func messageSignature(_ message: Message) -> String {
    let normalizedAuthor = FirestoreChatStore.canonicalUsername(message.author?.username ?? "")
    return messageSignature(
      text: message.text,
      createdAt: message.createdAt,
      normalizedAuthor: normalizedAuthor
    )
  }

  private static func messageSignature(text: String, createdAt: Date, normalizedAuthor: String)
    -> String
  {
    let stamp = Int(createdAt.timeIntervalSince1970 * 1000)
    return "\(normalizedAuthor)|\(stamp)|\(text)"
  }
}
