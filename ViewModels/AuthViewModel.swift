// ViewModels/AuthViewModel.swift
import Foundation
import FirebaseAuth
import Combine
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    // Inputs
    @Published var displayName: String = ""     // NEW
    @Published var email: String = ""
    @Published var password: String = ""

    // Outputs
    @Published var userSession: FirebaseAuth.User? = nil
    @Published var errorMessage: String? = nil

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userSession = user
        }
    }
    deinit { if let handle { Auth.auth().removeStateDidChangeListener(handle) } }

    func signIn() async {
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
        } catch { self.errorMessage = error.localizedDescription }
    }

    func signUp() async {
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // set displayName
            if !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try await change.commitChanges()
            }
            self.userSession = Auth.auth().currentUser
        } catch { self.errorMessage = error.localizedDescription }
    }

    func signOut() {
        errorMessage = nil
        PlayerViewModel.shared.clearQueueAndUI()
        do { try Auth.auth().signOut(); self.userSession = nil }
        catch { self.errorMessage = error.localizedDescription }
    }

    // Optional: Google Sign-In (works once the SDK is added through SPM)
    func signInWithGoogle(presenting: UIViewController) async {
        errorMessage = nil
        #if canImport(GoogleSignIn)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            self.userSession = authResult.user
        } catch { self.errorMessage = error.localizedDescription }
        #endif
    }
}
