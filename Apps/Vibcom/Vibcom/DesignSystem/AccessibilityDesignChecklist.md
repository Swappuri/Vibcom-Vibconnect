# Vibcom Accessibility UI Checklist

## Interaction
- All core actions work with VoiceOver only.
- All interactive elements have `accessibilityLabel`.
- Important controls include `accessibilityHint`.
- Dynamic Type works at largest accessibility sizes without clipping.
- Tap target minimum is at least `48x48pt`.

## Layout
- Use spacing tokens only: `8, 12, 16, 20, 24, 32`.
- Keep side padding between `16-20pt`.
- Keep row minimum height at `88pt` in chat lists.
- Keep primary controls in stable screen positions.

## Visual
- Maintain high contrast across text and controls.
- Use one corner-radius system (`12, 16, 24`).
- Use one stroke system (`1pt default`, `2pt focus`).
- Use one icon style and consistent icon sizes.

## Feedback
- Announce mode changes, send success, and errors.
- Use distinct haptic patterns for success and failure.
- Provide spoken confirmation for destructive actions.

## Chat and Input
- Chat rows expose actions: open, mark read, delete.
- Current input mode is always announced.
- Drawing recognition failure clears drawing and announces failure.
- Gesture mode controls remain consistent everywhere.
