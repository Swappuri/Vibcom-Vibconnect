# Contributing

Thanks for taking an interest in Vibcom and Vibconnect.

## Before you start

- Open the relevant shared Xcode scheme from `Apps/Vibcom/Vibcom.xcodeproj` or `Apps/Vibconnect/Vibconnect.xcodeproj`.
- Follow [Firebase setup](docs/FIREBASE.md) for local configuration. Keep Firebase plists and signing credentials out of commits.
- Keep changes focused on one app or a clearly related shared workflow.

## Style and checks

- Use two-space indentation and the checked-in `.swift-format` configuration.
- Run `scripts/format-swift.sh` to format Swift sources and `scripts/lint-swift.sh` to check them.
- Build the affected shared scheme in Xcode. The GitHub Actions workflow builds both apps for the iOS Simulator.
- Include or update automated tests when a change adds testable behavior; this repository does not currently contain test targets.

## Pull requests

Describe the user-visible change, identify the app(s) affected, and include screenshots or a short screen recording for visual changes. Note any Firebase setup or privacy implications.
