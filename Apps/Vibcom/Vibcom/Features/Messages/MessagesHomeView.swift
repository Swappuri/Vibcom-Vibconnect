//
//  MessagesHomeView.swift
//  Vibcom
//

import FirebaseAuth
import FirebaseFirestore
import SwiftData
import SwiftUI

struct MessagesHomeView: View {

  @EnvironmentObject private var appState: AppState
  @Environment(\.modelContext) private var modelContext

  let currentUser: VibcomUser

  @State private var searchText: String = ""

  @State private var focusedIndex: Int = 0
  @State private var lastAnnouncedItemID: String?
  @State private var path = NavigationPath()

  @State private var chatItems: [ChatItem] = []
  @State private var remoteSummaryByFriendUsername: [String: RemoteConversationSummary] = [:]
  @State private var conversationSummariesListener: ListenerRegistration?
  @State private var userPresenceListeners: [ListenerRegistration] = []
  @State private var listenedFriendPhonesKey: String = ""
  @State private var authBootstrapTask: Task<Void, Never>?

  @Query private var allFriendships: [Friendship]
  @Query private var allConversations: [Conversation]
  @Query private var allMessages: [Message]
  @Query private var settingsRecords: [AccessibilitySettings]

  private var mintGreen: Color { Color("MintGreen") }

  private let cardHeight: CGFloat = 104
  private let swipeThreshold: CGFloat = 55

  private func log(_ message: String) {
    print("[MessagesHome] \(message)")
  }

  struct ChatItem: Identifiable, Equatable {
    let id: UUID
    let friend: VibcomUser
    let preview: String
    let lastDate: Date?
  }

  private enum HomeRow: Identifiable, Equatable {
    case chat(ChatItem)
    case signOut

    var id: String {
      switch self {
      case .chat(let item):
        return item.id.uuidString
      case .signOut:
        return "signout"
      }
    }
  }

  private var settings: AccessibilitySettings {
    if let existing = settingsRecords.first { return existing }
    let created = AccessibilitySettings()
    created.brailleModeEnabled = true
    modelContext.insert(created)
    try? modelContext.save()
    return created
  }

  private var filteredChatItems: [ChatItem] {
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return chatItems }
    return chatItems.filter {
      $0.friend.username.localizedCaseInsensitiveContains(q)
        || $0.friend.displayName.localizedCaseInsensitiveContains(q)
    }
  }

  private var displayedRows: [HomeRow] {
    var rows = filteredChatItems.map { HomeRow.chat($0) }
    rows.append(.signOut)
    return rows
  }

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        background

        VStack(alignment: .leading, spacing: 14) {
          header

          if !appState.isBrailleModeActive {
            searchBar
          }

          chatCarouselContainer
        }
        .padding(.horizontal, VibcomSpace.md)
        .padding(.top, VibcomSpace.xs)
        .padding(.bottom, VibcomSpace.sm)
      }
      .navigationBarHidden(true)
      .overlay(
        TwoFingerActivateCatcher {
          guard path.isEmpty else { return }
          activateFocusedRow()
        }
        .ignoresSafeArea()
      )
      .navigationDestination(for: UUID.self) { friendID in
        if let friend = chatItems.first(where: { $0.id == friendID })?.friend {
          ChatDetailView(currentUser: currentUser, friend: friend)
        } else {
          Text("Chat not found.")
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
      }
      .onAppear {
        appState.isBrailleModeActive = settings.brailleModeEnabled
        rebuildChatItems()
        clampFocusIntoRange(resetToTop: true)
        announceFocusedIfNeeded()
        startCloudSyncWhenAuthenticated()
      }
      .onChange(of: allFriendships.count) { _, _ in
        rebuildChatItems()
        clampFocusIntoRange()
        announceFocusedIfNeeded()
        startRealtimeListeners()
      }
      .onChange(of: allMessages.count) { _, _ in
        let focusedID = currentFocusedRowID
        rebuildChatItems()
        restoreFocus(to: focusedID)
        announceFocusedIfNeeded()
      }
      .onChange(of: searchText) { _, _ in
        clampFocusIntoRange(resetToTop: true)
        announceFocusedIfNeeded()
      }
      .onChange(of: appState.isBrailleModeActive) { _, newValue in
        settings.brailleModeEnabled = newValue
        try? modelContext.save()
        searchText = ""
        lastAnnouncedItemID = nil
        clampFocusIntoRange(resetToTop: true)
        if newValue == false {
          BraillePlaybackEngine.shared.stopAllOutput()
        }
      }
      .onChange(of: path.count) { _, newCount in
        guard newCount == 0 else { return }
        lastAnnouncedItemID = nil
        clampFocusIntoRange(resetToTop: true)
        announceFocusedIfNeeded()
      }
      .onDisappear {
        stopRealtimeListeners()
        authBootstrapTask?.cancel()
        authBootstrapTask = nil
      }
    }
  }

  // MARK: - Background

  private var background: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color.black, Color(red: 0.02, green: 0.07, blue: 0.06), Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      RadialGradient(
        colors: [mintGreen.opacity(0.18), .clear],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 460
      )
      .ignoresSafeArea()
      LinearGradient(
        colors: [Color.clear, Color.black.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    }
  }

  // MARK: - Header

  private var header: some View {
    VStack(spacing: 10) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Messages")
            .font(VibcomTypography.title)
            .foregroundColor(VibcomColor.textPrimary)
        }
        .vibcomAccessible(
          label: "Messages screen.",
          hint: "Shows your chats. Swipe up or down to change focus."
        )

        brailleModeToggle
          .frame(maxWidth: .infinity)
      }

      HStack {
        Text("Recent Chats")
          .font(VibcomTypography.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.72))
        Spacer()
        Text("\(filteredChatItems.count)")
          .font(VibcomTypography.caption.weight(.bold))
          .foregroundStyle(mintGreen.opacity(0.95))
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(mintGreen.opacity(0.16))
          )
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, VibcomSpace.xs)
    .padding(.bottom, VibcomSpace.xs)
    .background(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .stroke(mintGreen.opacity(0.10), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
  }

  private var searchBar: some View {
    AuthTextField(
      iconName: "magnifyingglass",
      placeholder: "Search chats",
      text: $searchText,
      keyboardType: .default,
      mintGreen: mintGreen
    )
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
    .overlay(
      RoundedRectangle(cornerRadius: VibcomRadius.md)
        .stroke(mintGreen.opacity(0.10), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
    .vibcomAccessible(
      label: "Search field",
      hint: "Double tap to search your chats."
    )
  }

  private var brailleModeToggle: some View {
    BrailleModeTogglePill(
      isOn: Binding(
        get: { appState.isBrailleModeActive },
        set: { setBrailleMode($0) }
      ),
      activeColor: mintGreen
    )
    .vibcomAccessible(
      label: "Braille mode toggle.",
      hint: "Swipe right to enable. Swipe left to disable."
    )
  }

  private func setBrailleMode(_ enabled: Bool) {
    guard appState.isBrailleModeActive != enabled else { return }
    appState.isBrailleModeActive = enabled
  }

  // MARK: - Carousel Container

  private var chatCarouselContainer: some View {
    ZStack {
      RoundedRectangle(cornerRadius: VibcomRadius.lg)
        .fill(
          LinearGradient(
            colors: [
              Color.white.opacity(0.12),
              mintGreen.opacity(0.06),
              Color.white.opacity(0.04),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: VibcomRadius.lg)
            .stroke(Color.white.opacity(0.16), lineWidth: VibcomStroke.normal)
        )
        .overlay(
          RoundedRectangle(cornerRadius: VibcomRadius.lg)
            .stroke(mintGreen.opacity(0.10), lineWidth: 1)
        )

      chatCarousel
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
    }
    .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Carousel

  private var chatCarousel: some View {
    GeometryReader { geo in
      let topBottomInset = max(12, (geo.size.height - cardHeight) / 2)

      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          LazyVStack(spacing: 14) {
            Color.clear.frame(height: topBottomInset)

            ForEach(Array(displayedRows.enumerated()), id: \.element.id) { idx, row in
              let isFocused = (idx == focusedIndex)

              switch row {
              case .chat(let item):
                FocusFriendChatCard(
                  friend: item.friend,
                  isFocused: isFocused,
                  preview: item.preview,
                  timestamp: item.lastDate
                )
                .id(row.id)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                  guard isFocused else { return }
                  BraillePlaybackEngine.shared.stopAllOutput()
                  path.append(item.id)
                }

              case .signOut:
                SignOutCard(isFocused: isFocused)
                  .id(row.id)
                  .padding(.horizontal, 8)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    guard isFocused else { return }
                    signOut()
                  }
              }
            }

            Color.clear.frame(height: topBottomInset)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
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
        .onAppear {
          centerFocused(proxy: proxy, animated: false)
        }
        .onChange(of: focusedIndex) { _, _ in
          centerFocused(proxy: proxy, animated: true)
          announceFocusedIfNeeded()
        }
        .onChange(of: searchText) { _, _ in
          centerFocused(proxy: proxy, animated: false)
        }
      }
    }
  }

  private struct SignOutCard: View {
    let isFocused: Bool

    var body: some View {
      HStack(spacing: 14) {
        Circle()
          .fill(Color.red.opacity(isFocused ? 0.95 : 0.20))
          .frame(width: 44, height: 44)
          .overlay(
            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.black.opacity(isFocused ? 0.85 : 0.60))
          )

        VStack(alignment: .leading, spacing: 6) {
          Text("Sign out")
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .lineLimit(1)

          Text("End this session and return to login.")
            .font(.subheadline)
            .foregroundColor(.white.opacity(isFocused ? 0.80 : 0.55))
            .lineLimit(1)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(Color.red.opacity(isFocused ? 0.92 : 0.32))
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity)
      .frame(height: 104)
      .background(
        RoundedRectangle(cornerRadius: 22)
          .fill(isFocused ? Color.white.opacity(0.07) : Color.white.opacity(0.03))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .stroke(
            isFocused ? Color.red.opacity(0.95) : Color.white.opacity(0.06),
            lineWidth: isFocused ? 2 : 1
          )
      )
      .shadow(
        color: .black.opacity(isFocused ? 0.35 : 0.0),
        radius: isFocused ? 18 : 0,
        x: 0,
        y: 10
      )
      .scaleEffect(isFocused ? 1.03 : 0.96)
      .opacity(isFocused ? 1.0 : 0.80)
      .animation(.snappy(duration: 0.22), value: isFocused)
    }
  }

  // MARK: - Focus helpers

  private var currentFocusedRowID: String? {
    guard focusedIndex >= 0 && focusedIndex < displayedRows.count else { return nil }
    return displayedRows[focusedIndex].id
  }

  private func moveFocus(delta: Int, proxy: ScrollViewProxy) {
    guard !displayedRows.isEmpty else { return }
    let newIndex = min(max(focusedIndex + delta, 0), displayedRows.count - 1)
    guard newIndex != focusedIndex else { return }
    focusedIndex = newIndex
  }

  private func activateFocusedRow() {
    guard focusedIndex >= 0 && focusedIndex < displayedRows.count else { return }
    let row = displayedRows[focusedIndex]
    switch row {
    case .chat(let item):
      BraillePlaybackEngine.shared.stopAllOutput()
      path.append(item.id)
    case .signOut:
      signOut()
    }
  }

  private func centerFocused(proxy: ScrollViewProxy, animated: Bool) {
    guard !displayedRows.isEmpty else { return }
    guard focusedIndex >= 0 && focusedIndex < displayedRows.count else { return }
    let id = displayedRows[focusedIndex].id

    if animated {
      withAnimation(.snappy(duration: 0.22)) {
        proxy.scrollTo(id, anchor: .center)
      }
    } else {
      proxy.scrollTo(id, anchor: .center)
    }
  }

  private func clampFocusIntoRange(resetToTop: Bool = false) {
    if displayedRows.isEmpty {
      focusedIndex = 0
      return
    }
    if resetToTop {
      focusedIndex = 0
      return
    }
    focusedIndex = min(max(focusedIndex, 0), displayedRows.count - 1)
  }

  private func restoreFocus(to rowID: String?) {
    guard let rowID else {
      clampFocusIntoRange(resetToTop: true)
      return
    }
    if let idx = displayedRows.firstIndex(where: { $0.id == rowID }) {
      focusedIndex = idx
    } else {
      clampFocusIntoRange(resetToTop: true)
    }
  }

  private func announceFocusedIfNeeded() {
    guard focusedIndex >= 0 && focusedIndex < displayedRows.count else { return }
    let row = displayedRows[focusedIndex]
    guard row.id != lastAnnouncedItemID else { return }
    lastAnnouncedItemID = row.id

    switch row {
    case .chat(let item):
      let label = PhoneDisplayLabel.resolvedName(
        displayName: item.friend.displayName,
        username: item.friend.username
      )
      BraillePlaybackEngine.shared.readMessage(
        "Chat with \(label)",
        brailleEnabled: appState.isBrailleModeActive
      )
    case .signOut:
      BraillePlaybackEngine.shared.readMessage(
        "Sign out",
        brailleEnabled: appState.isBrailleModeActive
      )
    }
  }

  // MARK: - Data building

  private func rebuildChatItems() {
    let accepted = allFriendships.filter { f in
      f.isAccepted && (f.fromUser.id == currentUser.id || f.toUser.id == currentUser.id)
    }

    var friends: [VibcomUser] = []
    for f in accepted {
      let friend = (f.fromUser.id == currentUser.id) ? f.toUser : f.fromUser
      if friends.contains(where: { $0.id == friend.id }) == false {
        friends.append(friend)
      }
    }

    var items: [ChatItem] = []
    items.reserveCapacity(friends.count)

    let relevantConversations = allConversations.filter { conversation in
      let participantIDs = conversation.participants.map(\.id)
      return participantIDs.count == 2 && participantIDs.contains(currentUser.id)
    }

    let conversationByFriendID: [UUID: Conversation] = Dictionary(
      uniqueKeysWithValues: relevantConversations.compactMap { conversation in
        guard let other = conversation.participants.first(where: { $0.id != currentUser.id }) else {
          return nil
        }
        return (other.id, conversation)
      }
    )

    let relevantConversationIDs = Set(relevantConversations.map(\.id))
    var latestLocalMessageByConversationID: [UUID: Message] = [:]
    for message in allMessages {
      guard let conversationID = message.conversation?.id else { continue }
      guard relevantConversationIDs.contains(conversationID) else { continue }

      if let existing = latestLocalMessageByConversationID[conversationID] {
        if existing.createdAt < message.createdAt {
          latestLocalMessageByConversationID[conversationID] = message
        }
      } else {
        latestLocalMessageByConversationID[conversationID] = message
      }
    }

    for friend in friends {
      let localConversation = conversationByFriendID[friend.id]
      let localLatestMessage = localConversation.flatMap {
        latestLocalMessageByConversationID[$0.id]
      }
      let localDate = localLatestMessage?.createdAt
      let localPreview =
        localLatestMessage.map { $0.text.isEmpty ? "Empty message" : $0.text } ?? "No messages yet"
      let canonicalFriendUsername = FirestoreChatStore.canonicalUsername(friend.username)
      if let remoteSummary = remoteSummaryByFriendUsername[canonicalFriendUsername],
        let lastMessageAt = remoteSummary.lastMessageAt
      {
        let remotePreviewText: String
        if let lastMessageText = remoteSummary.lastMessageText {
          remotePreviewText = lastMessageText.isEmpty ? "Empty message" : lastMessageText
        } else {
          remotePreviewText = "No messages yet"
        }

        if let localDate, localDate > lastMessageAt {
          items.append(
            ChatItem(id: friend.id, friend: friend, preview: localPreview, lastDate: localDate))
        } else {
          items.append(
            ChatItem(
              id: friend.id, friend: friend, preview: remotePreviewText, lastDate: lastMessageAt))
        }
        continue
      }

      items.append(
        ChatItem(id: friend.id, friend: friend, preview: localPreview, lastDate: localDate))
    }

    items.sort { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
    chatItems = items
  }

  @MainActor
  private func syncRemoteConversationSummaries() async {
    guard Auth.auth().currentUser != nil else { return }
    do {
      log(
        "sync summaries start localUser=\(currentUser.username) authUID=\(Auth.auth().currentUser?.uid ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil")"
      )
      let summaries = try await FirestoreChatStore.shared.fetchConversationSummaries(
        for: currentUser.username)
      applyConversationSummaries(summaries)
    } catch {
      log(
        "sync summaries failed localUser=\(currentUser.username) authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") error=\(error)"
      )
    }
  }

  private func startRealtimeListeners() {
    guard Auth.auth().currentUser != nil else { return }
    if conversationSummariesListener == nil {
      log(
        "start summary listener localUser=\(currentUser.username) authUID=\(Auth.auth().currentUser?.uid ?? "nil") authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil")"
      )
      conversationSummariesListener = FirestoreChatStore.shared.listenForConversationSummaries(
        for: currentUser.username
      ) { result in
        DispatchQueue.main.async {
          switch result {
          case .success(let summaries):
            log(
              "summary listener success count=\(summaries.count) localUser=\(currentUser.username)")
            applyConversationSummaries(summaries)
          case .failure(let error):
            log(
              "summary listener failed localUser=\(currentUser.username) authPhone=\(Auth.auth().currentUser?.phoneNumber ?? "nil") error=\(error)"
            )
          }
        }
      }
    }

    let accepted = allFriendships.filter {
      $0.isAccepted && ($0.fromUser.id == currentUser.id || $0.toUser.id == currentUser.id)
    }
    let friendPhones =
      accepted
      .map { ($0.fromUser.id == currentUser.id) ? $0.toUser.username : $0.fromUser.username }
      .sorted()
    let phonesKey = friendPhones.joined(separator: "|")

    guard phonesKey != listenedFriendPhonesKey else { return }

    for listener in userPresenceListeners {
      listener.remove()
    }
    userPresenceListeners.removeAll()
    listenedFriendPhonesKey = phonesKey

    userPresenceListeners = FirebaseUserStore.shared.listenToUsersByPhoneE164(friendPhones) {
      result in
      DispatchQueue.main.async {
        switch result {
        case .success(let remoteUsers):
          applyRemotePresence(remoteUsers)
        case .failure(let error):
          print("Failed to listen for remote presence: \(error)")
        }
      }
    }
  }

  private func startCloudSyncWhenAuthenticated() {
    authBootstrapTask?.cancel()
    authBootstrapTask = Task(priority: .utility) {
      for attempt in 0..<20 {
        if let authUser = Auth.auth().currentUser {
          log(
            "auth ready for summaries attempt=\(attempt) uid=\(authUser.uid) phone=\(authUser.phoneNumber ?? "nil") localUser=\(currentUser.username)"
          )
          await syncRemoteConversationSummaries()
          await MainActor.run {
            startRealtimeListeners()
          }
          return
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
      }
      log("auth never became ready for summaries localUser=\(currentUser.username)")
    }
  }

  private func stopRealtimeListeners() {
    conversationSummariesListener?.remove()
    conversationSummariesListener = nil
    for listener in userPresenceListeners {
      listener.remove()
    }
    userPresenceListeners.removeAll()
    listenedFriendPhonesKey = ""
  }

  private func applyConversationSummaries(_ summaries: [RemoteConversationSummary]) {
    let me = FirestoreChatStore.canonicalUsername(currentUser.username)
    var mapped: [String: RemoteConversationSummary] = [:]

    for summary in summaries {
      if let friendUsername = summary.participants.first(where: { $0 != me }) {
        mapped[friendUsername] = summary
      }
    }

    remoteSummaryByFriendUsername = mapped
    rebuildChatItems()
    clampFocusIntoRange()
    announceFocusedIfNeeded()
  }

  private func applyRemotePresence(_ remoteUsers: [VibcomRemoteUser]) {
    var didChange = false

    for remoteUser in remoteUsers {
      let normalizedPhone = FirestoreChatStore.canonicalUsername(remoteUser.phoneE164)
      for friendship in allFriendships where friendship.isAccepted {
        let friend =
          (friendship.fromUser.id == currentUser.id) ? friendship.toUser : friendship.fromUser
        guard FirestoreChatStore.canonicalUsername(friend.username) == normalizedPhone else {
          continue
        }

        let preferredName = PhoneDisplayLabel.resolvedName(
          displayName: remoteUser.displayName,
          username: remoteUser.phoneE164
        )

        if friend.displayName != preferredName {
          friend.displayName = preferredName
          didChange = true
        }

        if friend.presence != remoteUser.presenceStatus {
          friend.presence = remoteUser.presenceStatus
          didChange = true
        }
      }
    }

    if didChange {
      try? modelContext.save()
      rebuildChatItems()
    }
  }

  // MARK: - Sign out

  private func signOut() {
    do {
      try Auth.auth().signOut()
    } catch {
      print("Firebase sign out failed: \(error)")
    }
    appState.logout()
  }
}
