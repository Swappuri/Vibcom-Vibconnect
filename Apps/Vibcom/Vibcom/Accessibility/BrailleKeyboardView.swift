//
//  BrailleKeyboardView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/26/25.
//

import SwiftUI
import UIKit

struct BrailleKeyboardView: View {

  @EnvironmentObject private var appState: AppState

  @Binding var text: String
  let onSend: () -> Void

  @State private var pattern: [Bool?] = Array(repeating: nil, count: 6)
  @State private var currentIndex: Int = 0

  private var mintGreen: Color { Color("MintGreen") }

  private var canSend: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 10) {

      Text(text.isEmpty ? "Enter a braille message…" : text)
        .font(.body)
        .foregroundColor(text.isEmpty ? .white.opacity(0.5) : .white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(mintGreen, lineWidth: 2)
        )
        .onTapGesture {
          if text.isEmpty {
            read("No text yet. Your message is empty.")
          } else {
            read("Current message: \(text)")
          }
        }

      HStack(spacing: 8) {
        ForEach(0..<6, id: \.self) { idx in
          Capsule()
            .stroke(mintGreen, lineWidth: 2)
            .background(
              Capsule()
                .fill(fillColor(for: pattern[idx]))
            )
            .frame(height: 12)
        }
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .onTapGesture {
        let filledCount = pattern.filter { $0 != nil }.count
        read("Current dots entered: \(filledCount)")
      }

      HStack(spacing: 16) {
        brailleChoiceButton(isRaised: true)
        brailleChoiceButton(isRaised: false)
      }

      HStack(spacing: 10) {

        smallIconButton(systemName: "arrow.clockwise") {
          playImpact(style: .rigid)
          read("Clear current cell")
          resetCurrentLetter()
        }

        Button {
          text.append(" ")
          playImpact(style: .medium)
          read("Space")
        } label: {
          Text("Space")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
        }
        .buttonStyle(FilledMintButtonStyle(mintGreen: mintGreen))

        smallIconButton(systemName: "delete.left") {
          guard !text.isEmpty else { return }
          text.removeLast()
          playNotification(type: .warning)
          read("Delete")
        }

        smallIconButton(systemName: "paperplane.fill") {
          guard canSend else { return }
          onSend()
          playNotification(type: .success)
          read("Send message")
        }
        .disabled(!canSend)
        .opacity(canSend ? 1.0 : 0.4)
      }
    }
    .padding(12)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(mintGreen, lineWidth: 2)
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
    .background(Color.black)
    .accessibilityHidden(true)
  }

  private func fillColor(for value: Bool?) -> Color {
    switch value {
    case .some(true):
      return mintGreen
    case .some(false):
      return mintGreen.opacity(0.25)
    case .none:
      return .clear
    }
  }

  private func brailleChoiceButton(isRaised: Bool) -> some View {
    Button {
      handleDotChoice(isRaised: isRaised)
    } label: {
      VStack(spacing: 6) {
        Circle()
          .stroke(mintGreen, lineWidth: 2)
          .background(
            Circle()
              .fill(isRaised ? mintGreen : .clear)
          )
          .frame(width: 40, height: 40)

        Text(isRaised ? "Raised Dot" : "Flat Dot")
          .font(.caption)
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity)
      .padding(8)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(mintGreen, lineWidth: 2)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func smallIconButton(systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.black)
        .frame(width: 32, height: 32)
        .background(mintGreen)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private func handleDotChoice(isRaised: Bool) {
    playImpact(style: isRaised ? .heavy : .light)

    read(isRaised ? "Raised dot" : "Flat dot")

    guard currentIndex < 6 else { return }
    pattern[currentIndex] = isRaised

    if currentIndex == 5 {
      commitLetter()
    } else {
      currentIndex += 1
    }
  }

  private func resetCurrentLetter() {
    pattern = Array(repeating: nil, count: 6)
    currentIndex = 0
  }

  private func commitLetter() {
    let raisedDots: Set<Int> = Set(
      pattern.enumerated()
        .compactMap { (idx, value) in
          value == true ? idx + 1 : nil
        }
    )

    if let char = brailleCharacter(for: raisedDots) {
      text.append(char)
      read(String(char))
    }

    resetCurrentLetter()
  }

  private func brailleCharacter(for dots: Set<Int>) -> Character? {
    switch Array(dots).sorted() {
    case [1]: return "a"
    case [1, 2]: return "b"
    case [1, 4]: return "c"
    case [1, 4, 5]: return "d"
    case [1, 5]: return "e"
    case [1, 2, 4]: return "f"
    case [1, 2, 4, 5]: return "g"
    case [1, 2, 5]: return "h"
    case [2, 4]: return "i"
    case [2, 4, 5]: return "j"
    case [1, 3]: return "k"
    case [1, 2, 3]: return "l"
    case [1, 3, 4]: return "m"
    case [1, 3, 4, 5]: return "n"
    case [1, 3, 5]: return "o"
    case [1, 2, 3, 4]: return "p"
    case [1, 2, 3, 4, 5]: return "q"
    case [1, 2, 3, 5]: return "r"
    case [2, 3, 4]: return "s"
    case [2, 3, 4, 5]: return "t"
    case [1, 3, 6]: return "u"
    case [1, 2, 3, 6]: return "v"
    case [2, 4, 5, 6]: return "w"
    case [1, 3, 4, 6]: return "x"
    case [1, 3, 4, 5, 6]: return "y"
    case [1, 3, 5, 6]: return "z"
    default:
      return nil
    }
  }

  private func read(_ message: String) {
    BraillePlaybackEngine.shared.readMessage(
      message,
      brailleEnabled: appState.isBrailleModeActive
    )
  }

  private func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
  }

  private func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(type)
  }
}

private struct FilledMintButtonStyle: ButtonStyle {
  let mintGreen: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.black)
      .background(mintGreen.opacity(configuration.isPressed ? 0.7 : 1.0))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
