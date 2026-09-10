import Foundation
import GoogleSignIn
import LacticCore
#if canImport(UIKit)
    import UIKit
#endif

/// Signs a user in with Google and hands the resulting ID token to the API.
///
/// The API verifies that token against a **single** audience — whatever
/// `GOOGLE_CLIENT_ID` is set to, which is the web client
/// (`google_verifier.rb:5`). Configuring `serverClientID` here makes Google
/// issue the ID token with `aud` set to that server client rather than the iOS
/// one, so the existing backend accepts it unchanged. Both clients must live in
/// the same Google Cloud project for that to hold.
///
/// This is an assumption worth checking rather than trusting: `audience(of:)`
/// exposes the claim so the first real token can be inspected. If it turns out
/// to carry the iOS client id, the fix is widening the verifier to a list.
public enum GoogleSignInProvider {
    public enum Failure: Error, Equatable {
        case notConfigured
        case cancelled
        case noPresenter
        case missingIDToken
    }

    /// Reads `GIDClientID` and `GIDServerClientID` from the bundle, so the ids
    /// live in the xcconfig alongside the URL scheme that has to match them
    /// rather than being duplicated in source.
    public static func configure(bundle: Bundle = .main) throws {
        guard let clientID = bundle.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty
        else { throw Failure.notConfigured }

        let serverClientID = bundle.object(forInfoDictionaryKey: "GIDServerClientID") as? String
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID?.isEmpty == false ? serverClientID : nil
        )
    }

    /// Handles the callback Google sends back through the app's URL scheme.
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// Restores a previous Google session on launch. Not what keeps the user
    /// signed in — that is the refresh token in the keychain — but it lets
    /// Google reissue an ID token without another consent screen.
    public static func restorePreviousSignIn() async {
        _ = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    #if canImport(UIKit)
        /// Presents the Google flow and returns the ID token to send to
        /// `POST /auth`.
        @MainActor
        public static func idToken() async throws -> String {
            try configure()

            guard let presenter = topViewController() else { throw Failure.noPresenter }

            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
                guard let token = result.user.idToken?.tokenString else {
                    throw Failure.missingIDToken
                }
                return token
            } catch {
                throw isCancellation(error) ? Failure.cancelled : error
            }
        }

        public static func signOut() {
            GIDSignIn.sharedInstance.signOut()
        }

        /// Backing out of Google's sheet arrives as a domain error rather than
        /// `CancellationError`, and is not worth reporting to the user.
        private static func isCancellation(_ error: any Error) -> Bool {
            let error = error as NSError
            return error.domain == kGIDSignInErrorDomain
                && error.code == GIDSignInError.canceled.rawValue
        }

        /// Google needs a presenter, and there is no environment hook for one.
        @MainActor
        private static func topViewController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var controller = scene?.keyWindow?.rootViewController
            while let presented = controller?.presentedViewController {
                controller = presented
            }
            return controller
        }
    #endif

    /// The `aud` claim of a Google ID token, read without verifying it.
    ///
    /// Only for confirming which client the token was issued for. Verification
    /// is the API's job and must stay there — a client that trusts its own
    /// unverified decode is a client that can be handed any token at all.
    public static func audience(of idToken: String) -> String? {
        let segments = idToken.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["aud"] as? String
    }
}
