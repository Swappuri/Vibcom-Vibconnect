//
//  BrailleInputView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/26/25.
//

import SwiftUI

struct BrailleInputView: View {

  @State private var dots: [Bool] = Array(repeating: false, count: 6)
  @State private var feedbackMessage: String?

  let onCharacter: (Character) -> Void
  let onBackspace: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 24) {
        dotColumn(indices: [0, 1, 2])
        dotColumn(indices: [3, 4, 5])
      }

      if let feedbackMessage {
        Text(feedbackMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 16) {
        Button(role: .destructive) {
          clearDots()
        } label: {
          Label("Clear", systemImage: "xmark.circle")
        }

        Button {
          handleBackspace()
        } label: {
          Label("Backspace", systemImage: "delete.left")
        }

        Button {
          commitCell()
        } label: {
          Label("Commit", systemImage: "arrow.down.square")
        }
        .buttonStyle(.borderedProminent)
      }
      .font(.callout)
    }
    .padding(.vertical, 8)
  }

  private func dotColumn(indices: [Int]) -> some View {
    VStack(spacing: 16) {
      ForEach(indices, id: \.self) { i in
        dotButton(index: i)
      }
    }
  }

  private func dotButton(index: Int) -> some View {
    let isOn = dots[index]

    return Button {
      toggleDot(at: index)
    } label: {
      Circle()
        .strokeBorder(lineWidth: 2)
        .background(
          Circle()
            .fill(isOn ? Color.accentColor : Color.clear)
        )
        .frame(width: 44, height: 44)
        .overlay {
          Text("\(index + 1)")
            .font(.caption2)
            .foregroundStyle(isOn ? .white : .secondary)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Dot \(index + 1)")
    .accessibilityValue(isOn ? "On" : "Off")
  }

  private func toggleDot(at index: Int) {
    guard dots.indices.contains(index) else { return }
    dots[index].toggle()
    HapticsManager.shared.play(dots[index] ? .dotOn : .dotOff)
    feedbackMessage = nil
  }

  private func clearDots() {
    dots = Array(repeating: false, count: 6)
    feedbackMessage = "Cleared current cell."
  }

  private func handleBackspace() {
    onBackspace()
    HapticsManager.shared.play(.dotOff)
    feedbackMessage = "Deleted previous character."
  }

  private func commitCell() {
    guard let character = BrailleTranslator.character(forDots: dots) else {
      feedbackMessage = "Pattern not recognized."
      HapticsManager.shared.play(.commitFailure)
      return
    }

    onCharacter(character)
    clearDots()
    feedbackMessage = "Added '\(character)'."
    HapticsManager.shared.play(.commitSuccess)
  }
}
