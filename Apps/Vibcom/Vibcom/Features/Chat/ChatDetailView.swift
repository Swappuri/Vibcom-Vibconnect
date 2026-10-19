//
//  ChatDetailView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 12/2/25.
//

import FirebaseAuth
import FirebaseFirestore
import SwiftData
import SwiftUI

struct ChatDetailView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let currentUser: VibcomUser
  let friend: VibcomUser

  @Query private var allConversations: [Conversation]
  @Query private var allMessages: [Message]

  @State private var conversation: Conversation?
  @State private var inputText: String = ""
  @State private var messageListener: ListenerRegistration?
  @State private var presenceListeners: [ListenerRegistration] = []
  @State private var conversationMessages: [Message] = []
  @State private var bootstrapSyncTask: Task<Void, Never>?
  @State private var authBootstrapTask: Task<Void, Never>?

  // Deterministic focus like MessagesHomeView
  @State private var focusedMessageID: UUID?
  @State private var lastAnnouncedMessageID: UUID?

  private var mintGreen: Color { Color("MintGreen") }

  private let swipeThreshold: CGFloat = 55

  private func log(_ message: String) {
    print("[ChatDetail] \(message)")
  }

  private var friendDisplayLabel: String {
    PhoneDisplayLabel.resolvedName(displayName: friend.displayName, username: friend.username)
  }

  private var displayedFriendStatus: PresenceStatus {
    PresenceStyle.displayedStatus(for: friend, currentUserID: currentUser.id)
  }

  private var messageIdentitySignature: String {
    conversationMessages
      .map { "\($0.id.uuidString)|\($0.createdAt.timeIntervalSince1970)" }
      .joined(separator: ",")
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color.black, Color(red: 0.02, green: 0.08, blue: 0.07), Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      RadialGradient(
        colors: [mintGreen.opacity(0.16), .clear],
        center: .topTrailing,
        startRadius: 24,
        endRadius: 430
      )
      .ignoresSafeArea()
      LinearGradient(
        colors: [mintGreen.opacity(0.08), Color.clear, Color.black.opacity(0.40)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        header

        if conversationMessages.isEmpty {
          Spacer()
          Text("You have no messages.")
            .font(.body)
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .center)
            .vibcomAccessible(
              label: "No messages yet.",
              hint: "This conversation is empty. Type a message to start chatting."
            )
          Spacer()
        } else {
          messageCarousel
        }

        Divider()
          .overlay(Color.white.opacity(0.12))

        if appState.isBrailleModeActive {
          brailleInputArea
        } else {
          inputBar
        }
      }
    }
    .navigationBarHidden(true)
    .onAppear {
      ensureConversation()
      reloadConversationMessagesFromLocal()
      forceFocusToLatest()
      startCloudSyncWhenAuthenticated()
    }
    .onDisappear {
      stopRealtimeListeners()
      bootstrapSyncTask?.cancel()
      bootstrapSyncTask = nil
      authBootstrapTask?.cancel()
      authBootstrapTask = nil
    }
    .onChange(of: conversation?.id) { _, _ in
      reloadConversationMessagesFromLocal()
      forceFocusToLatest()
    }
    .onChange(of: allMessages.count) { _, _ in
      reloadConversationMessagesFromLocal()
      forceFocusToLatest()
    }
    .onChange(of: messageIdentitySignature) { _, _ in
      forceFocusToLatest()
    }
    .onChange(of: appState.isBrailleModeActive) { _, _ in
      if appState.isBrailleModeActive == false {
        BraillePlaybackEngine.shared.stopAllOutput()
        return
      }
      forceFocusToLatest()
      lastAnnouncedMessageID = nil
      if let last = conversationMessages.last {
        announce(message: last)
        lastAnnouncedMessageID = last.id
      }
    }
    .overlay(
      TwoFingerBackTapCatcher {
        BraillePlaybackEngine.shared.stopAllOutput()
        dismiss()
      }
      .ignoresSafeArea()
    )
  }

  private var messageCarousel: some View {
    GeometryReader { geo in
      let topInset = geo.size.height * 0.32
      let bottomInset = geo.size.height * 0.18

      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          LazyVStack(spacing: 14) {
            Color.clear
              .frame(height: topInset)

            ForEach(conversationMessages) { message in
              FocusMessageCard(
                message: message,
                isCurrentUser: message.author?.id == currentUser.id,
                isFocused: message.id == focusedMessageID
              )
              .id(message.id)
            }

            Color.clear
              .frame(height: bottomInset)
          }
          .padding(.horizontal, 16)
          .padding(.top, 18)
          .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .highPriorityGesture(
          DragGesture(minimumDistance: 18)
            .onEnded { value in
              let dy = value.translation.height
              guard abs(dy) > swipeThreshold else { return }

              if dy < 0 {
                moveFocus(delta: 1, proxy: proxy)
              } else {
                moveFocus(delta: -1, proxy: proxy)
              }
            }
        )
        .overlay(
          LinearGradient(
            colors: [
              Color.black.opacity(0.98),
              Color.black.opacity(0.46),
              Color.clear,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 80),
          alignment: .top
        )
        .overlay(
          LinearGradient(
            colors: [
              Color.clear,
              Color.black.opacity(0.50),
              Color.black.opacity(0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 80),
          alignment: .bottom
        )
        .onAppear {
          forceFocusToLatest()
          lastAnnouncedMessageID = nil

          centerFocused(proxy: proxy, animated: false)

          if let last = conversationMessages.last {
            announce(message: last)
            lastAnnouncedMessageID = last.id
          }
        }
        .onChange(of: focusedMessageID) { _, newValue in
          guard let id = newValue else { return }

          centerFocused(proxy: proxy, animated: true)

          guard id != lastAnnouncedMessageID else { return }
          guard let message = conversationMessages.first(where: { $0.id == id }) else { return }

          lastAnnouncedMessageID = id
          announce(message: message)
        }
        .onChange(of: conversationMessages.count) { _, _ in
          forceFocusToLatest()
          centerFocused(proxy: proxy, animated: true)
        }
        .onChange(of: messageIdentitySignature) { _, _ in
          forceFocusToLatest()
          centerFocused(proxy: proxy, animated: true)
        }
      }
    }
  }

  private func moveFocus(delta: Int, proxy: ScrollViewProxy) {
    guard !conversationMessages.isEmpty else { return }

    let currentIndex =
      conversationMessages.firstIndex(where: { $0.id == focusedMessageID })
      ?? max(conversationMessages.count - 1, 0)

    let newIndex = min(max(currentIndex + delta, 0), conversationMessages.count - 1)
    let newID = conversationMessages[newIndex].id

    guard newID != focusedMessageID else { return }
    focusedMessageID = newID
  }

  private func centerFocused(proxy: ScrollViewProxy, animated: Bool) {
    guard let id = focusedMessageID,
      conversationMessages.contains(where: { $0.id == id })
    else {
      return
    }

    if animated {
      withAnimation(.snappy(duration: 0.22)) {
        proxy.scrollTo(id, anchor: .center)
      }
    } else {
      proxy.scrollTo(id, anchor: .center)
    }
  }

  private func announce(message: Message) {
    let senderName = (message.author?.id == currentUser.id) ? "You" : "Friend"

    let body = message.text.isEmpty ? "Empty message" : message.text
    let spoken = "\(senderName) said \(body)"

    BraillePlaybackEngine.shared.readMessage(
      spoken,
      brailleEnabled: appState.isBrailleModeActive
    )
  }

  private func forceFocusToLatest() {
    focusedMessageID = conversationMessages.last?.id
  }

  private var header: some View {
    HStack(spacing: 12) {

      Button {
        BraillePlaybackEngine.shared.stopAllOutput()
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(mintGreen)
          .frame(width: 40, height: 40)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white.opacity(0.07))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.14), lineWidth: 1)
          )
      }
      .vibcomAccessible(
        label: "Back button.",
        hint: "Go back to your list of conversations."
      )

      UserAvatarView(user: friend, size: 40)
        .vibcomAccessible(
          label: "Profile picture for \(friendDisplayLabel).",
          hint: "This is your friend's avatar."
        )

      VStack(alignment: .leading, spacing: 2) {
        Text(friendDisplayLabel)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.white)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: displayedFriendStatus))
            .frame(width: 8, height: 8)

          Text(PresenceStyle.text(for: displayedFriendStatus))
            .font(.caption.weight(.semibold))
            .foregroundStyle(PresenceStyle.color(for: displayedFriendStatus).opacity(0.98))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.10))
        )
      }
      .vibcomAccessible(
        label:
          "Conversation with \(friendDisplayLabel). Status \(PresenceStyle.text(for: displayedFriendStatus)).",
        hint: "You are currently viewing this chat."
      )

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 10)
    .padding(.bottom, 12)
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.94), Color.black.opacity(0.78)],
        startPoint: .top,
        endPoint: .bottom
      )
      .overlay(
        Rectangle()
          .fill(Color.white.opacity(0.12))
          .frame(height: 1),
        alignment: .bottom
      )
    )
  }

  private var inputBar: some View {
    HStack(spacing: 8) {

      HStack {
        TextField("Enter a message", text: $inputText, axis: .vertical)
          .textFieldStyle(.plain)
          .foregroundColor(.white)
          .textInputAutocapitalization(.sentences)
          .autocorrectionDisabled(false)
          .lineLimit(1...3)
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
      }
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white.opacity(0.08))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.white.opacity(0.18), lineWidth: 1)
      )

      Button(action: sendMessage) {
        Image(systemName: "paperplane.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.black)
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 14)
              .fill(
                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  ? Color.white.opacity(0.30)
                  : mintGreen
              )
          )
      }
      .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.84), Color.black.opacity(0.98)],
        startPoint: .top,
        endPoint: .bottom
      )
      .overlay(
        Rectangle()
          .fill(Color.white.opacity(0.10))
          .frame(height: 1),
        alignment: .top
      )
      .ignoresSafeArea(edges: .bottom)
    )
  }

  private var brailleInputArea: some View {
    VStack(spacing: 0) {
      GestureBrailleInputView(
        text: $inputText,
        onSend: sendMessage
      )
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 10)
    }
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.82), Color.black],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea(edges: .bottom)
    )
  }

  private func ensureConversation() {
    let matchingConversations = allConversations.filter { conv in
      let ids = conv.participants.map { $0.id }
      return ids.count == 2 && ids.contains(currentUser.id) && ids.contains(friend.id)
    }

    if let canonical = canonicalConversation(from: matchingConversations) {
      conversation = canonical
      return
    }

    let chatTitle = "\(currentUser.username) & \(friend.username)"

    let newConv = Conversation(
      title: chatTitle,
      participants: [currentUser, friend]
    )

    modelContext.insert(newConv)
    do {
      try modelContext.save()
      conversation = newConv
    } catch {
      print("Failed to create conversation: \(error)")
    }
  }

  private func canonicalConversation(from candidates: [Conversation]) -> Conversation? {
    candidates.max { lhs, rhs in
      let lhsLastMessageDate = latestMessageDate(for: lhs)
      let rhsLastMessageDate = latestMessageDate(for: rhs)

      switch (lhsLastMessageDate, rhsLastMessageDate) {
      case (let left?, let right?):
        return left < right
      case (.some, .none):
        return false
      case (.none, .some):
        return true
      case (.none, .none):
        return lhs.updatedAt < rhs.updatedAt
      }
    }
  }

  private func latestMessageDate(for conversation: Conversation) -> Date? {
    allMessages
      .filter { $0.conversation?.id == conversation.id }
      .map(\.createdAt)
      .max()
  }

  private func sendMessage() {
    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard conversation != nil else { return }

    let participants = [currentUser.username, friend.username]
    let authorUsername = currentUser.username
    let createdAt = Date()
    inputText = ""

    Task(priority: .userInitiated) {
      await persistMessageToCloud(
        participants: participants,
        authorUsername: authorUsername,
        text: trimmed,
        createdAt: createdAt
      )
    }
  }

  @MainActor
  private func syncConversationFromCloud() async {
    guard Auth.auth().currentUser != nil else { return }
    guard let conv = conversation else { return }

    do {
      let participants = [currentUser.username, friend.username]
      log(
        "sync start conv=\(conv.id.uuidString) participants=\(participants) authUID=\(Auth.auth().currentUser?.uid ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil")"
      )
      let remoteMessages = try await FirestoreChatStore.shared.fetchMessages(
        participants: participants)
      log("sync success conv=\(conv.id.uuidString) remoteCount=\(remoteMessages.count)")
      applyAuthoritativeRemoteMessages(remoteMessages, to: conv)
    } catch {
      log(
        "sync failed participants=\([currentUser.username, friend.username]) authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") error=\(error)"
      )
    }
  }

  private func startRealtimeListeners() {
    guard Auth.auth().currentUser != nil else { return }
    stopRealtimeListeners()

    let participants = [currentUser.username, friend.username]
    log(
      "start message listener participants=\(participants) authUID=\(Auth.auth().currentUser?.uid ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil")"
    )
    messageListener = FirestoreChatStore.shared.listenForMessages(participants: participants) {
      result in
      DispatchQueue.main.async {
        switch result {
        case .success(let remoteMessages):
          log(
            "message listener success participants=\(participants) remoteCount=\(remoteMessages.count)"
          )
          mergeRemoteMessages(remoteMessages)
        case .failure(let error):
          log(
            "message listener failed participants=\(participants) authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") error=\(error)"
          )
        }
      }
    }

    presenceListeners = FirebaseUserStore.shared.listenToUsersByPhoneE164([friend.username]) {
      result in
      DispatchQueue.main.async {
        switch result {
        case .success(let remoteUsers):
          guard let remote = remoteUsers.first else { return }
          let preferredName = PhoneDisplayLabel.resolvedName(
            displayName: remote.displayName,
            username: remote.phoneE164
          )
          if friend.displayName != preferredName {
            friend.displayName = preferredName
          }
          if friend.presence != remote.presenceStatus {
            friend.presence = remote.presenceStatus
          }
          try? modelContext.save()
        case .failure(let error):
          print("Failed to listen for friend presence: \(error)")
        }
      }
    }
  }

  private func startBootstrapSyncWindow() {
    bootstrapSyncTask?.cancel()
    log("bootstrap sync start participants=\([currentUser.username, friend.username])")
    bootstrapSyncTask = Task(priority: .utility) {
      let delays: [UInt64] = [250_000_000, 700_000_000, 1_400_000_000]

      for delay in delays {
        try? await Task.sleep(nanoseconds: delay)
        guard Task.isCancelled == false else { return }
        log("bootstrap sync firing delayNs=\(delay)")
        await syncConversationFromCloud()
      }
    }
  }

  private func startCloudSyncWhenAuthenticated() {
    authBootstrapTask?.cancel()
    authBootstrapTask = Task(priority: .utility) {
      for attempt in 0..<20 {
        if let authUser = Auth.auth().currentUser {
          log(
            "auth ready for chat attempt=\(attempt) uid=\(authUser.uid) phone=\(authUser.phoneNumber ?? "nil") participants=\([currentUser.username, friend.username])"
          )
          await syncConversationFromCloud()
          await MainActor.run {
            startRealtimeListeners()
            startBootstrapSyncWindow()
          }
          return
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
      }
      log(
        "auth never became ready for chat participants=\([currentUser.username, friend.username])")
    }
  }

  private func stopRealtimeListeners() {
    messageListener?.remove()
    messageListener = nil
    for listener in presenceListeners {
      listener.remove()
    }
    presenceListeners.removeAll()
  }

  private func mergeRemoteMessages(_ remoteMessages: [RemoteChatMessage]) {
    guard let conv = conversation else { return }
    applyAuthoritativeRemoteMessages(remoteMessages, to: conv)
  }

  private func reloadConversationMessagesFromLocal() {
    guard let conversationID = conversation?.id else {
      conversationMessages = []
      return
    }

    do {
      var descriptor = FetchDescriptor<Message>(
        predicate: #Predicate { message in
          message.conversation?.id == conversationID
        },
        sortBy: [SortDescriptor(\Message.createdAt, order: .forward)]
      )
      descriptor.includePendingChanges = true
      conversationMessages = try modelContext.fetch(descriptor)
    } catch {
      print("Failed to reload local conversation messages: \(error)")
      conversationMessages =
        allMessages
        .filter { $0.conversation?.id == conversationID }
        .sorted { $0.createdAt < $1.createdAt }
    }
  }

  private func persistMessageToCloud(
    participants: [String],
    authorUsername: String,
    text: String,
    createdAt: Date
  ) async {
    guard Auth.auth().currentUser != nil else { return }
    do {
      log(
        "send start participants=\(participants) author=\(authorUsername) createdAt=\(createdAt.timeIntervalSince1970) text=\(text)"
      )
      try await FirestoreChatStore.shared.sendMessage(
        participants: participants,
        authorUsername: authorUsername,
        text: text,
        createdAt: createdAt
      )
      log("send success participants=\(participants) createdAt=\(createdAt.timeIntervalSince1970)")
      await syncConversationFromCloud()
    } catch {
      log(
        "send failed participants=\(participants) authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") error=\(error)"
      )
      await MainActor.run {
        if inputText.isEmpty {
          inputText = text
        }
      }
    }
  }

  private func applyAuthoritativeRemoteMessages(
    _ remoteMessages: [RemoteChatMessage], to conv: Conversation
  ) {
    let canonicalRemoteMessages = Self.uniqueRemoteMessages(remoteMessages)
    let remoteSignatures = canonicalRemoteMessages.map(Self.messageSignature)
    let remoteSignatureSet = Set(remoteSignatures)

    let localMessages =
      allMessages
      .filter { $0.conversation?.id == conv.id }
      .sorted { $0.createdAt < $1.createdAt }
    let localGroups = Dictionary(grouping: localMessages, by: Self.messageSignature)

    var didChange = false

    for (signature, messages) in localGroups {
      if remoteSignatureSet.contains(signature) == false {
        messages.forEach(modelContext.delete)
        didChange = true
        continue
      }

      if messages.count > 1 {
        for duplicate in messages.dropFirst() {
          modelContext.delete(duplicate)
          didChange = true
        }
      }
    }

    let survivingLocalSignatures = Set(
      localGroups.compactMap { signature, messages in
        remoteSignatureSet.contains(signature) && messages.isEmpty == false ? signature : nil
      }
    )

    for remoteMessage in canonicalRemoteMessages
    where survivingLocalSignatures.contains(Self.messageSignature(remoteMessage)) == false {
      let normalizedAuthor = FirestoreChatStore.canonicalUsername(remoteMessage.authorUsername)
      let author = authorForNormalizedUsername(normalizedAuthor)

      let restored = Message(
        text: remoteMessage.text,
        createdAt: remoteMessage.createdAt,
        isIncoming: normalizedAuthor != FirestoreChatStore.canonicalUsername(currentUser.username),
        brailleEncoded: nil,
        seenByOtherUser: false,
        conversation: conv,
        author: author
      )
      modelContext.insert(restored)
      didChange = true
    }

    let latestRemoteDate = canonicalRemoteMessages.last?.createdAt ?? conv.createdAt
    if conv.updatedAt != latestRemoteDate {
      conv.updatedAt = latestRemoteDate
      didChange = true
    }

    if didChange {
      try? modelContext.save()
    }

    reloadConversationMessagesFromLocal()
  }

  private func authorForNormalizedUsername(_ normalizedAuthor: String) -> VibcomUser? {
    let normalizedCurrent = FirestoreChatStore.canonicalUsername(currentUser.username)
    let normalizedFriend = FirestoreChatStore.canonicalUsername(friend.username)

    if normalizedAuthor == normalizedCurrent {
      return currentUser
    } else if normalizedAuthor == normalizedFriend {
      return friend
    } else {
      return nil
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

  private static func messageSignature(_ remoteMessage: RemoteChatMessage) -> String {
    messageSignature(
      text: remoteMessage.text,
      createdAt: remoteMessage.createdAt,
      normalizedAuthor: FirestoreChatStore.canonicalUsername(remoteMessage.authorUsername)
    )
  }

  private static func uniqueRemoteMessages(_ remoteMessages: [RemoteChatMessage])
    -> [RemoteChatMessage]
  {
    var seen: Set<String> = []
    var unique: [RemoteChatMessage] = []

    for remoteMessage in remoteMessages.sorted(by: { $0.createdAt < $1.createdAt }) {
      let signature = messageSignature(remoteMessage)
      guard seen.insert(signature).inserted else { continue }
      unique.append(remoteMessage)
    }

    return unique
  }
}
