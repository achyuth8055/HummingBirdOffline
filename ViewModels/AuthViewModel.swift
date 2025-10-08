// ViewModels/AuthViewModel.swift
import Foundation
import FirebaseAuth
import Combine
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
import FirebaseCore
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    // Inputs
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""

    // Outputs
    @Published var userSession: FirebaseAuth.User? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // Enhanced auth awareness properties
    @Published var currentUser: FirebaseAuth.User? = nil
    
    // Computed properties for auth awareness
    var isGoogleUser: Bool {
        guard let user = currentUser else { return false }
        return user.providerData.contains { $0.providerID == "google.com" }
    }
    
    var userEmail: String {
        return currentUser?.email ?? ""
    }
    
    var isAuthenticated: Bool {
        return currentUser != nil
    }

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.userSession = user
            self?.currentUser = user
        }
        // Check if there's already a signed-in user
        self.userSession = Auth.auth().currentUser
        self.currentUser = Auth.auth().currentUser
    }
    
    deinit { 
        if let handle { 
            Auth.auth().removeStateDidChangeListener(handle) 
        } 
    }

    func signIn() async {
        errorMessage = nil
        isLoading = true
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            self.currentUser = result.user
        } catch {
            self.errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func signUp() async {
        errorMessage = nil
        isLoading = true
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // set displayName
            if !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try await change.commitChanges()
            }
            self.userSession = Auth.auth().currentUser
            self.currentUser = Auth.auth().currentUser
        } catch {
            self.errorMessage = "Sign up failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func signOut() {
        errorMessage = nil
        PlayerViewModel.shared.clearQueueAndUI()
        do { 
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch { 
            self.errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    // Enhanced Google Sign-In with better error handling and debugging
    func signInWithGoogle(presenting: UIViewController) async {
        errorMessage = nil
        isLoading = true
        
        #if canImport(GoogleSignIn)
        do {
            // Configure Google Sign-In
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                errorMessage = "Firebase client ID not found. Please check GoogleService-Info.plist"
                isLoading = false
                return
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Perform sign in
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token from Google Sign-In"
                isLoading = false
                return
            }
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            self.userSession = authResult.user
            self.currentUser = authResult.user
            
            // Success feedback
            ToastCenter.shared.success("Signed in as \(authResult.user.email ?? "User")")
            
        } catch let error as NSError {
            // Handle specific Google Sign-In errors
            if error.domain == "com.google.GIDSignIn" {
                switch error.code {
                case -1: // Cancelled by user
                    errorMessage = "Sign in was cancelled"
                case -2: // Keychain error
                    errorMessage = "Keychain error. Please try again"
                case -4: // No current user
                    errorMessage = "No Google account selected"
                case -5: // EMM error
                    errorMessage = "Google Sign-In configuration error"
                default:
                    errorMessage = "Google Sign-In error: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Authentication failed: \(error.localizedDescription)"
            }
        }
        #else
        errorMessage = "Google Sign-In SDK not available. Please add GoogleSignIn via Swift Package Manager."
        #endif
        
        isLoading = false
    }
    
    // Check Google Sign-In availability
    func isGoogleSignInAvailable() -> Bool {
        #if canImport(GoogleSignIn)
        return true
        #else
        return false
        #endif
    }
}
