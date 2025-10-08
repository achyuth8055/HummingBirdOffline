# Cloud Integration Setup Guide
### HummingBirdOffline - Google Drive & OneDrive Configuration

This guide provides step-by-step instructions for configuring OAuth authentication for Google Drive and OneDrive in your HummingBirdOffline app.

---

## ✅ Google Drive Integration

### 1. Google Cloud Console Setup

1. **Create/Access Project:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing "HummingBirdOffline"

2. **Enable APIs:**
   - Navigate to **APIs & Services > Library**
   - Search for and enable:
     - ✓ Google Drive API
     - ✓ Google Sign-In API (if not already enabled)

3. **Configure OAuth Consent Screen:**
   - Go to **APIs & Services > OAuth consent screen**
   - Choose **External** (unless you have Google Workspace)
   - Fill in required fields:
     - App name: `HummingBirdOffline`
     - User support email: Your email
     - Developer contact email: Your email
   - Add scopes:
     - `https://www.googleapis.com/auth/drive.readonly`
     - `.../auth/userinfo.email`
     - `.../auth/userinfo.profile`
   - Add test users (for development)

4. **Create OAuth 2.0 Credentials:**
   - Go to **APIs & Services > Credentials**
   - Click **Create Credentials > OAuth 2.0 Client ID**
   - Application type: **iOS**
   - Name: `HummingBird iOS Client`
   - Bundle ID: `com.yourcompany.HummingBirdOffline` (match your app's bundle ID)
   - Copy the **Client ID** (format: `XXXXX-YYYYY.apps.googleusercontent.com`)

### 2. Info.plist Configuration

Add the following keys to your `Info.plist`:

```xml
<!-- Google Drive Configuration -->
<key>GOOGLE_CLIENT_ID</key>
<string>YOUR_CLIENT_ID_HERE.apps.googleusercontent.com</string>

<!-- URL Schemes for Google OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Reverse Client ID format -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID_HERE</string>
        </array>
    </dict>
</array>

<!-- Allow HTTP for Google OAuth (if needed for development) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>accounts.google.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### 3. Add GoogleSignIn SDK

**Swift Package Manager** (Recommended):
1. In Xcode: **File > Add Package Dependencies**
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Version: **7.0.0** or later
4. Add to target: **HummingBirdOffline**

**CocoaPods** (Alternative):
```ruby
pod 'GoogleSignIn', '~> 7.0'
```

### 4. Test Google Drive Connection

1. Build and run the app
2. Navigate to **Library > Import**
3. Tap **Google Drive > Connect**
4. Sign in with your Google account
5. Grant permissions to access Drive files
6. Select audio files to import

---

## ✅ OneDrive Integration

### 1. Azure Portal Setup

1. **Access Azure Portal:**
   - Go to [Azure Portal](https://portal.azure.com/)
   - Sign in with your Microsoft account

2. **Register Application:**
   - Navigate to **Azure Active Directory > App registrations**
   - Click **New registration**
   - Fill in details:
     - Name: `HummingBirdOffline`
     - Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
     - Redirect URI: Leave blank for now
   - Click **Register**

3. **Configure Authentication:**
   - In your app registration, go to **Authentication**
   - Click **Add a platform > iOS / macOS**
   - Enter Bundle ID: `com.yourcompany.HummingBirdOffline`
   - System will auto-generate redirect URI: `msauth.com.yourcompany.HummingBirdOffline://auth`
   - Check **Access tokens** and **ID tokens** under **Implicit grant**
   - Click **Configure**

4. **API Permissions:**
   - Go to **API permissions**
   - Click **Add a permission > Microsoft Graph**
   - Select **Delegated permissions**
   - Add these permissions:
     - ✓ `User.Read`
     - ✓ `Files.Read`
     - ✓ `Files.Read.All`
   - Click **Grant admin consent** (if you're admin)

5. **Copy Application (client) ID:**
   - Go to **Overview** tab
   - Copy the **Application (client) ID** (format: `12345678-abcd-efgh-ijkl-1234567890ab`)

### 2. Info.plist Configuration

Add the following keys to your `Info.plist`:

```xml
<!-- OneDrive/MSAL Configuration -->
<key>MSAL_CLIENT_ID</key>
<string>YOUR_APPLICATION_CLIENT_ID_HERE</string>

<key>MSAL_AUTHORITY</key>
<string>https://login.microsoftonline.com/common</string>

<!-- URL Schemes for Microsoft OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <!-- Merge with existing Google entry if present -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.HummingBirdOffline</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.yourcompany.HummingBirdOffline</string>
        </array>
    </dict>
</array>

<!-- Whitelist Microsoft auth domains -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

### 3. Add MSAL SDK

**Swift Package Manager** (Recommended):
1. In Xcode: **File > Add Package Dependencies**
2. Enter URL: `https://github.com/AzureAD/microsoft-authentication-library-for-objc`
3. Version: **1.2.0** or later
4. Add to target: **HummingBirdOffline**

**CocoaPods** (Alternative):
```ruby
pod 'MSAL', '~> 1.2'
```

### 4. Test OneDrive Connection

1. Build and run the app
2. Navigate to **Library > Import**
3. Tap **OneDrive > Connect**
4. Sign in with your Microsoft account
5. Grant permissions to access OneDrive files
6. Select audio files to import

---

## 📝 Complete Info.plist Example

Here's a combined example with all required keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Google Drive -->
    <key>GOOGLE_CLIENT_ID</key>
    <string>123456789-abcdefg.apps.googleusercontent.com</string>
    
    <!-- OneDrive/MSAL -->
    <key>MSAL_CLIENT_ID</key>
    <string>12345678-abcd-1234-efgh-1234567890ab</string>
    
    <key>MSAL_AUTHORITY</key>
    <string>https://login.microsoftonline.com/common</string>
    
    <!-- URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- Google OAuth -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>com.googleusercontent.apps.123456789-abcdefg</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.123456789-abcdefg</string>
            </array>
        </dict>
        <!-- Microsoft OAuth -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>com.yourcompany.HummingBirdOffline</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>msauth.com.yourcompany.HummingBirdOffline</string>
            </array>
        </dict>
    </array>
    
    <!-- Microsoft auth whitelist -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>msauthv2</string>
        <string>msauthv3</string>
    </array>
    
    <!-- Network Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>accounts.google.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
            </dict>
            <key>login.microsoftonline.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

---

## 🔧 Troubleshooting

### Google Drive Issues

**Problem:** "Client ID not found" error
- ✓ Verify `GOOGLE_CLIENT_ID` in Info.plist matches Google Cloud Console
- ✓ Check GoogleService-Info.plist is added to project
- ✓ Ensure Firebase configuration is correct

**Problem:** Sign-in screen doesn't appear
- ✓ Verify URL scheme in Info.plist matches reversed Client ID
- ✓ Check GoogleSignIn SDK is properly installed
- ✓ Ensure app has internet connectivity

**Problem:** "Access Denied" after sign-in
- ✓ Add Drive API scope in Google Cloud Console OAuth consent screen
- ✓ Verify test users are added (for development)
- ✓ Request Drive permissions in code

### OneDrive Issues

**Problem:** "Invalid client" error
- ✓ Verify `MSAL_CLIENT_ID` in Info.plist matches Azure Portal App ID
- ✓ Check redirect URI in Azure Portal matches bundle ID
- ✓ Ensure authority URL is correct

**Problem:** Sign-in screen doesn't appear
- ✓ Verify URL scheme format: `msauth.{bundleId}://auth`
- ✓ Check MSAL SDK is properly installed
- ✓ Ensure `LSApplicationQueriesSchemes` includes msauth entries

**Problem:** "Insufficient permissions" error
- ✓ Add required Microsoft Graph permissions in Azure Portal
- ✓ Grant admin consent for permissions
- ✓ Sign out and sign in again

---

## 🎯 Testing Checklist

### Google Drive
- [ ] Can tap "Connect" and see Google sign-in page
- [ ] Can sign in with Google account
- [ ] Can see list of audio files from Drive
- [ ] Can select and import mp3/m4a/wav files
- [ ] Songs stream without downloading
- [ ] Auto-connect works for Google-authenticated users

### OneDrive
- [ ] Can tap "Connect" and see Microsoft sign-in page
- [ ] Can sign in with Microsoft account
- [ ] Can see list of audio files from OneDrive
- [ ] Can select and import audio files
- [ ] Songs stream without downloading

### General
- [ ] Import status shows success messages
- [ ] Imported songs appear in Library
- [ ] Songs play correctly from cloud URLs
- [ ] Network connectivity is required for playback
- [ ] Error messages are user-friendly

---

## 📱 User Experience Flow

### For Google Users (Signed in with Google)
1. User taps "Google Drive" in Import screen
2. System detects user is signed in with Google
3. Auto-connects to Drive using existing credentials
4. Shows "Connected (user@gmail.com)"
5. User can browse and import files immediately

### For Email/Password Users
1. User taps "Google Drive" in Import screen
2. Google Sign-In screen appears
3. User signs in with Google account
4. Grants Drive permissions
5. Can now browse and import files

### For OneDrive
1. User taps "OneDrive" in Import screen
2. Microsoft Sign-In screen appears
3. User signs in with Microsoft account
4. Grants OneDrive permissions
5. Can now browse and import files

---

## 🚀 Production Deployment

### Before App Store Submission

1. **Google Drive:**
   - Submit OAuth consent screen for verification
   - Remove test users limitation
   - Update privacy policy with Drive access details

2. **OneDrive:**
   - Ensure app registration is set to "multitenant"
   - Remove development restrictions
   - Update privacy policy with OneDrive access details

3. **App Store Connect:**
   - Declare "Music Services" capability
   - Explain cloud storage integration in review notes
   - Provide test account credentials if needed

---

## 📚 Additional Resources

- [Google Drive API Documentation](https://developers.google.com/drive/api/v3/about-sdk)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/api/overview)
- [MSAL iOS Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-overview)

---

## 💡 Best Practices

1. **Token Security:**
   - Never hardcode Client IDs in code
   - Use Keychain for sensitive data (consider migrating from UserDefaults)
   - Implement token refresh logic

2. **Error Handling:**
   - Provide clear error messages to users
   - Log errors for debugging
   - Handle network failures gracefully

3. **Performance:**
   - Cache file lists to reduce API calls
   - Implement pagination for large libraries
   - Use background tasks for heavy operations

4. **User Privacy:**
   - Only request necessary permissions
   - Explain why permissions are needed
   - Provide sign-out option

---

**Need Help?** 
- Check the troubleshooting section
- Review console logs for detailed error messages
- Ensure all configuration steps are completed correctly
