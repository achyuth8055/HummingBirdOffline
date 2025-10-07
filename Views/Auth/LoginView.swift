import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var busy = false
    @State private var showGoogleHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome Back")
                        .font(HBFont.heading(32))
                    Text("Sign in to continue")
                        .font(HBFont.body(15))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

                VStack(spacing: 16) {
                    TextField("Email", text: $authVM.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    SecureField("Password", text: $authVM.password)
                        .textContentType(.password)
                        .padding()
                        .background(Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }

                if let err = authVM.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                            .font(HBFont.body(13))
                    }
                    .foregroundColor(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    Haptics.light()
                    Task { busy = true; await authVM.signIn(); busy = false }
                } label: {
                    HStack(spacing: 8) {
                        if busy {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                        Text(busy ? "Signing In..." : "Sign In")
                            .font(HBFont.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentGreen)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(busy || authVM.email.isEmpty || authVM.password.isEmpty)
                .opacity((busy || authVM.email.isEmpty || authVM.password.isEmpty) ? 0.6 : 1)

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(HBFont.body(14))
                        .foregroundColor(.secondaryText)
                    NavigationLink {
                        SignupView()
                    } label: {
                        Text("Sign Up")
                            .font(HBFont.body(14, weight: .semibold))
                            .foregroundColor(.accentGreen)
                    }
                }
                .padding(.top, 8)

                HStack {
                    Rectangle()
                        .fill(Color.secondaryText.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(HBFont.body(12, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 12)
                    Rectangle()
                        .fill(Color.secondaryText.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)

                Button {
                    Haptics.light()
                    if let vc = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                        .first {
                        Task { await authVM.signInWithGoogle(presenting: vc) }
                    } else {
                        showGoogleHelp = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Continue with Google")
                            .font(HBFont.body(16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.secondaryBackground)
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .alert("Google Sign-In Setup", isPresented: $showGoogleHelp) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Google Sign-In is configured in your Info.plist. Make sure you have added GoogleSignIn SDK via Swift Package Manager.")
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
}



