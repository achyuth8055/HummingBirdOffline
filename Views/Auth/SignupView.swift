// Views/Auth/SignupView.swift
import SwiftUI
import UIKit

struct SignupView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showGoogleHelp = false
    @State private var isAppearing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(HBFont.heading(32))
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                    Text("Join HummingBird today")
                        .font(HBFont.body(15))
                        .foregroundColor(.secondaryText)
                        .opacity(isAppearing ? 1 : 0)
                        .offset(y: isAppearing ? 0 : 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

                VStack(spacing: 16) {
                    TextField("Your name", text: $authVM.displayName)
                        .textInputAutocapitalization(.words)
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
                        .textContentType(.newPassword)
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
                    Task { await authVM.signUp() }
                } label: {
                    HStack(spacing: 8) {
                        if authVM.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                        Text(authVM.isLoading ? "Creating Account..." : "Sign Up")
                            .font(HBFont.body(16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentGreen)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty || authVM.displayName.isEmpty)
                .opacity((authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty || authVM.displayName.isEmpty) ? 0.6 : 1)
                .scaleEffect(isAppearing ? 1 : 0.95)
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
                            Text("Signing up...")
                                .font(HBFont.body(16, weight: .medium))
                        } else {
                            Text("Sign up with Google")
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
                        Text("To enable this, add GoogleSignIn SDK via Swift Package Manager.")
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.primaryBackground.ignoresSafeArea())
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isAppearing = true
            }
        }
    }
}
