//
//  LoginView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import SwiftData
import SwiftUI

struct LoginView: View {

  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var appState: AppState

  let onBackToLanding: () -> Void
  let onSwitchToSignup: () -> Void

  @State private var identifier: String = ""
  @State private var password: String = ""
  @State private var isPasswordVisible: Bool = false
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?

  // 👇 Track which field is currently active
  @FocusState private var focusedField: Field?

  private var mintGreen: Color { Color("MintGreen") }

  // 👇 Which field can receive braille input
  private enum Field {
    case identifier
    case password
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {

      ZStack {
        HStack {
          Button(action: onBackToLanding) {
            Image(systemName: "chevron.left")
              .font(.title2.weight(.medium))
              .foregroundColor(mintGreen)
          }
          .vibcomAccessible(
            label: "Back button",
            hint: "Return to the Vibcom home screen."
          )
          Spacer()
        }

        Text("Welcome back")
          .font(.largeTitle.weight(.semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.top, 20)

      VStack(spacing: 16) {
        AuthTextField(
          iconName: "person.fill",
          placeholder: "Username or email",
          text: $identifier,
          keyboardType: .emailAddress,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .identifier)  // 👈 focusable
        .vibcomAccessible(
          label: "Username or email field",
          hint: "Double tap to edit your username or email."
        )

        AuthPasswordField(
          iconName: "lock.fill",
          placeholder: "Password",
          text: $password,
          isVisible: $isPasswordVisible,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .password)  // 👈 focusable
        .vibcomAccessible(
          label: "Password field",
          hint: "Double tap to edit your password."
        )

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .vibcomAccessible(
              label: "Error",
              hint: errorMessage
            )
        }

        Button(action: handleLogin) {
          if isLoading {
            ProgressView()
              .tint(mintGreen)
              .frame(maxWidth: .infinity)
          } else {
            Text("LOGIN")
              .font(.headline)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.vertical, 14)
        .foregroundColor(mintGreen)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(mintGreen, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .disabled(isLoading || !isInputValid)
        .vibcomAccessible(
          label: "Login button",
          hint: "Attempts to log in with the entered credentials."
        )

        HStack(spacing: 4) {
          Text("Don’t have an account?")
            .foregroundColor(.white.opacity(0.75))
            .font(.subheadline)
            .vibcomAccessible(
              label: "Don’t have an account?",
              hint: "You can create one with the Sign up button."
            )

          Button(action: onSwitchToSignup) {
            Text("Sign up")
              .foregroundColor(mintGreen)
              .font(.subheadline.weight(.semibold))
          }
          .vibcomAccessible(
            label: "Sign up link",
            hint: "Opens the sign up screen."
          )
        }
        .padding(.top, 8)
      }

      Spacer()

      // 👇 Braille keyboard appears when braille mode is active
      if appState.isBrailleModeActive {
        BrailleKeyboardView(text: bindingForFocusedField) {
          // What "Send" does on the login screen:
          //  - From identifier → move focus to password
          //  - From password → attempt login
          if focusedField == .identifier {
            focusedField = .password
          } else {
            handleLogin()
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
    }
    .padding(.horizontal, 24)
    .background(Color.black.ignoresSafeArea())
    .onAppear {
      // Default focus when this screen appears
      focusedField = .identifier
    }
  }

  // 👇 Choose which text the braille keyboard is editing
  private var bindingForFocusedField: Binding<String> {
    switch focusedField {
    case .password:
      return $password
    default:
      return $identifier
    }
  }

  private var isInputValid: Bool {
    !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
  }

  private func handleLogin() {
    errorMessage = nil

    let trimmed =
      identifier
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    guard !trimmed.isEmpty, !password.isEmpty else {
      errorMessage = "Please enter your username or email and password."
      return
    }

    isLoading = true

    Task { @MainActor in
      defer { isLoading = false }

      do {
        var descriptor = FetchDescriptor<VibcomUser>(
          predicate: #Predicate { user in
            user.email == lower || user.username == trimmed
          }
        )
        descriptor.fetchLimit = 1

        let users = try modelContext.fetch(descriptor)

        guard let user = users.first else {
          errorMessage = "No account found for those credentials."
          return
        }

        let incomingHash = PasswordHasher.hash(password)
        guard incomingHash == user.passwordHash else {
          errorMessage = "Incorrect password. Please try again."
          return
        }

        user.presence = .active
        do {
          try modelContext.save()
        } catch {
          print("Failed to save presence on login: \(error)")
        }

        appState.setCurrentUser(user)

      } catch {
        errorMessage = "Unable to log in right now. Please try again."
        print("Login error: \(error)")
      }
    }
  }
}
