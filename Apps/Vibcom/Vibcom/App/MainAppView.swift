//
//  MainAppView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import SwiftData
import SwiftUI

struct MainAppView: View {

  @EnvironmentObject private var appState: AppState
  let currentUser: VibcomUser

  var body: some View {
    MessagesHomeView(currentUser: currentUser)
  }
}
