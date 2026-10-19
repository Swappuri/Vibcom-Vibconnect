//
//  GestureNumericInputView.swift
//  Vibcom
//

import SwiftUI
import UIKit

struct GestureNumericInputView: View {

  @Binding var digits: String

  let primaryActionLabel: String
  let onPrimaryAction: () -> Void
  var horizontalPadding: CGFloat = 16

  @State private var dots: [Bool] = []
  private let maxDots = 6

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    VStack(spacing: 10) {
      Text(primaryActionLabel)
        .font(.footnote.weight(.semibold))
        .foregroundColor(Color.white.opacity(0.65))
        .accessibilityHidden(true)

      ZStack {
        RoundedRectangle(cornerRadius: 22)
          .fill(Color.white.opacity(0.03))
          .overlay(
            RoundedRectangle(cornerRadius: 22)
              .stroke(mintGreen.opacity(0.70), lineWidth: 1.6)
          )

        if dots.isEmpty {
          Image(systemName: "hand.draw")
            .font(.system(size: 42, weight: .regular))
            .foregroundColor(mintGreen.opacity(0.30))
            .transition(AnyTransition.opacity)
        } else {
          BrailleCellInPad(dots: dots)
            .transition(AnyTransition.opacity)
        }
      }
      .frame(height: 250)
      .contentShape(Rectangle())
      .gesture(mainGesture)
      .animation(.snappy(duration: 0.18), value: dots.isEmpty)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, 10)
    .background(Color.black.ignoresSafeArea(edges: .bottom))
    .accessibilityHidden(true)
    .onReceive(NotificationCenter.default.publisher(for: .didShakePhone)) { _ in
      deleteLastDigit()
    }
  }

  private var mainGesture: some Gesture {
    let tapGesture = TapGesture(count: 2)
      .onEnded { onPrimaryAction() }
      .exclusively(
        before:
          TapGesture(count: 1)
          .onEnded { commitIfPartial() }
      )

    return SimultaneousGesture(
      DragGesture(minimumDistance: 18)
        .onEnded { value in
          let dx = value.translation.width
          let dy = value.translation.height

          guard abs(dx) > abs(dy) else { return }

          if dx >= 28 {
            registerDot(true)
          } else if dx <= -28 {
            registerDot(false)
          }
        },
      tapGesture
    )
  }

  private func registerDot(_ raised: Bool) {
    guard dots.count < maxDots else { return }

    dots.append(raised)
    HapticsManager.shared.play(raised ? .dotOn : .dotOff)

    if dots.count == maxDots {
      commitCharacter()
    }
  }

  private func commitIfPartial() {
    guard !dots.isEmpty else { return }
    commitCharacter()
  }

  private func commitCharacter() {
    if dots.count < maxDots {
      dots += Array(repeating: false, count: maxDots - dots.count)
    }

    guard let char = BrailleTranslator.character(forDots: dots) else {
      HapticsManager.shared.play(.commitFailure)
      dots.removeAll()
      return
    }

    if let digit = brailleCharToDigit(char) {
      digits.append(digit)
      HapticsManager.shared.play(.commitSuccess)
    } else {
      HapticsManager.shared.play(.commitFailure)
    }

    dots.removeAll()
  }

  private func brailleCharToDigit(_ char: Character) -> String? {
    switch String(char).lowercased() {
    case "a": return "1"
    case "b": return "2"
    case "c": return "3"
    case "d": return "4"
    case "e": return "5"
    case "f": return "6"
    case "g": return "7"
    case "h": return "8"
    case "i": return "9"
    case "j": return "0"
    default: return nil
    }
  }

  private func deleteLastDigit() {
    guard !digits.isEmpty else { return }
    digits.removeLast()
    HapticsManager.shared.play(.commitFailure)
    dots.removeAll()
  }
}

private struct BrailleCellInPad: View {

  let dots: [Bool]

  private let dotSize: CGFloat = 36
  private let spacing: CGFloat = 30

  private func state(for index: Int) -> DotState {
    if index < dots.count {
      return dots[index] ? .raised : .flat
    }
    return .empty
  }

  var body: some View {
    let mint = Color("MintGreen")

    VStack(spacing: spacing) {
      HStack(spacing: spacing) {
        dotView(state: state(for: 0), mint: mint)
        dotView(state: state(for: 3), mint: mint)
      }
      HStack(spacing: spacing) {
        dotView(state: state(for: 1), mint: mint)
        dotView(state: state(for: 4), mint: mint)
      }
      HStack(spacing: spacing) {
        dotView(state: state(for: 2), mint: mint)
        dotView(state: state(for: 5), mint: mint)
      }
    }
  }

  private func dotView(state: DotState, mint: Color) -> some View {
    Circle()
      .fill(fillColor(for: state, mint: mint))
      .overlay(
        Circle()
          .stroke(strokeColor(for: state, mint: mint), lineWidth: 2)
      )
      .frame(width: dotSize, height: dotSize)
      .scaleEffect(state == .raised ? 1.08 : 1.0)
      .animation(.snappy(duration: 0.14), value: state)
  }

  private func fillColor(for state: DotState, mint: Color) -> Color {
    switch state {
    case .raised:
      return mint
    case .flat:
      return Color.black.opacity(0.0)
    case .empty:
      return Color.black.opacity(0.0)
    }
  }

  private func strokeColor(for state: DotState, mint: Color) -> Color {
    switch state {
    case .raised:
      return mint.opacity(0.95)
    case .flat:
      return mint.opacity(0.80)
    case .empty:
      return mint.opacity(0.28)
    }
  }

  private enum DotState {
    case empty
    case flat
    case raised
  }
}
