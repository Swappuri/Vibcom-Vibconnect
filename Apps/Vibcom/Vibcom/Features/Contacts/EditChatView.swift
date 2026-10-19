//
//  EditChat.swift
//  Vibcom
//
//  Created by Swapnil Puri on 12/1/25.
//

import SwiftData
import SwiftUI

struct EditChatView: View {

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let currentUser: VibcomUser

  @Query(sort: \VibcomUser.username) private var allUsers: [VibcomUser]
  @Query private var allFriendships: [Friendship]

  @State private var searchText: String = ""
  @State private var isSendingRequest: UUID?
  @State private var isRemovingFriend: UUID?
  @State private var isHandlingRequest: UUID?
  @State private var errorMessage: String?

  private var mintGreen: Color { Color("MintGreen") }

  private enum Segment {
    case friends
    case recommended
    case requests
  }

  @State private var segment: Segment = .friends

  private var otherUsers: [VibcomUser] {
    allUsers.filter { $0.id != currentUser.id }
  }

  private var userFriendships: [Friendship] {
    allFriendships.filter { f in
      f.fromUser.id == currentUser.id || f.toUser.id == currentUser.id
    }
  }

  private var currentFriends: [VibcomUser] {
    userFriendships
      .filter { $0.isAccepted }
      .map { f in
        f.fromUser.id == currentUser.id ? f.toUser : f.fromUser
      }
  }

  private var incomingRequests: [Friendship] {
    allFriendships.filter { f in
      !f.isAccepted && f.toUser.id == currentUser.id
    }
  }

  private var incomingRequestUsers: [VibcomUser] {
    incomingRequests.map { $0.fromUser }
  }

  private var recommendedUsers: [VibcomUser] {
    let engagedIDs: Set<UUID> = Set(
      userFriendships.map { f in
        f.fromUser.id == currentUser.id ? f.toUser.id : f.fromUser.id
      }
    )

    return Array(
      otherUsers
        .filter { user in !engagedIDs.contains(user.id) }
        .prefix(3)
    )
  }

  private var searchResults: [VibcomUser] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }

    let base: [VibcomUser]
    switch segment {
    case .friends:
      base = currentFriends
    case .recommended:
      base = recommendedUsers
    case .requests:
      base = incomingRequestUsers
    }

    return base.filter { user in
      user.username.localizedCaseInsensitiveContains(query)
    }
  }

  private var searchPlaceholder: String {
    switch segment {
    case .friends: return "Search current friends"
    case .recommended: return "Search recommended"
    case .requests: return "Search requests"
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 24) {

        header

        VStack(spacing: 18) {
          VStack(spacing: 16) {
            segmentControl
            searchSection
            listSection
          }
          .frame(maxWidth: 360)
          .frame(maxWidth: .infinity, alignment: .center)

          if let errorMessage {
            Text(errorMessage)
              .font(.footnote)
              .foregroundColor(.red)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .vibcomAccessible(
                label: "Error.",
                hint: errorMessage
              )
          }
        }

        Spacer()
      }
      .padding(.horizontal, 24)
    }
    .navigationBarHidden(true)
    .overlay(
      TwoFingerBackTapCatcher {
        dismiss()
      }
      .ignoresSafeArea()
    )
  }

  private var header: some View {
    HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.title2.weight(.medium))
          .foregroundColor(mintGreen)
      }
      .vibcomAccessible(
        label: "Back button.",
        hint: "Return to the messages screen."
      )

      Text("Edit")
        .font(.title2.weight(.semibold))
        .foregroundColor(.white)
        .vibcomAccessible(
          label: "Edit chats screen.",
          hint: "Manage current friends, recommended connections, and incoming requests."
        )

      Spacer()
    }
    .padding(.top, 20)
  }

  private var segmentControl: some View {
    HStack(spacing: 8) {
      segmentButton(title: "Friends", segment: .friends)
      segmentButton(title: "Recommended", segment: .recommended)
      segmentButton(title: "Requests", segment: .requests)
    }
  }

  private func segmentButton(title: String, segment target: Segment) -> some View {
    let isSelected = (segment == target)

    return Button {
      segment = target
      searchText = ""
    } label: {
      Text(title)
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundColor(isSelected ? .black : mintGreen)
        .background(isSelected ? mintGreen : .clear)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(mintGreen, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .vibcomAccessible(
      label: "\(title) tab.",
      hint: tabHint(for: target)
    )
  }

  private func tabHint(for segment: Segment) -> String {
    switch segment {
    case .friends:
      return "Shows your current accepted friends. You can remove existing friends here."
    case .recommended:
      return "Shows people you may want to connect with. You can send new friend requests."
    case .requests:
      return "Shows incoming friend requests that you can accept or decline."
    }
  }

  private var searchSection: some View {
    AuthTextField(
      iconName: "magnifyingglass",
      placeholder: searchPlaceholder,
      text: $searchText,
      keyboardType: .default,
      mintGreen: mintGreen
    )
    .vibcomAccessible(
      label: "Search field.",
      hint: "Search within the current \(segmentLabel()) section."
    )
  }

  private func segmentLabel() -> String {
    switch segment {
    case .friends: return "friends"
    case .recommended: return "recommended"
    case .requests: return "requests"
    }
  }

  @ViewBuilder
  private var listSection: some View {
    let results = searchResults

    switch segment {
    case .friends:
      friendsList(results: results)
    case .recommended:
      recommendedList(results: results)
    case .requests:
      requestsList(results: results)
    }
  }

  @ViewBuilder
  private func friendsList(results: [VibcomUser]) -> some View {
    let source =
      results.isEmpty && !searchText.isEmpty ? [] : results.isEmpty ? currentFriends : results

    if source.isEmpty {
      Text("You have no current friends.")
        .font(.footnote)
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .center)
        .vibcomAccessible(
          label: "No current friends.",
          hint: "You do not have any accepted friends yet."
        )
    } else {
      VStack(spacing: 12) {
        ForEach(source) { friend in
          CurrentFriendCard(
            user: friend,
            isRemoving: isRemovingFriend == friend.id,
            onRemove: { removeFriend(friend) }
          )
        }
      }
    }
  }

  @ViewBuilder
  private func recommendedList(results: [VibcomUser]) -> some View {
    let source =
      results.isEmpty && !searchText.isEmpty ? [] : results.isEmpty ? recommendedUsers : results

    if source.isEmpty {
      Text("No recommendations yet.")
        .font(.footnote)
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .center)
        .vibcomAccessible(
          label: "No recommendations.",
          hint: "There are currently no users to recommend."
        )
    } else {
      VStack(spacing: 12) {
        ForEach(source) { user in
          FriendSuggestionCard(
            user: user,
            isSending: isSendingRequest == user.id,
            onRequest: { sendRequest(to: user) }
          )
        }
      }
    }
  }

  @ViewBuilder
  private func requestsList(results: [VibcomUser]) -> some View {
    let source =
      results.isEmpty && !searchText.isEmpty ? [] : results.isEmpty ? incomingRequestUsers : results

    if source.isEmpty {
      Text("You have no incoming requests.")
        .font(.footnote)
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .center)
        .vibcomAccessible(
          label: "No incoming requests.",
          hint: "You have not received any friend requests."
        )
    } else {
      VStack(spacing: 12) {
        ForEach(source) { user in
          IncomingRequestCard(
            user: user,
            isHandling: isHandlingRequest == user.id,
            onAccept: { acceptRequest(from: user) },
            onDecline: { declineRequest(from: user) }
          )
        }
      }
    }
  }

  private func sendRequest(to user: VibcomUser) {
    guard user.id != currentUser.id else { return }

    errorMessage = nil
    isSendingRequest = user.id

    Task { @MainActor in
      defer { isSendingRequest = nil }

      do {
        let currentID = currentUser.id
        let otherID = user.id

        var descriptor1 = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            f.fromUser.id == currentID && f.toUser.id == otherID
          }
        )
        descriptor1.fetchLimit = 1
        let existing1 = try modelContext.fetch(descriptor1)

        var descriptor2 = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            f.fromUser.id == otherID && f.toUser.id == currentID
          }
        )
        descriptor2.fetchLimit = 1
        let existing2 = try modelContext.fetch(descriptor2)

        if !existing1.isEmpty || !existing2.isEmpty {
          errorMessage = "You already have a relationship or request with this user."
          return
        }

        let friendship = Friendship(
          fromUser: currentUser,
          toUser: user
        )

        modelContext.insert(friendship)
        try modelContext.save()

      } catch {
        errorMessage = "Unable to send request right now. Please try again."
        print("Friend request error: \(error)")
      }
    }
  }

  private func removeFriend(_ user: VibcomUser) {
    isRemovingFriend = user.id
    errorMessage = nil

    Task { @MainActor in
      defer { isRemovingFriend = nil }

      do {
        let currentID = currentUser.id
        let otherID = user.id

        let descriptor1 = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            f.isAccepted && f.fromUser.id == currentID && f.toUser.id == otherID
          }
        )
        let descriptor2 = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            f.isAccepted && f.fromUser.id == otherID && f.toUser.id == currentID
          }
        )

        let f1 = try modelContext.fetch(descriptor1)
        let f2 = try modelContext.fetch(descriptor2)

        for friendship in (f1 + f2) {
          modelContext.delete(friendship)
        }

        if !f1.isEmpty || !f2.isEmpty {
          try modelContext.save()
        }

      } catch {
        errorMessage = "Unable to remove friend right now. Please try again."
        print("Remove friend error: \(error)")
      }
    }
  }

  private func acceptRequest(from user: VibcomUser) {
    isHandlingRequest = user.id
    errorMessage = nil

    Task { @MainActor in
      defer { isHandlingRequest = nil }

      do {
        let currentID = currentUser.id
        let otherID = user.id

        var descriptor = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            !f.isAccepted && f.fromUser.id == otherID && f.toUser.id == currentID
          }
        )
        descriptor.fetchLimit = 1

        guard let friendship = try modelContext.fetch(descriptor).first else {
          return
        }

        friendship.isAccepted = true
        try modelContext.save()

      } catch {
        errorMessage = "Unable to accept request right now."
        print("Accept request error: \(error)")
      }
    }
  }

  private func declineRequest(from user: VibcomUser) {
    isHandlingRequest = user.id
    errorMessage = nil

    Task { @MainActor in
      defer { isHandlingRequest = nil }

      do {
        let currentID = currentUser.id
        let otherID = user.id

        var descriptor = FetchDescriptor<Friendship>(
          predicate: #Predicate { f in
            !f.isAccepted && f.fromUser.id == otherID && f.toUser.id == currentID
          }
        )
        descriptor.fetchLimit = 1

        if let friendship = try modelContext.fetch(descriptor).first {
          modelContext.delete(friendship)
          try modelContext.save()
        }

      } catch {
        errorMessage = "Unable to decline request right now."
        print("Decline request error: \(error)")
      }
    }
  }
}

struct CurrentFriendCard: View {
  let user: VibcomUser
  let isRemoving: Bool
  let onRemove: () -> Void

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    HStack(spacing: 12) {
      UserAvatarView(user: user, size: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(user.username)
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.white)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: user.presence))
            .frame(width: 6, height: 6)
          Text(PresenceStyle.text(for: user.presence))
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
      }

      Spacer()

      Button(action: onRemove) {
        if isRemoving {
          ProgressView()
            .tint(.black)
            .frame(width: 24)
        } else {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
      }
      .background(mintGreen)
      .foregroundColor(.black)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .vibcomAccessible(
        label: "Remove \(user.username).",
        hint: "Double tap to remove this friend."
      )
    }
    .padding(10)
    .frame(maxWidth: .infinity)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(mintGreen, lineWidth: 2)
    )
    .vibcomAccessible(
      label: "Current friend: \(user.username).",
      hint:
        "Status: \(PresenceStyle.text(for: user.presence)). Long press the remove button to hear that you can remove this friend."
    )
  }
}

struct FriendSuggestionCard: View {
  let user: VibcomUser
  let isSending: Bool
  let onRequest: () -> Void

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    HStack(spacing: 12) {
      UserAvatarView(user: user, size: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(user.username)
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.white)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: user.presence))
            .frame(width: 6, height: 6)
          Text(PresenceStyle.text(for: user.presence))
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
      }

      Spacer()

      Button(action: onRequest) {
        if isSending {
          ProgressView()
            .tint(.black)
            .frame(width: 24)
        } else {
          Text("Add")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
      }
      .background(mintGreen)
      .foregroundColor(.black)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .vibcomAccessible(
        label: "Send request to \(user.username).",
        hint: "Double tap to send a friend request."
      )
    }
    .padding(10)
    .frame(maxWidth: .infinity)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(mintGreen, lineWidth: 2)
    )
    .vibcomAccessible(
      label: "Recommended user: \(user.username).",
      hint:
        "Status: \(PresenceStyle.text(for: user.presence)). Use the add button to send a friend request."
    )
  }
}

struct IncomingRequestCard: View {
  let user: VibcomUser
  let isHandling: Bool
  let onAccept: () -> Void
  let onDecline: () -> Void

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    HStack(spacing: 12) {
      UserAvatarView(user: user, size: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(user.username)
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.white)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: user.presence))
            .frame(width: 6, height: 6)
          Text(PresenceStyle.text(for: user.presence))
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
      }

      Spacer()

      if isHandling {
        ProgressView()
          .tint(mintGreen)
          .frame(width: 60)
      } else {
        HStack(spacing: 6) {
          Button(action: onDecline) {
            Text("Decline")
              .font(.caption.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .foregroundColor(mintGreen)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(mintGreen, lineWidth: 2)
              )
          }
          .vibcomAccessible(
            label: "Decline request from \(user.username).",
            hint: "Double tap to decline this friend request."
          )

          Button(action: onAccept) {
            Text("Accept")
              .font(.caption.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .foregroundColor(.black)
              .background(mintGreen)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .vibcomAccessible(
            label: "Accept request from \(user.username).",
            hint: "Double tap to accept this friend request and create a chat."
          )
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(mintGreen, lineWidth: 2)
    )
    .vibcomAccessible(
      label: "Incoming request from \(user.username).",
      hint:
        "Status: \(PresenceStyle.text(for: user.presence)). Use the accept or decline buttons to respond."
    )
  }
}
