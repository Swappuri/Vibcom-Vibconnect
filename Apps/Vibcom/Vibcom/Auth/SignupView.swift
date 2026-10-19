//
//  SignupView.swift
//  Vibcom
//
//  Created by Swapnil Puri on 11/24/25.
//

import SwiftData
import SwiftUI

struct SignupView: View {

  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var appState: AppState

  let onBackToLanding: () -> Void
  let onSwitchToLogin: () -> Void

  @State private var email: String = ""
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var confirmPassword: String = ""
  @State private var isPasswordVisible: Bool = false
  @State private var isConfirmPasswordVisible: Bool = false
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?

  // 👇 Track focus for braille keyboard
  @FocusState private var focusedField: Field?

  private var mintGreen: Color { Color("MintGreen") }

  private enum Field {
    case username
    case email
    case password
    case confirmPassword
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

        Text("Create an account")
          .font(.largeTitle.weight(.semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.top, 20)

      VStack(spacing: 16) {
        AuthTextField(
          iconName: "person.fill",
          placeholder: "Username",
          text: $username,
          keyboardType: .default,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .username)
        .vibcomAccessible(
          label: "Username field",
          hint: "Double tap to edit your username."
        )

        AuthTextField(
          iconName: "envelope.fill",
          placeholder: "Email",
          text: $email,
          keyboardType: .emailAddress,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .email)
        .vibcomAccessible(
          label: "Email field",
          hint: "Double tap to edit your email address."
        )

        AuthPasswordField(
          iconName: "lock.fill",
          placeholder: "Password",
          text: $password,
          isVisible: $isPasswordVisible,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .password)
        .vibcomAccessible(
          label: "Password field",
          hint: "Double tap to set your password. Minimum eight characters."
        )

        AuthPasswordField(
          iconName: "checkmark.seal.fill",
          placeholder: "Confirm Password",
          text: $confirmPassword,
          isVisible: $isConfirmPasswordVisible,
          mintGreen: mintGreen
        )
        .focused($focusedField, equals: .confirmPassword)
        .vibcomAccessible(
          label: "Confirm password field",
          hint: "Double tap to re-enter your password."
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

        Button(action: handleSignup) {
          if isLoading {
            ProgressView()
              .tint(mintGreen)
              .frame(maxWidth: .infinity)
          } else {
            Text("SIGN UP")
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
          label: "Sign up button",
          hint: "Creates your Vibcom account with the entered information."
        )

        HStack(spacing: 4) {
          Text("Already have an account?")
            .foregroundColor(.white.opacity(0.75))
            .font(.subheadline)
            .vibcomAccessible(
              label: "Already have an account?",
              hint: "You can log in with the Login button."
            )

          Button(action: onSwitchToLogin) {
            Text("Login")
              .foregroundColor(mintGreen)
              .font(.subheadline.weight(.semibold))
          }
          .vibcomAccessible(
            label: "Login link",
            hint: "Opens the login screen."
          )
        }
        .padding(.top, 8)
      }

      Spacer()

      // 👇 Braille keyboard only when braille mode is active
      if appState.isBrailleModeActive {
        BrailleKeyboardView(text: bindingForFocusedField) {
          // What "Send" means for signup:
          switch focusedField {
          case .username:
            focusedField = .email
          case .email:
            focusedField = .password
          case .password:
            focusedField = .confirmPassword
          default:
            handleSignup()
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
    }
    .padding(.horizontal, 24)
    .background(Color.black.ignoresSafeArea())
    .onAppear {
      focusedField = .username
    }
  }

  // 👇 Which field gets braille input right now
  private var bindingForFocusedField: Binding<String> {
    switch focusedField {
    case .email:
      return $email
    case .password:
      return $password
    case .confirmPassword:
      return $confirmPassword
    default:
      return $username
    }
  }

  private var isInputValid: Bool {
    !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 8
      && confirmPassword == password
  }

  private func handleSignup() {
    errorMessage = nil

    let trimmedEmail =
      email
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let trimmedUsername =
      username
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard isInputValid else {
      errorMessage = "Please complete all fields. Password must be at least 8 characters and match."
      return
    }

    isLoading = true

    Task { @MainActor in
      defer { isLoading = false }

      do {
        var emailDescriptor = FetchDescriptor<VibcomUser>(
          predicate: #Predicate { user in
            user.email == trimmedEmail
          }
        )
        emailDescriptor.fetchLimit = 1

        if try modelContext.fetch(emailDescriptor).first != nil {
          errorMessage = "An account with that email already exists."
          return
        }

        var usernameDescriptor = FetchDescriptor<VibcomUser>(
          predicate: #Predicate { user in
            user.username == trimmedUsername
          }
        )
        usernameDescriptor.fetchLimit = 1

        if try modelContext.fetch(usernameDescriptor).first != nil {
          errorMessage = "That username is already taken."
          return
        }

        let hashed = PasswordHasher.hash(password)

        let newUser = VibcomUser(
          email: trimmedEmail,
          username: trimmedUsername,
          displayName: trimmedUsername,
          passwordHash: hashed
        )

        modelContext.insert(newUser)
        try modelContext.save()

        newUser.presence = .active
        try modelContext.save()
        appState.setCurrentUser(newUser)

      } catch {
        errorMessage = "Unable to create account right now. Please try again."
        print("Signup error: \(error)")
      }
    }
  }
}
