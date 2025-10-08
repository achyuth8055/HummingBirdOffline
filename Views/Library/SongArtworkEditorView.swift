import SwiftUI
import SwiftData
import PhotosUI

/// View for editing custom artwork for individual songs
struct SongArtworkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let song: Song
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUpdating = false
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Current Artwork Display
                    artworkSection
                    
                    // Actions
                    actionsSection
                    
                    // Song Info
                    songInfoSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentGreen)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    updateArtwork(image)
                }
            }
            .overlay {
                if showSuccessMessage {
                    successOverlay
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Artwork Display
                if let artworkData = song.artworkData,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                } else {
                    // Default artwork with app logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentGreen.opacity(0.6), Color.accentGreen.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 280, height: 280)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
            }
            
            if isUpdating {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(.accentGreen)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Button {
                Haptics.light()
                showImagePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Choose from Photos")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentGreen)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isUpdating)
            
            if song.artworkData != nil {
                Button {
                    Haptics.light()
                    removeArtwork()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Remove Artwork")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.secondaryBackground)
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isUpdating)
            }
        }
    }
    
    // MARK: - Song Info Section
    
    private var songInfoSection: some View {
        VStack(spacing: 16) {
            Text("Song Details")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "music.note",
                    title: "Title",
                    value: song.title,
                    iconColor: .accentGreen
                )
                
                InfoRow(
                    icon: "person.fill",
                    title: "Artist",
                    value: song.artistName,
                    iconColor: .blue
                )
                
                InfoRow(
                    icon: "opticaldisc",
                    title: "Album",
                    value: song.albumName,
                    iconColor: .purple
                )
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
            
            Text("Artwork Updated")
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
    
    private func updateArtwork(_ image: UIImage) {
        isUpdating = true
        
        Task {
            // Resize image for optimal storage
            let resizedImage = image.resized(to: CGSize(width: 1024, height: 1024))
            
            if let data = resizedImage.jpegData(compressionQuality: 0.85) {
                await MainActor.run {
                    song.artworkData = data
                    
                    // Also update the album artwork if this song is part of an album
                    if let album = song.album, album.artworkData == nil {
                        album.artworkData = data
                    }
                    
                    try? modelContext.save()
                    
                    isUpdating = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessMessage = true
                    }
                }
            } else {
                await MainActor.run {
                    isUpdating = false
                    ToastCenter.shared.error("Failed to process image")
                }
            }
        }
    }
    
    private func removeArtwork() {
        isUpdating = true
        
        Task {
            await MainActor.run {
                song.artworkData = nil
                try? modelContext.save()
                
                isUpdating = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSuccessMessage = true
                }
            }
        }
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
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Song.self, configurations: config)
    
    let sampleSong = Song(
        title: "Sample Song",
        artistName: "Sample Artist",
        albumName: "Sample Album",
        duration: 180,
        filePath: "sample.mp3"
    )
    
    return SongArtworkEditorView(song: sampleSong)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
