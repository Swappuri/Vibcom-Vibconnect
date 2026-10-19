//
//  FocusMessageCard.swift
//  Vibcom
//
//  A message card that grows and highlights when it is the centered (focused) message.
//

import SwiftUI

struct FocusMessageCard: View {
  let message: Message
  let isCurrentUser: Bool
  let isFocused: Bool

  private var mintGreen: Color { Color("MintGreen") }

  private var cardFill: Color {
    isCurrentUser
      ? mintGreen.opacity(isFocused ? 0.26 : 0.16) : Color.white.opacity(isFocused ? 0.11 : 0.07)
  }

  private var cardStroke: Color {
    isFocused ? mintGreen.opacity(0.95) : Color.white.opacity(0.18)
  }

  private var senderLabel: String {
    if isCurrentUser { return "You" }
    return PhoneDisplayLabel.resolvedName(
      displayName: message.author?.displayName ?? "",
      username: message.author?.username ?? "Friend"
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {

      header

      Text(message.text.isEmpty ? "Empty" : message.text)
        .font(messageFont)
        .foregroundColor(.white)
        .lineSpacing(isFocused ? 6 : 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 26)
        .fill(cardFill)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 26)
        .stroke(cardStroke, lineWidth: isFocused ? 2.1 : 1.1)
    )
    .shadow(
      color: Color.black.opacity(isFocused ? 0.30 : 0.10), radius: isFocused ? 14 : 6, x: 0, y: 8
    )
    .scaleEffect(isFocused ? 1.0 : 0.95)
    .opacity(isFocused ? 1.0 : 0.82)
    .animation(.snappy(duration: 0.22), value: isFocused)
    .contentShape(Rectangle())
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "person.fill")
        .foregroundColor(isCurrentUser ? .white.opacity(0.85) : mintGreen)

      Text(senderLabel)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.white)

      Spacer()

      Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
        .font(.footnote)
        .foregroundColor(.white.opacity(0.65))
    }
  }

  private var messageFont: Font {
    if isFocused {
      return .system(size: 32, weight: .semibold, design: .rounded)
    }
    return .system(size: 22, weight: .semibold, design: .rounded)
  }
}
