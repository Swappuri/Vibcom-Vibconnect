# Architecture

Vibcom and Vibconnect are separate SwiftUI iOS applications that share an account identity and support different parts of an accessible messaging workflow. They are built and signed independently.

## Vibcom

Vibcom owns phone-based Firebase Authentication, user profiles, contacts matching, messaging, presence, and Braille-inspired input and feedback. SwiftData stores local user and conversation state. Firebase Cloud Firestore stores user profiles, presence, nearby-discovery fields, conversation summaries, and message records.

## Vibconnect

Vibconnect uses the shared identity to discover nearby profiles, filters candidates against on-device contacts, and exchanges a phone number and account identifier with an accepted nearby peer using encrypted Multipeer Connectivity. It can add accepted profiles to the device contacts.

## Shared identity

Both apps use the same App Group identifier in `SharedIdentityStore.swift` and their `.entitlements` files. The shared defaults store contains the Firebase user ID and phone number so Vibconnect can act on the Vibcom account. The App Group must be registered and enabled for both app identifiers in the signing team.

## Backend boundary

The repository contains the iOS clients, not Firebase deployment configuration. Firestore collection names and fields are defined in the app services. Firebase Authentication providers, Firestore indexes and security rules, project configuration, retention, and operational monitoring must be configured separately. Do not treat a successful client build as backend security validation.
