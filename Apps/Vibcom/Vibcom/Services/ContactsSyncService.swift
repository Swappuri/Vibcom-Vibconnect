//
//  ContactsSyncService.swift
//  Vibcom
//

import Contacts
import Foundation
import SwiftData

struct ContactPhoneCandidate: Hashable {
  let displayName: String
  let phoneE164: String
}

final class ContactsSyncService {

  static let shared = ContactsSyncService()

  private let store = CNContactStore()

  private init() {}

  // MARK: - Authorization

  enum ContactsAuthState: Equatable {
    case authorized
    case notDetermined
    case deniedOrRestricted
  }

  func authorizationState() -> ContactsAuthState {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      return .authorized
    case .limited:
      return .authorized
    case .notDetermined:
      return .notDetermined
    case .denied, .restricted:
      return .deniedOrRestricted
    @unknown default:
      return .deniedOrRestricted
    }
  }

  func requestAccessIfNeeded() async throws -> Bool {
    switch authorizationState() {
    case .authorized:
      return true
    case .deniedOrRestricted:
      return false
    case .notDetermined:
      return try await withCheckedThrowingContinuation { continuation in
        store.requestAccess(for: .contacts) { granted, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }
          continuation.resume(returning: granted)
        }
      }
    }
  }

  // MARK: - Fetch

  /// Returns a de-duplicated list of (displayName, phoneE164).
  /// - Dedupes by phoneE164.
  /// - Prefers "mobile" labeled numbers when multiple exist for the same contact.
  /// - Uses CNContactFormatter for better name formatting.
  func fetchContactPhoneCandidatesUS() throws -> [ContactPhoneCandidate] {
    let keys: [CNKeyDescriptor] = [
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactOrganizationNameKey as CNKeyDescriptor,
    ]

    let request = CNContactFetchRequest(keysToFetch: keys)
    request.unifyResults = true
    request.sortOrder = .userDefault

    // Deduplicate: phoneE164 -> best displayName
    var bestByPhone: [String: String] = [:]

    try store.enumerateContacts(with: request) { contact, _ in
      let name = ContactsSyncService.bestDisplayName(for: contact)

      // Collect numbers, preferring mobile
      let numbers = ContactsSyncService.preferredPhoneNumbers(from: contact.phoneNumbers)

      for labeled in numbers {
        let raw = labeled.value.stringValue
        if let e164 = PhoneNormalizer.usToE164(raw: raw) {
          let resolvedName =
            (name == "Contact")
            ? PhoneDisplayLabel.formattedIfPhone(e164)
            : name
          // Pick the "best" name for that phone number
          // If we already have a placeholder, upgrade to a better name
          if let existing = bestByPhone[e164] {
            if existing == "Contact", resolvedName != "Contact" {
              bestByPhone[e164] = resolvedName
            }
          } else {
            bestByPhone[e164] = resolvedName
          }
        }
      }
    }

    return bestByPhone.map { ContactPhoneCandidate(displayName: $0.value, phoneE164: $0.key) }
      .sorted {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
      }
  }

  private static func preferredPhoneNumbers(from numbers: [CNLabeledValue<CNPhoneNumber>])
    -> [CNLabeledValue<CNPhoneNumber>]
  {
    guard numbers.count > 1 else { return numbers }

    // Put mobile/iPhone first
    let preferredLabels: Set<String> = [CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone]
    let preferred = numbers.filter { lv in
      if let label = lv.label { return preferredLabels.contains(label) }
      return false
    }

    if !preferred.isEmpty {
      return preferred
        + numbers.filter { lv in !(preferred.contains { $0.identifier == lv.identifier }) }
    }
    return numbers
  }

  private static func bestDisplayName(for contact: CNContact) -> String {
    if let formatted = CNContactFormatter.string(from: contact, style: .fullName)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !formatted.isEmpty
    {
      return formatted
    }

    let org = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !org.isEmpty { return org }

    return "Contact"
  }

  // MARK: - Remote Match Materialization

  @MainActor
  func syncContactsIntoLocalChats(for currentUser: VibcomUser, in modelContext: ModelContext)
    async throws
  {
    guard authorizationState() == .authorized else { return }

    let candidates = try await Task.detached(priority: .userInitiated) {
      try ContactsSyncService.shared.fetchContactPhoneCandidatesUS()
    }.value

    let phoneBook = Dictionary(
      uniqueKeysWithValues: candidates.map { ($0.phoneE164, $0.displayName) })
    let phones = candidates.map(\.phoneE164)
    let remoteMatches = try await FirebaseUserStore.shared.fetchUsersByPhoneE164(phones)

    try materializeRemoteMatches(
      remoteMatches,
      contactNameByPhoneE164: phoneBook,
      for: currentUser,
      in: modelContext
    )
  }

  @MainActor
  func materializeRemoteMatches(
    _ remoteUsers: [VibcomRemoteUser],
    contactNameByPhoneE164: [String: String],
    for currentUser: VibcomUser,
    in modelContext: ModelContext
  ) throws {
    let existingUsers = (try? modelContext.fetch(FetchDescriptor<VibcomUser>())) ?? []
    let friendships = (try? modelContext.fetch(FetchDescriptor<Friendship>())) ?? []
    let conversations = (try? modelContext.fetch(FetchDescriptor<Conversation>())) ?? []

    func getOrCreateLocalUser(for remote: VibcomRemoteUser) -> VibcomUser {
      if let found = existingUsers.first(where: { $0.username == remote.phoneE164 }) {
        if let name = contactNameByPhoneE164[remote.phoneE164], name.isEmpty == false {
          found.displayName = name
        }
        return found
      }

      let display = contactNameByPhoneE164[remote.phoneE164] ?? remote.displayName
      let created = VibcomUser(
        email: "\(remote.phoneE164)@vibcom.remote",
        username: remote.phoneE164,
        displayName: display,
        passwordHash: "remote"
      )
      modelContext.insert(created)
      return created
    }

    func friendshipExists(with friend: VibcomUser) -> Bool {
      friendships.contains { f in
        (f.fromUser.id == currentUser.id && f.toUser.id == friend.id)
          || (f.fromUser.id == friend.id && f.toUser.id == currentUser.id)
      }
    }

    func conversationExists(with friend: VibcomUser) -> Bool {
      conversations.contains { c in
        let ids = c.participants.map(\.id)
        return ids.contains(currentUser.id) && ids.contains(friend.id) && ids.count == 2
      }
    }

    if remoteUsers.isEmpty == false {
      for remote in remoteUsers {
        let friend = getOrCreateLocalUser(for: remote)

        if friendshipExists(with: friend) == false {
          let friendship = Friendship(isAccepted: true, fromUser: currentUser, toUser: friend)
          modelContext.insert(friendship)
        }

        if conversationExists(with: friend) == false {
          let conversation = Conversation(participants: [currentUser, friend])
          conversation.updatedAt = .now
          modelContext.insert(conversation)
        }
      }
    }

    // Remove phone-based remote chats/friendships when their phone is no longer in Contacts.
    // This keeps contact-backed messaging authoritative and prevents stale local chats from surviving.
    func isPhoneBasedRemoteUser(_ user: VibcomUser) -> Bool {
      guard user.id != currentUser.id else { return false }
      let u = user.username
      guard u.hasPrefix("+") else { return false }
      return u.dropFirst().allSatisfy(\.isNumber)
    }

    let validContactPhones = Set(contactNameByPhoneE164.keys)
    func isStalePhoneBasedUser(_ user: VibcomUser) -> Bool {
      isPhoneBasedRemoteUser(user) && validContactPhones.contains(user.username) == false
    }

    let staleFriendships = friendships.filter { f in
      if f.fromUser.id == currentUser.id { return isStalePhoneBasedUser(f.toUser) }
      if f.toUser.id == currentUser.id { return isStalePhoneBasedUser(f.fromUser) }
      return false
    }
    for friendship in staleFriendships {
      modelContext.delete(friendship)
    }

    let staleConversations = conversations.filter { c in
      guard c.participants.count == 2 else { return false }
      guard c.participants.contains(where: { $0.id == currentUser.id }) else { return false }
      guard let other = c.participants.first(where: { $0.id != currentUser.id }) else {
        return false
      }
      return isStalePhoneBasedUser(other)
    }
    for conversation in staleConversations {
      modelContext.delete(conversation)
    }

    let deletedFriendUserIDs = Set(
      staleFriendships.flatMap { friendship in
        [friendship.fromUser.id, friendship.toUser.id]
      }
    )
    let deletedConversationUserIDs = Set(
      staleConversations.flatMap { conversation in
        conversation.participants.map(\.id)
      }
    )

    let staleUsers = existingUsers.filter { user in
      guard isStalePhoneBasedUser(user) else { return false }
      return deletedFriendUserIDs.contains(user.id) || deletedConversationUserIDs.contains(user.id)
    }
    for user in staleUsers {
      modelContext.delete(user)
    }

    try modelContext.save()
  }
}

enum PhoneNormalizer {

  static func digitsOnly(_ s: String) -> String {
    s.filter { $0.isNumber }
  }

  /// Best-effort E164:
  /// - 10 digits -> +1XXXXXXXXXX
  /// - 11 digits starting with 1 -> +1XXXXXXXXXX
  /// - +<digits> passthrough if enough digits exist
  static func usToE164(raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }

    if trimmed.hasPrefix("+") {
      let plusDigits = "+" + digitsOnly(trimmed)
      // Minimum sanity length: + + at least 8 digits
      if plusDigits.count >= 9 { return plusDigits }
      return nil
    }

    let d = digitsOnly(trimmed)

    if d.count == 10 {
      return "+1" + d
    }

    if d.count == 11, d.first == "1" {
      return "+" + d
    }

    return nil
  }
}
