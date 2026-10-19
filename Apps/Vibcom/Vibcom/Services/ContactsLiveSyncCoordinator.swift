//
//  ContactsLiveSyncCoordinator.swift
//  Vibcom
//

import Contacts
import Foundation
import SwiftData

@MainActor
final class ContactsLiveSyncCoordinator {

  static let shared = ContactsLiveSyncCoordinator()

  private var observer: NSObjectProtocol?
  private var debounceTask: Task<Void, Never>?
  private var activeUserID: UUID?
  private var activeContext: ModelContext?
  private var isSyncInFlight = false
  private var shouldRunAgain = false

  private init() {}

  func start(currentUser: VibcomUser, modelContext: ModelContext) {
    activeUserID = currentUser.id
    activeContext = modelContext
    installObserverIfNeeded()
    scheduleSync(delayNanoseconds: 250_000_000)
  }

  func stop() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
    debounceTask?.cancel()
    debounceTask = nil
    activeUserID = nil
    activeContext = nil
    isSyncInFlight = false
    shouldRunAgain = false
  }

  func triggerNow() {
    scheduleSync(delayNanoseconds: 0)
  }

  private func installObserverIfNeeded() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: .CNContactStoreDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        self.scheduleSync(delayNanoseconds: 700_000_000)
      }
    }
  }

  private func scheduleSync(delayNanoseconds: UInt64) {
    debounceTask?.cancel()
    debounceTask = Task { [weak self] in
      guard let self else { return }
      if delayNanoseconds > 0 {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
      }
      await self.runSyncCycle()
    }
  }

  private func runSyncCycle() async {
    guard let context = activeContext, let userID = activeUserID else { return }

    if isSyncInFlight {
      shouldRunAgain = true
      return
    }
    isSyncInFlight = true
    defer {
      isSyncInFlight = false
    }

    do {
      var descriptor = FetchDescriptor<VibcomUser>(
        predicate: #Predicate { user in
          user.id == userID
        }
      )
      descriptor.fetchLimit = 1
      guard let currentUser = try context.fetch(descriptor).first else { return }

      try await ContactsSyncService.shared.syncContactsIntoLocalChats(for: currentUser, in: context)
    } catch {
      print("Live contacts sync failed: \(error)")
    }

    if shouldRunAgain {
      shouldRunAgain = false
      scheduleSync(delayNanoseconds: 350_000_000)
    }
  }
}
