import Foundation
import UIKit
import SwiftData
import Combine
#if canImport(MSAL)
import MSAL
#endif

// MARK: - OneDrive Service Manager (Stub)
// Placeholder implementation for Microsoft OneDrive using Microsoft Graph API.
// Real implementation requires MSAL authentication (OAuth 2) and Graph requests.

@MainActor
final class OneDriveServiceManager: ObservableObject {
    static let shared = OneDriveServiceManager()
    
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var accountName: String? = nil
    @Published private(set) var items: [DriveItem] = []
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    private let tokenKey = "HBOneDriveAuthToken"
    
    private init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            isAuthorized = true
            accountName = "user@outlook.com"
        }
    }
    
    struct DriveItem: Identifiable, Hashable {
        enum FileType { case audio, folder, other }
        let id: String
        let name: String
        let size: Int64?
        let isFolder: Bool
        let downloadURL: String?
        
        var type: FileType {
            if isFolder { return .folder }
            let lower = name.lowercased()
            if lower.hasSuffix(".mp3") || lower.hasSuffix(".m4a") || lower.hasSuffix(".wav") || lower.hasSuffix(".flac") { return .audio }
            return .other
        }
    }
    
    enum OneDriveError: Error, LocalizedError {
        case authFailed, notAuthorized, network, downloadFailed
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Unable to authorize OneDrive"
            case .notAuthorized: return "Please connect OneDrive first"
            case .network: return "Network error communicating with OneDrive"
            case .downloadFailed: return "Failed to download file"
            }
        }
    }
    
    func authorize(presenting: UIViewController? = nil) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        #if canImport(MSAL)
        do {
            // Expect values to be provided via Info.plist or constants
            guard let clientID = Bundle.main.object(forInfoDictionaryKey: "MSAL_CLIENT_ID") as? String,
                  let authorityURLString = Bundle.main.object(forInfoDictionaryKey: "MSAL_AUTHORITY") as? String,
                  let authorityURL = URL(string: authorityURLString) else {
                throw OneDriveError.authFailed
            }
            let authority = try MSALAADAuthority(url: authorityURL)
            let config = MSALPublicClientApplicationConfig(clientId: clientID, redirectUri: nil, authority: authority)
            let app = try MSALPublicClientApplication(configuration: config)
            let params = MSALInteractiveTokenParameters(scopes: ["User.Read", "Files.Read", "Files.ReadWrite"], webviewParameters: MSALWebviewParameters(authPresentationViewController: presenting ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.rootViewController ?? UIViewController()))
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                app.acquireToken(with: params) { res, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let res { continuation.resume(returning: res) }
                    else { continuation.resume(throwing: OneDriveError.authFailed) }
                }
            }
            let token = result.accessToken
            UserDefaults.standard.set(token, forKey: tokenKey)
            isAuthorized = true
            accountName = result.account.username
            return true
        } catch {
            print("OneDrive auth error: \(error)")
            lastError = error
            return false
        }
        #else
        // Fallback stub
        try? await Task.sleep(nanoseconds: 300_000_000)
        isAuthorized = true
        accountName = "stub@outlook.com"
        UserDefaults.standard.set("mock-onedrive-token", forKey: tokenKey)
        return true
        #endif
    }
    
    func signOut() {
        isAuthorized = false
        accountName = nil
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    func refreshItems() async throws {
        guard isAuthorized else { throw OneDriveError.notAuthorized }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        // TODO: Graph API call: GET /me/drive/root/children?select=id,name,size,@microsoft.graph.downloadUrl
        try? await Task.sleep(nanoseconds: 500_000_000)
        items = mockItems()
    }
    
    func download(item: DriveItem, to destinationFolder: URL) async throws -> URL {
        guard isAuthorized else { throw OneDriveError.notAuthorized }
        guard item.type == .audio else { throw OneDriveError.downloadFailed }
        isLoading = true
        defer { isLoading = false }
        // TODO: Use item @microsoft.graph.downloadUrl to fetch bytes and write to dest
        try? await Task.sleep(nanoseconds: 500_000_000)
        let dest = destinationFolder.appendingPathComponent(item.name)
        if !FileManager.default.fileExists(atPath: dest.path) {
            FileManager.default.createFile(atPath: dest.path, contents: Data(), attributes: nil)
        }
        return dest
    }
    
    private func mockItems() -> [DriveItem] {
        [
            DriveItem(id: "od1", name: "Chill Vibes.mp3", size: 4_300_000, isFolder: false, downloadURL: "https://example.com/od1"),
            DriveItem(id: "od2", name: "Interviews", size: nil, isFolder: true, downloadURL: nil),
            DriveItem(id: "od3", name: "SynthWave.m4a", size: 6_800_000, isFolder: false, downloadURL: "https://example.com/od3")
        ]
    }
}
