//
//  FirestoreChatStore.swift
//  Vibcom
//

import FirebaseFirestore
import Foundation

struct RemoteChatMessage: Identifiable, Hashable {
  let id: String
  let text: String
  let authorUsername: String
  let createdAt: Date
}

struct RemoteConversationSummary: Identifiable, Hashable {
  let id: String
  let participants: [String]
  let lastMessageText: String?
  let lastMessageAt: Date?
}

final class FirestoreChatStore {

  static let shared = FirestoreChatStore()

  private lazy var db: Firestore = {
    AppDelegate.configureFirebaseIfNeeded()
    return Firestore.firestore()
  }()

  private init() {
    AppDelegate.configureFirebaseIfNeeded()
  }

  private func log(_ message: String) {
    print("[FirestoreChatStore] \(message)")
  }

  static func canonicalUsername(_ username: String) -> String {
    username
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  func sendMessage(
    participants: [String],
    authorUsername: String,
    text: String,
    createdAt: Date = .now
  ) async throws {
    let normalizedParticipants = normalizedParticipants(from: participants)
    guard normalizedParticipants.count == 2 else { return }

    let conversationID = conversationKey(for: normalizedParticipants)
    log(
      "sendMessage conversationID=\(conversationID) participants=\(normalizedParticipants) author=\(Self.canonicalUsername(authorUsername)) createdAt=\(createdAt.timeIntervalSince1970)"
    )
    let conversationRef = db.collection("conversations").document(conversationID)

    try await conversationRef.setData(
      [
        "participants": normalizedParticipants,
        "updatedAt": FieldValue.serverTimestamp(),
        "lastMessageText": text,
        "lastMessageAt": Timestamp(date: createdAt),
      ], merge: true)

    try await conversationRef.collection("messages").addDocument(data: [
      "text": text,
      "authorUsername": Self.canonicalUsername(authorUsername),
      "createdAt": Timestamp(date: createdAt),
      "serverCreatedAt": FieldValue.serverTimestamp(),
    ])
  }

  func fetchMessages(participants: [String]) async throws -> [RemoteChatMessage] {
    let normalizedParticipants = normalizedParticipants(from: participants)
    guard normalizedParticipants.count == 2 else { return [] }

    let conversationID = conversationKey(for: normalizedParticipants)
    log("fetchMessages conversationID=\(conversationID) participants=\(normalizedParticipants)")
    let snapshot = try await db.collection("conversations")
      .document(conversationID)
      .collection("messages")
      .order(by: "createdAt", descending: false)
      .getDocuments()
    log("fetchMessages success conversationID=\(conversationID) count=\(snapshot.documents.count)")

    return snapshot.documents.compactMap { document in
      let data = document.data()
      let text = (data["text"] as? String) ?? ""
      let authorUsername = (data["authorUsername"] as? String) ?? ""

      let createdAtTimestamp =
        (data["createdAt"] as? Timestamp) ?? (data["serverCreatedAt"] as? Timestamp)

      guard let createdAtTimestamp else { return nil }

      return RemoteChatMessage(
        id: document.documentID,
        text: text,
        authorUsername: authorUsername,
        createdAt: createdAtTimestamp.dateValue()
      )
    }
  }

  func fetchConversationSummaries(for username: String) async throws -> [RemoteConversationSummary]
  {
    let me = Self.canonicalUsername(username)
    log("fetchConversationSummaries username=\(me)")
    let snapshot = try await db.collection("conversations")
      .whereField("participants", arrayContains: me)
      .getDocuments()
    log("fetchConversationSummaries success username=\(me) count=\(snapshot.documents.count)")

    var summaries: [RemoteConversationSummary] = []
    summaries.reserveCapacity(snapshot.documents.count)

    for document in snapshot.documents {
      let data = document.data()
      let participants = (data["participants"] as? [String]) ?? []
      guard participants.contains(me) else { continue }

      let lastMessageText = data["lastMessageText"] as? String
      let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue()

      summaries.append(
        RemoteConversationSummary(
          id: document.documentID,
          participants: participants,
          lastMessageText: lastMessageText,
          lastMessageAt: lastMessageAt
        )
      )
    }

    return summaries.sorted { lhs, rhs in
      let l = lhs.lastMessageAt ?? .distantPast
      let r = rhs.lastMessageAt ?? .distantPast
      return l > r
    }
  }

  func warmConnection(for username: String) {
    let normalized = Self.canonicalUsername(username)
    guard normalized.isEmpty == false else { return }

    Task(priority: .userInitiated) {
      _ = try? await fetchConversationSummaries(for: normalized)
    }
  }

  @discardableResult
  func listenForMessages(
    participants: [String],
    onChange: @escaping (Result<[RemoteChatMessage], Error>) -> Void
  ) -> ListenerRegistration? {
    let normalizedParticipants = normalizedParticipants(from: participants)
    guard normalizedParticipants.count == 2 else { return nil }

    let conversationID = conversationKey(for: normalizedParticipants)
    log(
      "listenForMessages attach conversationID=\(conversationID) participants=\(normalizedParticipants)"
    )
    return db.collection("conversations")
      .document(conversationID)
      .collection("messages")
      .order(by: "createdAt", descending: false)
      .addSnapshotListener { snapshot, error in
        if let error {
          self.log("listenForMessages failure conversationID=\(conversationID) error=\(error)")
          onChange(.failure(error))
          return
        }

        let messages =
          snapshot?.documents.compactMap { document -> RemoteChatMessage? in
            let data = document.data()
            let text = (data["text"] as? String) ?? ""
            let authorUsername = (data["authorUsername"] as? String) ?? ""
            let createdAtTimestamp =
              (data["createdAt"] as? Timestamp) ?? (data["serverCreatedAt"] as? Timestamp)

            guard let createdAtTimestamp else { return nil }

            return RemoteChatMessage(
              id: document.documentID,
              text: text,
              authorUsername: authorUsername,
              createdAt: createdAtTimestamp.dateValue()
            )
          } ?? []

        self.log("listenForMessages event conversationID=\(conversationID) count=\(messages.count)")
        onChange(.success(messages))
      }
  }

  @discardableResult
  func listenForConversationSummaries(
    for username: String,
    onChange: @escaping (Result<[RemoteConversationSummary], Error>) -> Void
  ) -> ListenerRegistration {
    let me = Self.canonicalUsername(username)
    log("listenForConversationSummaries attach username=\(me)")

    return db.collection("conversations")
      .whereField("participants", arrayContains: me)
      .addSnapshotListener { snapshot, error in
        if let error {
          self.log("listenForConversationSummaries failure username=\(me) error=\(error)")
          onChange(.failure(error))
          return
        }

        let summaries = (snapshot?.documents ?? []).compactMap {
          document -> RemoteConversationSummary? in
          let data = document.data()
          let participants = (data["participants"] as? [String]) ?? []
          guard participants.contains(me) else { return nil }

          return RemoteConversationSummary(
            id: document.documentID,
            participants: participants,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue()
          )
        }
        .sorted {
          ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
        }

        self.log("listenForConversationSummaries event username=\(me) count=\(summaries.count)")
        onChange(.success(summaries))
      }
  }

  private func normalizedParticipants(from participants: [String]) -> [String] {
    Array(Set(participants.map(Self.canonicalUsername))).sorted()
  }

  private func conversationKey(for normalizedParticipants: [String]) -> String {
    normalizedParticipants.joined(separator: "__")
  }
}
