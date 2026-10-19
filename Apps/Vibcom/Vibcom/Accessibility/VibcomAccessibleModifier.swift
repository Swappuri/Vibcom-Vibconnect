//
//  VibcomAccessibleModifier.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/30/25.
//

import SwiftUI

struct VibcomAccessibleModifier: ViewModifier {

  @EnvironmentObject private var appState: AppState

  let label: String
  let hint: String?

  func body(content: Content) -> some View {
    content
      .contentShape(Rectangle())
      .simultaneousGesture(
        TapGesture()
          .onEnded {
            guard appState.isBrailleModeActive else { return }

            let phrase: String
            if let hint, !hint.isEmpty {
              phrase = "\(label). \(hint)"
            } else {
              phrase = label
            }

            BraillePlaybackEngine.shared.readMessage(
              phrase,
              brailleEnabled: true
            )
          }
      )
  }
}

extension View {
  func vibcomAccessible(label: String, hint: String? = nil) -> some View {
    self.modifier(VibcomAccessibleModifier(label: label, hint: hint))
  }
}
