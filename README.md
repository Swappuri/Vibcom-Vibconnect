# Vibcom and Vibconnect

Vibcom and Vibconnect are companion iOS apps exploring accessible mobile messaging. Vibcom provides messaging with Braille-inspired input and haptic, audio, and visual feedback. Vibconnect supports nearby discovery and contact exchange. The project is organized as two independently built iOS apps. [The project report](docs/project-report.pdf) describes the system and its design.

## Repository layout

```text
.github/workflows/   Formatting and simulator build checks
Apps/Vibcom/         Vibcom app and shared Xcode scheme
Apps/Vibconnect/     Vibconnect app and shared Xcode scheme
docs/                Architecture, setup, privacy notes, and project documents
scripts/             Swift formatting commands
```

## Requirements

- macOS and Xcode 16.4 or later
- iOS 18.5 SDK or later
- A Firebase project with separate iOS registrations for both apps
- An Apple Developer team and App Group for device signing and shared identity

The checked-in `com.example.www.*` bundle identifiers and `group.com.example.www.vibcom.shared` App Group are development placeholders. Replace them with identifiers registered to your team before signing or distribution. Keep the App Group consistent in both app targets and source files.

## Configure and run

1. Open `Apps/Vibcom/Vibcom.xcodeproj` or `Apps/Vibconnect/Vibconnect.xcodeproj` in Xcode. Use the shared `Vibcom` or `Vibconnect` scheme.
2. Follow [Firebase setup](docs/FIREBASE.md) to register both apps, add local Firebase configuration, and configure the Apple App Group.
3. Allow Xcode to resolve the Firebase iOS SDK Swift Package dependency.
4. Select an iOS Simulator or signed device and build and run the selected scheme.

Firebase Authentication and Cloud Firestore are required by app features. This repository does not include Firebase deployment files or Firestore security rules. Do not connect real users until backend access and data-retention rules have been configured and reviewed.

## Development checks

Run `scripts/lint-swift.sh` to check formatting or `scripts/format-swift.sh` to apply the checked-in Swift formatting rules. GitHub Actions checks formatting and builds both apps for the iOS Simulator. The Xcode projects do not currently contain automated test targets.

## Project documents

- [Architecture](docs/ARCHITECTURE.md)
- [Firebase setup](docs/FIREBASE.md)
- [Data flows and privacy notes](docs/DATA-AND-PRIVACY.md)
- [Project report](docs/project-report.pdf)
- [Project presentation](docs/project-presentation.pdf)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full terms.

Built app bundles, Xcode user state, signing profiles, and Firebase configuration files are local-only and excluded from Git.
