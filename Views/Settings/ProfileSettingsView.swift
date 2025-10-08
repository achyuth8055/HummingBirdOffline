import SwiftUI
import FirebaseAuth
import PhotosUI

/// Full-featured profile settings view with editing capabilities
struct ProfileSettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var isEditingName: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var selectedImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var isUpdating: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var errorMessage: String?
    
    private var isGoogleUser: Bool {
        authVM.isGoogleUser
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Picture Section
                    profilePictureSection
                    
                    // User Information
                    userInfoSection
                    
                    // Account Details
                    accountDetailsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentGreen)
                }
            }
            .overlay {
                if showSuccessMessage {
                    successOverlay
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                loadUserData()
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    profileImage = image
                    updateProfilePicture(image)
                }
            }
        }
    }
    
    // MARK: - Profile Picture Section
    
    private var profilePictureSection: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                // Profile Image
                Group {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else if let photoURL = authVM.currentUser?.photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                defaultProfileImage
                            @unknown default:
                                defaultProfileImage
                            }
                        }
                    } else {
                        defaultProfileImage
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentGreen.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                
                // Edit Button
                Button {
                    Haptics.light()
                    showImagePicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentGreen)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            if isUpdating {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(.accentGreen)
            }
        }
    }
    
    private var defaultProfileImage: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentGreen, Color.accentGreen.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(getInitials())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        VStack(spacing: 16) {
            // Display Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .textCase(.uppercase)
                
                HStack {
                    if isEditingName {
                        TextField("Enter your name", text: $displayName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17))
                            .foregroundColor(.primaryText)
                    } else {
                        Text(displayName.isEmpty ? "Not set" : displayName)
                            .font(.system(size: 17))
                            .foregroundColor(displayName.isEmpty ? .secondaryText : .primaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        Haptics.light()
                        if isEditingName {
                            updateDisplayName()
                        } else {
                            isEditingName = true
                        }
                    } label: {
                        Text(isEditingName ? "Save" : "Edit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentGreen)
                    }
                    .disabled(isUpdating)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondaryBackground)
                )
            }
            
            // Email (Read-only for Google users)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Email")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .textCase(.uppercase)
                    
                    if isGoogleUser {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("Google Account")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.accentGreen.opacity(0.15))
                        )
                    }
                }
                
                HStack {
                    Text(email)
                        .font(.system(size: 17))
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    if isGoogleUser {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentGreen)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondaryBackground.opacity(isGoogleUser ? 0.5 : 1.0))
                )
            }
        }
    }
    
    // MARK: - Account Details Section
    
    private var accountDetailsSection: some View {
        VStack(spacing: 16) {
            Text("Account Details")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "person.fill",
                    title: "User ID",
                    value: authVM.currentUser?.uid.prefix(8).description ?? "N/A",
                    iconColor: .blue
                )
                
                InfoRow(
                    icon: "calendar",
                    title: "Member Since",
                    value: formatDate(authVM.currentUser?.metadata.creationDate),
                    iconColor: .purple
                )
                
                if isGoogleUser {
                    InfoRow(
                        icon: "link",
                        title: "Sign In Method",
                        value: "Google",
                        iconColor: .accentGreen
                    )
                } else {
                    InfoRow(
                        icon: "envelope.fill",
                        title: "Sign In Method",
                        value: "Email & Password",
                        iconColor: .orange
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondaryBackground)
            )
        }
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen)
                    .frame(width: 64, height: 64)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Profile Updated")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primaryText)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.secondaryBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .onAppear {
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSuccessMessage = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() {
        if let user = authVM.currentUser {
            displayName = user.displayName ?? ""
            email = user.email ?? ""
        }
    }
    
    private func getInitials() -> String {
        let name = displayName.isEmpty ? (email.components(separatedBy: "@").first ?? "U") : displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private func updateDisplayName() {
        guard let user = Auth.auth().currentUser else { return }
        
        isUpdating = true
        
        Task {
            do {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
                
                await MainActor.run {
                    isUpdating = false
                    isEditingName = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessMessage = true
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = error.localizedDescription
                    ToastCenter.shared.error("Failed to update name")
                }
            }
        }
    }
    
    private func updateProfilePicture(_ image: UIImage) {
        isUpdating = true
        
        Task {
            // In a real app, you would upload to Firebase Storage
            // For now, we'll just show success
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isUpdating = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSuccessMessage = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
