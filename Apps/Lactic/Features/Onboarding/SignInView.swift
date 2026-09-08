import LacticKit
import SwiftUI

/// Sign-in.
///
/// Only the development path exists so far. Google Sign-In is order-of-work
/// step 8 and Sign in with Apple lands at the App Store gate, where guideline
/// 4.8 makes it mandatory once Google is offered. Both slot in beside this
/// through the same `SessionStore` calls.
struct SignInView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var email = "alice@example.com"
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Lactic")
                    .font(.largeTitle.bold())
                Text("Follow your programme, log your sets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            #if DEBUG
                developmentSignIn
            #else
                Text("Sign-in is not available in this build yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            #endif

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if DEBUG
        private var developmentSignIn: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Development sign-in")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isWorking)

                Button(action: signIn) {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Sign in").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking || email.isEmpty)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.isStaticText)
                }

                Text("Uses the API's dev_login route, which does not exist in production.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        private func signIn() {
            isWorking = true
            errorMessage = nil
            Task {
                do {
                    try await environment.session.signInWithDevLogin(email: email)
                } catch let error as APIError {
                    errorMessage = error.message
                } catch {
                    errorMessage = error.localizedDescription
                }
                isWorking = false
            }
        }
    #endif
}
