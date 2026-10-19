//
//  FocusFriendChatCard.swift
//  Vibcom
//
//  Created by Swapnil Puri on 2/11/26.
//

import SwiftUI

struct FocusFriendChatCard: View {

  let friend: VibcomUser
  let isFocused: Bool
  let preview: String
  let timestamp: Date?

  private var mintGreen: Color { Color("MintGreen") }
  private var status: PresenceStatus {
    PresenceStyle.displayedStatus(for: friend, currentUserID: nil)
  }
  private var displayName: String {
    PhoneDisplayLabel.resolvedName(displayName: friend.displayName, username: friend.username)
  }

  var body: some View {
    HStack(spacing: 14) {

      ZStack {
        UserAvatarView(user: friend, size: 44)

        Circle()
          .stroke(
            isFocused ? mintGreen.opacity(0.95) : mintGreen.opacity(0.18),
            lineWidth: isFocused ? 2 : 1)
      }
      .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(displayName)
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .lineLimit(1)

          Spacer()

          if let timestamp {
            Text(timestamp, style: .time)
              .font(.caption.weight(.semibold))
              .foregroundColor(.white.opacity(isFocused ? 0.70 : 0.40))
          }
        }

        Text(preview)
          .font(.subheadline)
          .foregroundColor(.white.opacity(isFocused ? 0.85 : 0.62))
          .lineLimit(1)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: status))
            .frame(width: 7, height: 7)

          Text(PresenceStyle.text(for: status))
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
          Capsule()
            .fill(Color.white.opacity(isFocused ? 0.13 : 0.08))
        )
      }

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(mintGreen.opacity(isFocused ? 0.9 : 0.18))
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity)
    .frame(height: 104)
    .background(
      RoundedRectangle(cornerRadius: 22)
        .fill(isFocused ? Color.white.opacity(0.10) : Color.white.opacity(0.045))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22)
        .stroke(
          isFocused ? mintGreen.opacity(0.95) : Color.white.opacity(0.10),
          lineWidth: isFocused ? 2 : 1
        )
    )
    .shadow(
      color: .black.opacity(isFocused ? 0.32 : 0.10),
      radius: isFocused ? 16 : 8,
      x: 0,
      y: isFocused ? 10 : 5
    )
    .scaleEffect(isFocused ? 1.03 : 0.96)
    .opacity(isFocused ? 1.0 : 0.80)
    .animation(.snappy(duration: 0.22), value: isFocused)
  }
}
