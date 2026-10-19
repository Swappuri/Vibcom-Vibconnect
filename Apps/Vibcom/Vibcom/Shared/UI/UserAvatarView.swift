//
//  UserAvatarView.swift
//  Vibcom
//

import SwiftUI
import UIKit

struct UserAvatarView: View {

  let user: VibcomUser
  let size: CGFloat

  var body: some View {
    Group {
      if let data = user.profileImageData,
        let uiImage = UIImage(data: data)
      {

        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()

      } else {

        IdenticonView(seed: user.username)
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(
      Circle()
        .stroke(Color.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.24), radius: size * 0.12, x: 0, y: size * 0.08)
  }
}

private struct IdenticonView: View {

  let seed: String

  private var seedHash: UInt64 {
    var hash: UInt64 = 1_469_598_103_934_665_603
    for byte in seed.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return hash
  }

  private var palette: (Color, Color) {
    let hueA = Double(seedHash % 360) / 360.0
    let hueB = Double((seedHash / 13) % 360) / 360.0
    let start = Color(hue: hueA, saturation: 0.72, brightness: 0.90)
    let end = Color(hue: hueB, saturation: 0.62, brightness: 0.62)
    return (start, end)
  }

  var body: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [palette.0, palette.1],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        Circle()
          .stroke(Color.white.opacity(0.24), lineWidth: 1.0)
      )
      .overlay(
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.12)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .blendMode(.softLight)
      )
  }
}
