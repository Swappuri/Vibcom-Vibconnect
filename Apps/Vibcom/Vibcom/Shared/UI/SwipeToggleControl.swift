//
//  SwipeToggleControl.swift
//  Vibcom
//

import SwiftUI

struct SwipeToggleControl: View {
  @Binding var isOn: Bool
  var activeColor: Color = Color("MintGreen")
  var inactiveKnobColor: Color = Color.white.opacity(0.92)
  var trackColor: Color = Color.white.opacity(0.16)
  var width: CGFloat = 220
  var height: CGFloat = 34
  var knobPadding: CGFloat = 3

  @State private var dragOffset: CGFloat = 0
  @State private var dragStartOffset: CGFloat?
  @State private var isDragging = false

  private var knobSize: CGFloat { height - (knobPadding * 2) }
  private var maxTravel: CGFloat { width - knobSize - (knobPadding * 2) }
  private var baseOffset: CGFloat { isOn ? maxTravel : 0 }
  private var renderedOffset: CGFloat { min(max(dragOffset, 0), maxTravel) }

  var body: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(trackColor)
        .frame(width: width, height: height)

      Circle()
        .fill(isOn ? activeColor : inactiveKnobColor)
        .frame(width: knobSize, height: knobSize)
        .offset(x: knobPadding + renderedOffset)
        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 2)
        .onChanged { value in
          if isDragging == false {
            isDragging = true
            dragStartOffset = baseOffset
          }
          let start = dragStartOffset ?? baseOffset
          dragOffset = min(max(start + value.translation.width, 0), maxTravel)
        }
        .onEnded { value in
          let start = dragStartOffset ?? baseOffset
          let projected = start + value.predictedEndTranslation.width * 0.38
          let shouldEnable = projected > (maxTravel / 2)
          withAnimation(.interactiveSpring(response: 0.14, dampingFraction: 0.96)) {
            isOn = shouldEnable
            dragOffset = shouldEnable ? maxTravel : 0
            isDragging = false
            dragStartOffset = nil
          }
        }
    )
    .onAppear {
      dragOffset = baseOffset
    }
    .onChange(of: isOn) { _, newValue in
      guard isDragging == false else { return }
      withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.96)) {
        dragOffset = newValue ? maxTravel : 0
      }
    }
    .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.95), value: isOn)
  }
}
