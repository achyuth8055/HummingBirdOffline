// Views/Auth/SignupView.swift
import SwiftUI
import UIKit

struct SignupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showGoogleHelp = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(HBFont.heading(28))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)

            VStack(spacing: 14) {
                TextField("Your name", text: $authVM.displayName)
                    .textInputAutocapitalization(.words)
                    .padding().background(Color.secondaryBackground, in: RoundedRectangle(cornerRadius: 12))

                TextField("Email", text: $authVM.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding().background(Color.secondaryBackground, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $authVM.password)
                    .textContentType(.newPassword)
                    .padding().background(Color.secondaryBackground, in: RoundedRectangle(cornerRadius: 12))
            }

            if let err = authVM.errorMessage {
                Text(err).font(.footnote).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await authVM.signUp() }
            } label: {
                HStack { 
                    if authVM.isLoading { 
                        ProgressView().tint(.black) 
                    }
                    Text("Sign Up").bold() 
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.accentGreen).foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(authVM.isLoading)

            // Google Sign-Up
            Button {
                if !authVM.isGoogleSignInAvailable() {
                    showGoogleHelp = true
                    return
                }
                if let vc = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    Task { await authVM.signInWithGoogle(presenting: vc) }
                } else {
                    showGoogleHelp = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                    if authVM.isLoading {
                        ProgressView()
                        Text("Signing up...").bold()
                    } else {
                        Text("Sign up with Google").bold()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(authVM.isLoading)
            .alert("Google Sign-In Setup", isPresented: $showGoogleHelp) {
                Button("OK", role: .cancel) { }
            } message: {
                if authVM.isGoogleSignInAvailable() {
                    Text("Google Sign-In is ready. If you encounter issues, please ensure GoogleService-Info.plist is properly configured.")
                } else {
                    Text("To enable this, add GoogleSignIn SDK via Swift Package Manager.")
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }
}
