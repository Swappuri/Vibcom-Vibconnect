//
//  SwipeNavigateBar.swift
//  Vibcom
//
//  Created by Swapnil Puri on 2/11/26.
//

import SwiftUI

struct SwipeNavigateBar: View {
  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "chevron.up")
        .font(.caption.weight(.semibold))
        .foregroundColor(mintGreen.opacity(0.9))

      Text("Swipe up or down to focus messages")
        .font(.footnote.weight(.semibold))
        .foregroundColor(.white.opacity(0.85))

      Image(systemName: "chevron.down")
        .font(.caption.weight(.semibold))
        .foregroundColor(mintGreen.opacity(0.9))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.white.opacity(0.04))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(mintGreen.opacity(0.65), lineWidth: 1.2)
    )
    .accessibilityHidden(true)
  }
}
