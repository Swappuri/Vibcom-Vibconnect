//
//  ChatRowView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 12/5/25.
//

import SwiftUI

struct ChatRowView: View {
  let friend: VibcomUser
  private var displayName: String {
    PhoneDisplayLabel.resolvedName(displayName: friend.displayName, username: friend.username)
  }

  var body: some View {
    HStack(spacing: VibcomSpace.xs) {

      UserAvatarView(user: friend, size: VibcomSize.minTap)

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName)
          .font(VibcomTypography.body.weight(.semibold))
          .foregroundColor(VibcomColor.textPrimary)

        Text("Tap to start chatting")
          .font(VibcomTypography.caption)
          .foregroundColor(VibcomColor.textSecondary)
      }

      Spacer()
    }
    .frame(minHeight: VibcomSize.rowHeight)
    .padding(.horizontal, VibcomSpace.sm)
    .padding(.vertical, VibcomSpace.xs)
    .vibcomAccessible(
      label: "Chat with \(displayName).",
      hint: "Long press to hear this description. Double tap to open the conversation."
    )
  }
}

struct ChatRowCardView: View {
  let friend: VibcomUser

  private var mintGreen: Color { Color("MintGreen") }
  private var displayName: String {
    PhoneDisplayLabel.resolvedName(displayName: friend.displayName, username: friend.username)
  }

  var body: some View {
    HStack(spacing: VibcomSpace.xs) {

      UserAvatarView(user: friend, size: VibcomSize.minTap)

      VStack(alignment: .leading, spacing: 4) {
        Text(displayName)
          .font(VibcomTypography.body.weight(.semibold))
          .foregroundColor(VibcomColor.textPrimary)

        HStack(spacing: 6) {
          Circle()
            .fill(PresenceStyle.color(for: friend.presence))
            .frame(width: 6, height: 6)

          Text(PresenceStyle.text(for: friend.presence))
            .font(VibcomTypography.caption)
            .foregroundColor(VibcomColor.textSecondary)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(mintGreen)
    }
    .frame(minHeight: VibcomSize.rowHeight)
    .padding(.horizontal, VibcomSpace.xs)
    .padding(.vertical, VibcomSpace.xs)
    .overlay(
      RoundedRectangle(cornerRadius: VibcomRadius.sm)
        .stroke(mintGreen, lineWidth: VibcomStroke.focus)
    )
    .vibcomAccessible(
      label: "Chat with \(displayName). Status \(PresenceStyle.text(for: friend.presence)).",
      hint: "Long press to hear and feel this description. Double tap to open this chat."
    )
  }
}
