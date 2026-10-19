# Vibcom & Vibconnect

**Accessible communication, with Braille-inspired messaging and nearby connection.**

Vibcom and Vibconnect are two companion iOS apps designed to work together. Vibcom is the communication app: people can find contacts who already use the service, message them, and compose messages with a Braille-inspired input experience supported by haptic, audio, and visual feedback. Vibconnect extends that experience to in-person discovery, helping people discover nearby profiles and exchange contact details with an accepted peer.

The apps are separate Xcode projects, but share an account identity. Sign in with Vibcom, then Vibconnect can use that identity for nearby discovery and contact exchange. Together, they explore how accessible interaction and in-person connection can complement everyday messaging.

## The two apps

### Vibcom

- Phone-number sign-in and profile setup
- Contact matching to find existing Vibcom users
- One-to-one conversations backed by Cloud Firestore
- Braille-inspired message composition, with configurable feedback
- Haptic, spoken, and visual feedback to support message entry and reading
- Profile, presence, and accessibility preferences

### Vibconnect

- Nearby profile discovery using location
- On-device contact filtering for discovery results
- Encrypted peer-to-peer exchange using Apple Multipeer Connectivity
- Add an accepted nearby person to device contacts
- Shared Vibcom account identity through an Apple App Group

## How the system fits together

```text
Vibcom ── account, contacts, messaging, Braille-inspired interaction
   │
   ├── Firebase Authentication and Cloud Firestore
   │
   └── shared account identity (Apple App Group)
             │
             └── Vibconnect ── nearby discovery and peer contact exchange
```

The apps are built and signed independently. Firebase stores account, profile, presence, discovery, and conversation data. Vibconnect uses the shared identity to discover profiles and uses encrypted Multipeer Connectivity for an accepted nearby exchange. See [Architecture](docs/ARCHITECTURE.md) and [Data flows and privacy notes](docs/DATA-AND-PRIVACY.md) for more detail.

## Visuals

The repository currently includes app branding and icons, but no representative in-app screenshots. The [project presentation](docs/project-presentation.pdf) and [project report](docs/project-report.pdf) provide the available visual walkthrough and deeper design context.

## Built with

- **Swift and SwiftUI** for the iOS applications and interfaces
- **SwiftData** for local profile and conversation state
- **Firebase Authentication** for phone-based account sign-in
- **Cloud Firestore** for profiles, presence, discovery data, and messages
- **Core Location** for nearby discovery
- **Contacts and PhotosUI** for contact matching, contact creation, and local profile image selection
- **Multipeer Connectivity** for encrypted nearby peer exchange
- **Apple App Groups** to share account identity between the apps

## Repository layout

```text
Apps/Vibcom/         Vibcom iOS app and shared Xcode scheme
Apps/Vibconnect/     Vibconnect iOS app and shared Xcode scheme
docs/                Architecture, setup, privacy notes, report, and presentation
scripts/             Swift formatting commands
.github/workflows/   Formatting and simulator build checks
```

## Build and run

### Requirements

- macOS with Xcode 16.4 or later
- iOS 18.5 SDK or later
- A Firebase project with separate iOS registrations for both apps
- An Apple Developer team and App Group for device signing and shared identity

### Setup

1. Open `Apps/Vibcom/Vibcom.xcodeproj` or `Apps/Vibconnect/Vibconnect.xcodeproj` in Xcode.
2. Select the shared `Vibcom` or `Vibconnect` scheme.
3. Follow [Firebase setup](docs/FIREBASE.md) to register both apps and add the Firebase configuration files locally.
4. Replace the checked-in `com.example.www.*` bundle identifiers and `group.com.example.www.vibcom.shared` App Group placeholder with identifiers registered to your team. Keep the App Group consistent across both targets and the source.
5. Allow Xcode to resolve the Firebase iOS SDK Swift Package dependency, then select an iOS Simulator or a signed device and run the app.

Firebase-backed features require a configured Firebase project. This repository does not include Firebase deployment files or Firestore security rules. Configure and review restrictive backend access and data-retention rules before connecting real users. See [Firebase setup](docs/FIREBASE.md) and [Data flows and privacy notes](docs/DATA-AND-PRIVACY.md).

## Development

Run `scripts/lint-swift.sh` to check formatting or `scripts/format-swift.sh` to apply the repository's Swift formatting rules. GitHub Actions checks formatting and builds both apps for the iOS Simulator. The Xcode projects do not currently include automated test targets.

## Project documents

The source and this README are intended to give a quick overview. For a fuller account of the design and project, see the [project report](docs/project-report.pdf) and [project presentation](docs/project-presentation.pdf).

- [Architecture](docs/ARCHITECTURE.md)
- [Firebase setup](docs/FIREBASE.md)
- [Data flows and privacy notes](docs/DATA-AND-PRIVACY.md)
- [Project report](docs/project-report.pdf)
- [Project presentation](docs/project-presentation.pdf)

## License

This project is licensed under the [MIT License](LICENSE).
