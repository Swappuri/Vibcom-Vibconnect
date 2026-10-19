//
//  MessageBubbleView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 12/3/25.
//

import SwiftUI

struct MessageBubbleView: View {
  @EnvironmentObject private var appState: AppState

  let message: Message
  let isCurrentUser: Bool

  private var mintGreen: Color { Color("MintGreen") }

  var body: some View {
    HStack {
      if isCurrentUser { Spacer() }

      VStack(alignment: .leading, spacing: 4) {
        Text(message.text)
          .foregroundColor(isCurrentUser ? .black : .white)
          .font(.body)
          .padding(10)
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(isCurrentUser ? mintGreen : Color.gray.opacity(0.4))
          )

        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
          .font(.caption2)
          .foregroundColor(.white.opacity(0.6))
          .padding(.horizontal, 4)
      }
      .frame(maxWidth: 260, alignment: isCurrentUser ? .trailing : .leading)

      if !isCurrentUser { Spacer() }
    }
    .onTapGesture {
      let spoken = message.text.isEmpty ? "Empty message" : message.text
      BraillePlaybackEngine.shared.readMessage(
        spoken,
        brailleEnabled: appState.isBrailleModeActive
      )
    }
  }
}
