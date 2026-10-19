//
//  VibcomApp.swift
//  Vibcom
//

import SwiftData
import SwiftUI

@main
struct VibcomApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  private var modelContainer: ModelContainer = {
    do {
      let storeURL: URL = {
        let fileManager = FileManager.default
        let baseURL =
          fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedIdentityStore.appGroupIdentifier)
          ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportURL = baseURL.appendingPathComponent(
          "Library/Application Support", isDirectory: true)
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        return appSupportURL.appendingPathComponent("default.store")
      }()

      let configuration = ModelConfiguration(url: storeURL)
      return try ModelContainer(
        for: VibcomUser.self,
        Conversation.self,
        Message.self,
        AccessibilitySettings.self,
        Friendship.self,
        configurations: configuration
      )
    } catch {
      fatalError("❌ Failed to create ModelContainer: \(error)")
    }
  }()

  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(appState)
    }
    .modelContainer(modelContainer)
  }
}
