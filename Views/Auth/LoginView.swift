import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showGoogleHelp = false
    @State private var isAppearing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome Back")
                        .font(HBFont.heading(32))
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                    Text("Sign in to continue")
                        .font(HBFont.body(15))
                        .foregroundColor(.secondaryText)
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
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
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                    
                    SecureField("Password", text: $authVM.password)
                        .textContentType(.password)
                        .padding()
                        .background(Color.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
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
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    Haptics.light()
                    Task { await authVM.signIn() }
                } label: {
                    HStack(spacing: 8) {
                        if authVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                        Text(authVM.isLoading ? "Signing In..." : "Sign In")
                            .font(HBFont.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentGreen)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty)
                .opacity((authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty) ? 0.6 : 1)
                .scaleEffect(isAppearing ? 1 : 0.95)
                .opacity(isAppearing ? 1 : 0)

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
                .opacity(isAppearing ? 1 : 0)

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
                .opacity(isAppearing ? 1 : 0)

                Button {
                    Haptics.light()
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
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        if authVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primaryText))
                            Text("Signing in...")
                                .font(HBFont.body(16, weight: .medium))
                        } else {
                            Text("Continue with Google")
                                .font(HBFont.body(16, weight: .medium))
                        }
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
                .disabled(authVM.isLoading)
                .opacity(authVM.isLoading ? 0.6 : (isAppearing ? 1 : 0))
                .offset(y: isAppearing ? 0 : 20)
                .alert("Google Sign-In Setup", isPresented: $showGoogleHelp) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if authVM.isGoogleSignInAvailable() {
                        Text("Google Sign-In is ready. If you encounter issues, please ensure GoogleService-Info.plist is properly configured.")
                    } else {
                        Text("Google Sign-In SDK is not available. Please add GoogleSignIn via Swift Package Manager to enable this feature.")
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAppearing = true
            }
        }
    }
}
