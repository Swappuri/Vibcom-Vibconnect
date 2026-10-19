//
//  ContactsMatchListView.swift
//  Vibcom
//

import SwiftUI

struct ContactsMatchListView: View {

  let matches: [VibcomRemoteUser]
  let onAddFriend: (VibcomRemoteUser) -> Void

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("On Vibcom")
        .font(.headline)
        .foregroundColor(.white)

      if matches.isEmpty {
        Text("No contacts found on Vibcom yet.")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.70))
      } else {
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 10) {
            ForEach(matches) { user in
              row(user)
            }
          }
        }
      }
    }
  }

  private func row(_ user: VibcomRemoteUser) -> some View {
    Button {
      onAddFriend(user)
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(mintGreen.opacity(0.16))
          Text(initials(from: user.displayName))
            .font(.subheadline.weight(.bold))
            .foregroundColor(mintGreen)
        }
        .frame(width: 42, height: 42)

        VStack(alignment: .leading, spacing: 2) {
          Text(user.displayName)
            .font(.headline)
            .foregroundColor(.white)

          Text(user.phoneE164)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.70))
        }

        Spacer()

        Image(systemName: "plus.circle.fill")
          .font(.title3)
          .foregroundColor(mintGreen)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .background(Color.white.opacity(0.05))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(mintGreen.opacity(0.18), lineWidth: 1.0)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityLabel("Add friend \(user.displayName)")
    .accessibilityHint("Double tap to add this person as a friend.")
  }

  private func initials(from name: String) -> String {
    let parts = name.split(separator: " ").map(String.init)
    if parts.isEmpty { return "V" }
    if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
    let a = String(parts[0].prefix(1)).uppercased()
    let b = String(parts[1].prefix(1)).uppercased()
    return a + b
  }
}
