# ScaleCloud iOS Implementation

## Overview

ScaleCloud is a custom iOS client based on Nextcloud iOS that integrates Tailscale networking to enable secure access to private Nextcloud instances over a Tailscale network (tailnet). This document describes all modifications made to create ScaleCloud from the base Nextcloud iOS client.

## Architecture

### Component Stack

```
┌─────────────────────────────────────┐
│     ScaleCloudApp (iOS App)         │
│  - Custom login UI                  │
│  - Auto-upload integration          │
│  - Watched downloads                │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│   ScaleCloudKit (Swift Framework)   │
│  - Fork of NextcloudKit             │
│  - Proxy integration layer          │
│  - URLSession lifecycle mgmt        │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│   ScaleCloudGo (Go Framework)       │
│  - Tailscale tsnet integration      │
│  - HTTP proxy server                │
│  - Built with gomobile bind         │
└─────────────────────────────────────┘
```

## Key Features

### 1. Tailscale Network Proxy (Go Layer)

**File**: `ScaleCloudGo/ScaleCloudGo.go`

**Purpose**: Provides transparent HTTP proxy that routes traffic through Tailscale when accessing `.ts.net` hosts or CGNAT addresses (100.64.0.0/10).

#### Exported Functions

```go
func StartProxy(hostname, stateDir string) (int, error)
func StopProxy() error
```

#### Implementation Details

- **Tailscale Node**: Single `*tsnet.Server` instance per app lifecycle
  - Non-ephemeral node (persists across app restarts)
  - State stored in `<app support>/tailscale/`
  - Uses official Tailscale control plane
  - OAuth credentials injected via environment variables

- **HTTP Proxy**: `goproxy.ProxyHttpServer` on `127.0.0.1:0` (random port)
  - Custom `Transport.DialContext` that checks if target is Tailscale address
  - If yes → uses `tsNode.Dial()` (routes through tailnet)
  - If no → uses standard `net.Dialer` (normal internet)

- **Thread Safety**: Two mutexes
  - `proxyMX`: Protects proxy server lifecycle
  - `nodeMX`: Protects Tailscale node initialization

- **Address Detection**: `isTailscaleAddress(host string) bool`
  - Returns `true` if host ends with `.ts.net`
  - Returns `true` if host is in `100.64.0.0/10` CGNAT range
  - Mirrors Android implementation exactly

#### Build Process

Built with `gomobile bind -target=ios` which generates:
- `ScaleCloudGo.xcframework` (multi-architecture framework)
- Objective-C headers with bindings
- Swift can import and call directly

### 2. Proxy Integration Layer (Kit Layer)

**File**: `ScaleCloudKit/Sources/ScaleCloudKit/SCKSession.swift`

**Purpose**: Fork of NextcloudKit that automatically configures all network requests to use the Tailscale proxy.

#### Static State Management

```swift
private static var proxyClients: [WeakURLSession] = []
private static var cleanupTimer: Timer?
private static var proxyPort: Int = 0
private static let lock = NSLock()
```

Mirrors Android's `OwnCloudClient` static fields for proxy lifecycle management.

#### Core Method: `applyProxySettings()`

```swift
private static func applyProxySettings() -> [AnyHashable: Any]?
```

1. Creates state directory: `<app support>/tailscale/`
2. Calls `ScaleCloudGoStartProxy("ios-scalecloud-client", stateDir, &port, &error)`
3. Returns proxy dictionary:
   ```swift
   [
       kCFProxyTypeKey: kCFProxyTypeHTTP,
       kCFProxyHostNameKey: "127.0.0.1",
       kCFProxyPortNumberKey: port,
       // ... HTTPS equivalent
   ]
   ```

#### URLSession Lifecycle Management

**Registration**:
```swift
private static func registerSession(_ session: URLSession)
```
- Wraps session in `WeakURLSession` helper
- Adds to `proxyClients` array
- Starts cleanup timer (60s interval) on first registration

**Cleanup**:
```swift
private static func checkAndCleanup()
```
- Prunes dead sessions from array
- When last session dies → calls `ScaleCloudGoStopProxy()`
- Resets `proxyPort` to 0

**Integration**: Every `URLSessionConfiguration` in `SCKSession.__init__()` gets:
```swift
config.connectionProxyDictionary = proxyDictionary
SCKSession.registerSession(sessionInstance.session)
```

This applies to:
- `sessionData` (cached)
- `sessionDataNoCache`
- `sessionDownloadBackground`
- `sessionUploadBackground`
- All lazy extension sessions (`sessionDataExt`, etc.)
- WWAN-specific sessions

### 3. ScaleCloud-Specific Features (App Layer)

#### A. Custom Login UI

**Files**: 
- `ScaleCloudApp/iOSClient/Login/NCLogin.swift`
- `ScaleCloudApp/iOSClient/Login/NCLogin.storyboard`

**Purpose**: Special login flow for `toth-adattar` (specific Tailscale deployment).

**Detection Logic**:
```swift
private func isToCsaCloud(_ urlString: String) -> Bool {
    guard let host = URL(string: urlString)?.host else { return false }
    return host == "toth-adattar" || host.hasPrefix("toth-adattar.")
}
```

**UI Changes**:
- Normal login: Shows server URL + web login button
- ScaleCloud login: Shows username + password fields with custom styling
- Triggered in `handleServerUrlEntry()` → `isTailscaleAddress()` check

**Storyboard Elements**:
- `scUsernameContainer` + `scUsernameInput`
- `scPasswordContainer` + `scPasswordInput`
- Custom login button with arrow icon
- Initially hidden, shown by `showTailscaleLoginUI()`

**Login Flow**:
```swift
@IBAction private func performTailscaleLoginFromUI()
```
Calls standard Nextcloud authentication with the Tailscale server URL.

#### B. Account Settings Extension

**Files**:
- `ScaleCloudApp/iOSClient/Account/Account Settings/NCAccountSettingsModel.swift`
- `ScaleCloudApp/iOSClient/Account/Account Settings/NCAccountSettingsView.swift`
- `ScaleCloudApp/iOSClient/Account/Account Settings/ScaleCloudWatchedFoldersModel.swift`
- `ScaleCloudApp/iOSClient/Account/Account Settings/ScaleCloudWatchedFoldersView.swift`

**ScaleCloud-Only Section**: "Watched Download Folders"

**Detection**:
```swift
var isScaleCloudAccount: Bool {
    guard let tblAccount else { return false }
    return isToCsaCloud(tblAccount.urlBase)
}
```

**UI**:
- Only shown for accounts where `isScaleCloudAccount == true`
- Navigates to folder picker
- Manages security-scoped bookmarks for folder access

**Folder Management**:
```swift
class ScaleCloudWatchedFoldersModel: ObservableObject {
    @Published var folders: [WatchedFolder] = []
    
    func addFolder()       // Uses UIDocumentPickerViewController
    func removeFolder(id)  // Releases bookmark, updates preferences
}
```

**Persistence**:
```swift
// In NCPreferences.swift
func getScaleCloudWatchedDownloadBookmarks(account: String) -> [Data]
func setScaleCloudWatchedDownloadBookmarks(account: String, bookmarks: [Data])
```

Stores security-scoped bookmark data as `Data` arrays in user defaults.

#### C. Auto-Upload Integration

**File**: `ScaleCloudApp/iOSClient/Networking/NCAutoUpload.swift`

**Purpose**: Enhanced auto-upload for ScaleCloud accounts that watches both photo library and custom download folders.

**ScaleCloud Detection**:
```swift
private func isToCsaCloud(_ urlString: String) -> Bool {
    guard let host = URL(string: urlString)?.host else { return false }
    return host == "toth-adattar" || host.hasPrefix("toth-adattar.")
}
```

**Enhanced Auto-Upload**:
```swift
// Inside autoUploadFullPhotos()
if isToCsaCloud(tblAccount.urlBase) {
    let bookmarks = NCPreferences().getScaleCloudWatchedDownloadBookmarks(account: tblAccount.account)
    await ScaleCloudDownloadsHelper.scanAndEnqueueDownloads(for: tableAccount(value: tblAccount), bookmarks: bookmarks)
}
```

**Custom Remote Paths** (ScaleCloud-specific):
```swift
var effectiveBase = autoUploadServerUrlBase
if isToCsaCloud(tblAccount.urlBase) && index < sourceCollections.count {
    let source = sourceCollections[index]
    switch source.assetCollectionSubtype {
    case .smartAlbumScreenshots:
        effectiveBase = autoUploadServerUrl + "/Képernyőmentések"
    default:
        effectiveBase = autoUploadServerUrl + "/Saját Fényképek és Videók/"
    }
}
```

Maps:
- Screenshots → `/Képernyőmentések`
- Photos/Videos → `/Saját Fényképek és Videók/`

#### D. Watched Downloads Helper

**File**: `ScaleCloudApp/iOSClient/Utility/ScaleCloudDownloadsHelper.swift`

**Purpose**: Scans user-selected folders for new files and queues them for upload to ScaleCloud.

**Main Function**:
```swift
static func scanAndEnqueueDownloads(for account: tableAccount, bookmarks: [Data]) async
```

**Process**:
1. Resolves security-scoped bookmarks
2. Scans directories for files
3. Filters out files already uploaded (checks database)
4. Enqueues new files with metadata:
   - Source: `"downloadsCollection"` (virtual collection identifier)
   - Preserves creation/modification dates
5. Uses `NCNetworking.shared.upload()` to queue uploads

**Security-Scoped Bookmark Handling**:
```swift
guard let url = try? URL(resolvingBookmarkData: bookmark, 
                          options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale) else { continue }

guard url.startAccessingSecurityScopedResource() else { continue }
defer { url.stopAccessingSecurityScopedResource() }
```

#### E. App Launch Auto-Sync

**File**: `ScaleCloudApp/iOSClient/SceneDelegate.swift`

**Purpose**: Automatically configures ScaleCloud accounts for photo/video auto-upload on app launch.

**Entry Point**:
```swift
func sceneDidBecomeActive(_ scene: UIScene) {
    // ...
    setupScaleCloudAutoSync()
}
```

**Implementation**:
```swift
private func setupScaleCloudAutoSync() {
    guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }
    
    var hasScaleCloudAccount = false
    for tblAccount in accounts {
        if isTailscaleAddress(tblAccount.urlBase) {
            hasScaleCloudAccount = true
            configureAutoUploadForAccount(tblAccount)
        }
    }
    
    if hasScaleCloudAccount {
        Task { await NCAutoUpload.shared.initAutoUpload() }
    }
}
```

**Per-Account Configuration**:
```swift
private func configureAutoUploadForAccount(_ tblAccount: tableAccount) {
    database.setAccountAutoUploadImage(true, account: tblAccount.account)
    database.setAccountAutoUploadVideo(true, account: tblAccount.account)
    database.setAccountAutoUploadWWAn(false, account: tblAccount.account)
    
    // Set default camera upload path
    let defaultFolder = database.getAccountAutoUploadDirectory(account: tblAccount.account)
    if defaultFolder.isEmpty {
        database.setAccountAutoUploadDirectory("/", 
                                                fileName: NCKeyGlobal().folderDefaultAutoUpload,
                                                account: tblAccount.account)
    }
}
```

**Settings Applied**:
- ✅ Image auto-upload: enabled
- ✅ Video auto-upload: enabled
- ❌ Upload over cellular: disabled (Wi-Fi only)
- 📁 Default folder: `/` with standard camera upload subfolder

**Tailscale Detection**:
```swift
private func isTailscaleAddress(_ urlString: String) -> Bool {
    guard let host = URL(string: urlString)?.host else { return false }
    if host.hasSuffix(".ts.net") { return true }
    
    // Check CGNAT range 100.64.0.0/10
    guard let ipAddr = IPv4Address(host) else { return false }
    let rawValue = ipAddr.rawValue
    let networkBits = rawValue & 0xFFC00000  // /10 mask
    return networkBits == 0x64400000         // 100.64.0.0
}
```

## Project Structure Changes

### Local Package Dependencies

**Change**: Switched from remote Swift Package Manager reference to local package.

**Before**:
```xml
<XCRemoteSwiftPackageReference>
  <url>https://github.com/nextcloud/NextcloudKit</url>
  <branch>7.3.2</branch>
</XCRemoteSwiftPackageReference>
```

**After**:
```xml
<XCLocalSwiftPackageReference>
  <path>../ScaleCloudKit</path>
</XCLocalSwiftPackageReference>
```

**Reason**: Allows customization of NextcloudKit fork for proxy integration.

### Tuist Project Management

The project uses Tuist for workspace generation with a 4-layer structure:

```
ScaleCloudGo (Go framework)
    ↓
ScaleCloudKit (Swift framework - NextcloudKit fork)
    ↓
ScaleCloudApp (iOS app)
    ↓
ScaleCloudWrap (future wrapper layer)
```

Each layer has:
- `Project.swift` - Tuist project definition
- `prebuilt/` - Directory for precompiled artifacts
- Post-build scripts that use prebuilt dependencies when available

See `BUILD_WORKFLOW.md` for CI/CD setup.

## Key Design Decisions

### 1. Proxy Approach

**Decision**: Use HTTP proxy instead of implementing custom URLProtocol.

**Rationale**:
- Simpler integration - just set `connectionProxyDictionary`
- Works with all URLSession configurations automatically
- No need to register custom protocols
- Matches Android implementation (easier to maintain parity)

### 2. Lifecycle Management

**Decision**: Start proxy on first URLSession creation, stop when last session deallocates.

**Rationale**:
- Proxy only runs when needed (network activity)
- Automatic cleanup - no manual intervention required
- Mirrors Android's lifecycle (tied to OwnCloudClient instances)

### 3. Tailscale Node Persistence

**Decision**: Non-ephemeral Tailscale node with persistent state directory.

**Rationale**:
- Node persists across app restarts
- Avoids re-authentication on every launch
- State stored in standard iOS app support directory
- Users remain authenticated in Tailscale Admin Console

### 4. Account Detection

**Decision**: Use hostname pattern matching (`toth-adattar`) instead of capabilities check.

**Rationale**:
- Immediate detection without network request
- Works before authentication completes
- Simpler than adding custom Nextcloud capabilities
- Deployment-specific (this is for a specific tailnet)

### 5. Watched Downloads Approach

**Decision**: Use security-scoped bookmarks instead of hardcoded paths.

**Rationale**:
- Respects iOS sandbox security
- User explicitly grants access to folders
- Persistent access across app launches
- Works with iCloud Drive, external storage, etc.

## Testing

### Manual Testing Checklist

#### Proxy Functionality
- [ ] Launch app with ScaleCloud account
- [ ] Verify proxy starts (check logs for "ScaleCloud: startProxy succeeded")
- [ ] Browse files on Tailscale Nextcloud instance
- [ ] Download a file
- [ ] Upload a file
- [ ] Verify traffic routes through tailnet (check Tailscale admin console)

#### Login Flow
- [ ] Enter `toth-adattar` server URL
- [ ] Verify custom username/password fields appear
- [ ] Enter credentials
- [ ] Verify successful authentication
- [ ] Account appears in account list

#### Auto-Upload
- [ ] Take a photo
- [ ] Verify it uploads to `/Saját Fényképek és Videók/`
- [ ] Take a screenshot
- [ ] Verify it uploads to `/Képernyőmentések`

#### Watched Downloads
- [ ] Go to account settings
- [ ] Add a watched folder (e.g., Downloads)
- [ ] Add files to that folder
- [ ] Launch app or trigger auto-upload
- [ ] Verify files upload with `downloadsCollection` source

#### Lifecycle
- [ ] Force quit app
- [ ] Relaunch
- [ ] Verify proxy reconnects automatically
- [ ] Browse files (should work without re-auth)

### Debug Logging

Enable verbose logging in `SCKSession.swift`:
```swift
nkLog(message: "ScaleCloud: proxy started on port \(proxyPort)")
nkLog(error: "ScaleCloud: startProxy failed: \(error?.localizedDescription ?? "unknown")")
```

## Known Limitations

1. **Single Tailnet Support**: Hardcoded to `toth-adattar` deployment
   - Future: Could make this configurable per account

2. **No Wrap Layer**: ScaleCloudWrap not yet implemented
   - Placeholder exists in project structure

3. **iOS Only**: No macOS, watchOS, or tvOS support
   - Go framework built with `gomobile bind -target=ios` only

4. **Manual Folder Management**: Users must manually add watched folders
   - Future: Could auto-detect common download locations

5. **No Conflict Resolution**: If file already exists on server
   - Uses standard Nextcloud behavior (might overwrite or fail)

## Future Enhancements

### Planned Features

1. **Multi-Tailnet Support**
   - Remove hardcoded `toth-adattar` check
   - Add UI for configuring tailnet domain per account
   - Store in account preferences

2. **Smart Folder Detection**
   - Auto-suggest common folders: Downloads, Documents, Desktop
   - Intelligent filtering (skip system folders, temp files)

3. **Upload Policies**
   - File type filters (only upload images, videos, documents)
   - Size limits
   - Upload scheduling (only at night, only on Wi-Fi + charging)

4. **Enhanced Sync Status**
   - Show which watched folders are being monitored
   - Display upload queue and progress
   - Notifications for completed uploads

5. **macOS Support**
   - Build ScaleCloudGo for macOS (`-target=macos`)
   - Adapt UI for macOS (AppKit or Catalyst)

### Technical Debt

1. **Error Handling**: More graceful handling of proxy failures
2. **Logging**: Structured logging with levels (debug, info, error)
3. **Tests**: Unit tests for proxy logic, integration tests for uploads
4. **Performance**: Monitor proxy overhead, optimize if needed

## Comparison with Android Implementation

| Feature | Android | iOS | Notes |
|---------|---------|-----|-------|
| Proxy Framework | Java HTTP Proxy | Go goproxy | Both use HTTP proxy approach |
| Tailscale Integration | tsnet.Server | tsnet.Server | Identical Go library |
| Lifecycle | Static fields in OwnCloudClient | Static vars in SCKSession | Same pattern |
| Session Management | Weak references | WeakURLSession helper | Equivalent |
| Login UI | AuthenticatorActivity | NCLogin.swift | Similar detection logic |
| Account Detection | isToCsaCloud() | isToCsaCloud() | Identical |
| Auto-Upload | FileUploadWorker | NCAutoUpload | Similar, iOS has watched folders |
| State Directory | filesDir/tailscale | App Support/tailscale | Platform-specific |

## References

### External Documentation
- [Tailscale tsnet package](https://pkg.go.dev/tailscale.com/tsnet)
- [gomobile documentation](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile)
- [iOS URLSession Proxy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411499-connectionproxydictionary)
- [Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/nsurl/1417051-startaccessingsecurityscopedreso)

### Internal Documentation
- `BUILD_WORKFLOW.md` - CI/CD and prebuilt artifacts
- `ScaleCloudGo/prebuilt/README.md` - Go framework build instructions
- `ScaleCloudKit/prebuilt/README.md` - Kit framework build instructions

## Contributors

Original Nextcloud iOS client by Nextcloud GmbH and contributors.

ScaleCloud modifications implemented for the `toth-adattar` Tailscale deployment.
