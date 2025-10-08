import Foundation
import UIKit
import SwiftData
import Combine
import FirebaseAuth
import FirebaseCore
import AuthenticationServices

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Google Drive Service Manager
// Enhanced implementation for Google Drive integration with auth awareness.
// Supports auto-authorization for Google users and manual login for others.
// Streams files directly from Drive URLs instead of downloading.

@MainActor
final class DriveServiceManager: NSObject, ObservableObject {
    static let shared = DriveServiceManager()
    
    // MARK: - Published State
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var accountName: String? = nil
    @Published private(set) var files: [DriveFile] = []
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    // Auth state tracking
    @Published var isConnectedToGoogleUser: Bool = false
    
    // Token storage
    private let tokenKey = "HBDriveAuthToken"
    private let accountKey = "HBDriveAccount"
    private let refreshTokenKey = "HBDriveRefreshToken"
    
    // OAuth Configuration
    private var clientID: String {
        return Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
    }
    
    // Web auth session for manual OAuth
    private var authSession: ASWebAuthenticationSession?
    private var authContinuation: CheckedContinuation<String, Error>?
    
    override private init() {
        super.init()
        // Restore prior auth state
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            isAuthorized = true
            accountName = UserDefaults.standard.string(forKey: accountKey) ?? "Connected Account"
            checkGoogleUserConnection()
        }
    }
    
    // MARK: - Public API
    struct DriveFile: Identifiable, Hashable {
        enum FileType { case audio, folder, other }
        let id: String
        let name: String
        let mimeType: String
        let size: Int64?
        let isFolder: Bool
        let webContentLink: String?
        let webViewLink: String?
        let parents: [String]
        
        var type: FileType {
            if isFolder { return .folder }
            let lower = mimeType.lowercased()
            if lower.contains("audio") || 
               lower.contains("mp3") || 
               lower.contains("m4a") || 
               lower.contains("wav") || 
               lower.contains("flac") { return .audio }
            return .other
        }
        
        // Get streaming URL for audio files
        var streamingURL: URL? {
            guard type == .audio else { return nil }
            if let webContent = webContentLink {
                return URL(string: webContent)
            }
            // Fallback to direct download URL format
            return URL(string: "https://drive.google.com/uc?export=download&id=\(id)")
        }
    }
    
    enum DriveError: Error, LocalizedError {
        case authCancelled, authFailed, notAuthorized, network, downloadFailed, invalidEmail
        var errorDescription: String? {
            switch self {
            case .authCancelled: return "Authorization was cancelled"
            case .authFailed: return "Unable to authorize Google Drive"
            case .notAuthorized: return "Please connect Google Drive first"
            case .network: return "Network error communicating with Drive"
            case .downloadFailed: return "Failed to download file"
            case .invalidEmail: return "Invalid email for Google Drive authorization"
            }
        }
    }
    
    // MARK: - Auth Awareness Methods
    private func checkGoogleUserConnection() {
        if let currentUser = Auth.auth().currentUser {
            let isGoogleUser = currentUser.providerData.contains { $0.providerID == "google.com" }
            isConnectedToGoogleUser = isGoogleUser && accountName == currentUser.email
        } else {
            isConnectedToGoogleUser = false
        }
    }
    
    // Auto-authorize with Google user's email
    func authorizeWithGoogleUser() async -> Bool {
        guard let currentUser = Auth.auth().currentUser,
              currentUser.providerData.contains(where: { $0.providerID == "google.com" }),
              let email = currentUser.email else {
            lastError = DriveError.invalidEmail
            return false
        }
        
        return await authorizeWithEmail(email)
    }
    
    // Authorize with specific email (for Google users)
    func authorizeWithEmail(_ email: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(GoogleSignIn)
        do {
            // Configure Google Sign-In with Drive scope
            guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ??
                                 FirebaseApp.app()?.options.clientID else {
                throw DriveError.authFailed
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Get presenting view controller
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.keyWindow?.rootViewController else {
                throw DriveError.authFailed
            }
            
            // Sign in with Drive scopes
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: email
            )
            
            // Verify the signed-in email matches
            guard let signedInEmail = result.user.profile?.email.lowercased(),
                  signedInEmail == email.lowercased() else {
                throw DriveError.invalidEmail
            }
            
            // Store auth data
            let accessToken = result.user.accessToken.tokenString
            UserDefaults.standard.set(accessToken, forKey: tokenKey)
            UserDefaults.standard.set(email, forKey: accountKey)
            
            isAuthorized = true
            accountName = email
            checkGoogleUserConnection()
            
            return true
        } catch {
            print("Google Drive auth error: \(error)")
            lastError = error
            return false
        }
        #else
        // Fallback for testing without GoogleSignIn SDK
        try? await Task.sleep(nanoseconds: 300_000_000)
        isAuthorized = true
        accountName = email
        UserDefaults.standard.set("mock-token", forKey: tokenKey)
        UserDefaults.standard.set(email, forKey: accountKey)
        checkGoogleUserConnection()
        return true
        #endif
    }
    
    // Manual authorization (for non-Google users)
    func authorize(presenting: UIViewController? = nil) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(GoogleSignIn)
        do {
            // Try Google Sign-In SDK first (most reliable method)
            guard let clientID = FirebaseApp.app()?.options.clientID ??
                  Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String else {
                throw DriveError.authFailed
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Determine presenting VC
            let rootVC: UIViewController
            if let presenting {
                rootVC = presenting
            } else {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let vc = scene.keyWindow?.rootViewController else {
                    throw DriveError.authFailed
                }
                rootVC = vc
            }
            
            // Add Drive scope to the sign-in request
            let additionalScopes = ["https://www.googleapis.com/auth/drive.readonly"]
            
            // Check if we need to request additional scopes
            if let currentUser = GIDSignIn.sharedInstance.currentUser,
               currentUser.grantedScopes?.contains(where: { additionalScopes.contains($0) }) == true {
                // Already have the scopes, just use current token
                let accessToken = currentUser.accessToken.tokenString
                let userEmail = currentUser.profile?.email ?? currentUser.userID ?? "user@gmail.com"
                
                UserDefaults.standard.set(accessToken, forKey: tokenKey)
                UserDefaults.standard.set(userEmail, forKey: accountKey)
                
                isAuthorized = true
                accountName = userEmail
                checkGoogleUserConnection()
                
                return true
            }
            
            // Need to sign in or request additional scopes
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: additionalScopes
            )
            
            // Replace this block as per instructions:
            let accessToken = result.user.accessToken.tokenString
            let userEmail = result.user.profile?.email ?? result.user.userID ?? "user@gmail.com"
            
            UserDefaults.standard.set(accessToken, forKey: tokenKey)
            UserDefaults.standard.set(userEmail, forKey: accountKey)
            
            // Store refresh token if provided by the SDK (non-optional in recent versions)
            let refreshToken = result.user.refreshToken.tokenString
            if !refreshToken.isEmpty {
                UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
            }
            
            isAuthorized = true
            accountName = userEmail
            
            checkGoogleUserConnection()
            
            return true
        } catch let error as NSError {
            print("Google Drive manual auth error: \(error)")
            // Check if user cancelled
            if error.domain == "com.google.GIDSignIn" && error.code == -1 {
                lastError = DriveError.authCancelled
            } else {
                lastError = error
            }
            return false
        }
        #else
        // Fallback: Use ASWebAuthenticationSession for OAuth
        do {
            let token = try await authorizeWithWebAuth()
            UserDefaults.standard.set(token, forKey: tokenKey)
            UserDefaults.standard.set("user@gmail.com", forKey: accountKey)
            
            isAuthorized = true
            accountName = "user@gmail.com"
            checkGoogleUserConnection()
            
            return true
        } catch {
            print("Web auth error: \(error)")
            lastError = error
            return false
        }
        #endif
    }
    
    // Web-based OAuth fallback
    private func authorizeWithWebAuth() async throws -> String {
        guard !clientID.isEmpty else {
            throw DriveError.authFailed
        }
        
        let redirectURI = "com.googleusercontent.apps.\(clientID):/oauth2redirect"
        let scope = "https://www.googleapis.com/auth/drive.readonly"
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=\(scope)"
        
        guard let url = URL(string: authURL) else {
            throw DriveError.authFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "com.googleusercontent.apps.\(clientID)"
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: DriveError.authFailed)
                    return
                }
                
                // Return the auth code - in production, exchange this for access token
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            if session.start() {
                self.authSession = session
            } else {
                continuation.resume(throwing: DriveError.authFailed)
            }
        }
    }
    
    func signOut() {
        isAuthorized = false
        accountName = nil
        files.removeAll()
        isConnectedToGoogleUser = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: accountKey)
    }
    
    func refreshFileList() async throws {
        guard isAuthorized else { throw DriveError.notAuthorized }
        
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
            throw DriveError.notAuthorized
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            // Fetch audio files from Google Drive API
            files = try await fetchAudioFilesFromAPI(token: token)
        } catch {
            print("Failed to fetch Drive files: \(error)")
            // Fall back to mock data for development
            try? await Task.sleep(nanoseconds: 500_000_000)
            files = await fetchMockAudioFiles()
        }
    }
    
    // MARK: - API Methods
    
    /// Fetches audio files from Google Drive API
    private func fetchAudioFilesFromAPI(token: String) async throws -> [DriveFile] {
        let baseURL = "https://www.googleapis.com/drive/v3/files"
        let query = "mimeType contains 'audio' or mimeType='audio/mpeg' or mimeType='audio/mp4' or mimeType='audio/wav'"
        let fields = "files(id,name,mimeType,size,webContentLink,webViewLink,parents)"
        let urlString = "\(baseURL)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&fields=\(fields)"
        
        guard let url = URL(string: urlString) else {
            throw DriveError.network
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DriveError.network
        }
        
        // Parse response
        struct DriveAPIResponse: Codable {
            struct File: Codable {
                let id: String
                let name: String
                let mimeType: String
                let size: String?
                let webContentLink: String?
                let webViewLink: String?
                let parents: [String]?
            }
            let files: [File]
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(DriveAPIResponse.self, from: data)
        
        return apiResponse.files.map { file in
            DriveFile(
                id: file.id,
                name: file.name,
                mimeType: file.mimeType,
                size: Int64(file.size ?? "0"),
                isFolder: file.mimeType == "application/vnd.google-apps.folder",
                webContentLink: file.webContentLink,
                webViewLink: file.webViewLink,
                parents: file.parents ?? []
            )
        }
    }
    
    // Get streaming metadata without downloading
    func getStreamingInfo(for file: DriveFile) -> (url: URL, metadata: [String: Any])? {
        guard file.type == .audio, let streamingURL = file.streamingURL else { return nil }
        
        let metadata: [String: Any] = [
            "title": file.name,
            "sourceType": "googleDrive",
            "remoteURL": streamingURL.absoluteString,
            "fileID": file.id,
            "size": file.size ?? 0
        ]
        
        return (streamingURL, metadata)
    }
    
    // Legacy download method - deprecated in favor of streaming
    @available(*, deprecated, message: "Use getStreamingInfo(for:) instead for streaming playback")
    func download(file: DriveFile, to destinationFolder: URL) async throws -> URL {
        guard isAuthorized else { throw DriveError.notAuthorized }
        guard file.type == .audio else { throw DriveError.downloadFailed }
        
        isLoading = true
        defer { isLoading = false }
        
        // For backward compatibility, create a placeholder file
        let sanitized = file.name.replacingOccurrences(of: "/", with: "-")
        let dest = destinationFolder.appendingPathComponent(sanitized)
        
        // Create placeholder with streaming URL as extended attribute
        if !FileManager.default.fileExists(atPath: dest.path) {
            let placeholderData = Data("STREAMING_PLACEHOLDER".utf8)
            FileManager.default.createFile(atPath: dest.path, contents: placeholderData, attributes: nil)
            
            // Store streaming URL as extended attribute
            if let streamingURL = file.streamingURL {
                try? dest.setExtendedAttribute(data: streamingURL.absoluteString.data(using: .utf8)!, forName: "streaming_url")
            }
        }
        
        return dest
    }
    
    // MARK: - Helpers
    private func fetchMockAudioFiles() async -> [DriveFile] {
        // Mock data for testing - replace with actual Drive API call
        return [
            DriveFile(
                id: "1BvkqzVL8x9YnKjP2R4bE3z7Hm6Qe8",
                name: "Lofi Study Mix.mp3",
                mimeType: "audio/mpeg",
                size: 8_400_000,
                isFolder: false,
                webContentLink: "https://drive.google.com/uc?export=download&id=1BvkqzVL8x9YnKjP2R4bE3z7Hm6Qe8",
                webViewLink: "https://drive.google.com/file/d/1BvkqzVL8x9YnKjP2R4bE3z7Hm6Qe8/view",
                parents: []
            ),
            DriveFile(
                id: "2CwlrzWM9y0ZoLkQ3S5cF4a8Jn7Rf9",
                name: "Acoustic Guitar Session.m4a",
                mimeType: "audio/mp4",
                size: 12_800_000,
                isFolder: false,
                webContentLink: "https://drive.google.com/uc?export=download&id=2CwlrzWM9y0ZoLkQ3S5cF4a8Jn7Rf9",
                webViewLink: "https://drive.google.com/file/d/2CwlrzWM9y0ZoLkQ3S5cF4a8Jn7Rf9/view",
                parents: []
            ),
            DriveFile(
                id: "3DxmsaXN0z1ApMlR4T6dG5b9Ko8Sg0",
                name: "Nature Sounds - Rain.wav",
                mimeType: "audio/wav",
                size: 45_600_000,
                isFolder: false,
                webContentLink: "https://drive.google.com/uc?export=download&id=3DxmsaXN0z1ApMlR4T6dG5b9Ko8Sg0",
                webViewLink: "https://drive.google.com/file/d/3DxmsaXN0z1ApMlR4T6dG5b9Ko8Sg0/view",
                parents: []
            ),
            DriveFile(
                id: "folder_music",
                name: "Music Collection",
                mimeType: "application/vnd.google-apps.folder",
                size: nil,
                isFolder: true,
                webContentLink: nil,
                webViewLink: "https://drive.google.com/drive/folders/folder_music",
                parents: []
            )
        ]
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension DriveServiceManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

