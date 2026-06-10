# Phase 1: Extraction Complete

**Status**: Dependencies Configured - Ready for Phase 2
**Files**: 49 extracted + ldid source tree + Silence.m4a asset

## Source
- SideStore 0.6.4: `/home/cvt/sidestore/`
- AltSign: `a48493283bd676ad3a4d5b65dc7c039cebf7749e`
- ldid: Full source copied to `Sources/AltSign/ldid/`

## Extracted (Local - Modified)

### AltSign (40+ files)
`Sources/AltSign/` - URLSession proxy injection needed

### Anisette (1 file)
`Sources/Anisette/FetchAnisetteDataOperation.swift` - Strip UI, inject proxy

### Operations (3 files)
`Sources/Operations/` - Strip minimuxer/em_proxy/UI

### Utilities (2 files)
`Sources/Utilities/BackgroundTaskManager.swift` - Silent audio protection during signing

### Resources (1 asset)
`Resources/Silence.m4a` - Silent audio file for background execution extension

## Dependencies (SPM)

### Starscream
WebSocket for Anisette V3

### Roxas
Riley Testut utilities (ResultOperation)

### AltStoreCore
CoreData models (InstalledApp, DatabaseManager, RefreshAttempt)
Will replace with custom orchestration in Phase 3-4

## ldid Resolution
✅ Full source tree copied to `Sources/AltSign/ldid/`
- ldid.cpp (115KB)
- ldid.hpp
- lookup2.c, sha1.h
- libplist/ (entire directory)

Build settings configured in project.yml


# ADDENDUM -------------------------------

# Phase 1 Addendum: Silent Audio Protection

**Status**: Complete  
**Integration**: BackgroundRefreshAppsOperation  

## Overview

SideStore uses a defensive mechanism to extend execution time during signing operations: silent audio playback. This protection is now integrated into ScaleCloudSign as part of Phase 1 extraction.

## Mechanism

**AVAudioEngine** plays a looping silent audio file (Silence.m4a) at zero volume. This:
- Extends app execution time beyond normal background limits
- Prevents iOS from suspending the app during signing
- Works in both foreground and background contexts

**Critical Architecture Point**: The signing operation itself (`BackgroundRefreshAppsOperation`) includes this protection. The calling context (BGTask vs foreground) doesn't matter — the operation is always protected.

## Implementation

### Files Extracted

**`Sources/Utilities/BackgroundTaskManager.swift`** (from `/home/cvt/sidestore/AltStore/Components/BackgroundTaskManager.swift`)
- Singleton manager for silent audio lifecycle
- `performExtendedBackgroundTask()` wraps operations in audio protection
- Modified bundle lookup for framework context

**`Resources/Silence.m4a`** (from `/home/cvt/sidestore/AltStore/Resources/Silence.m4a`)
- Silent audio file played in loop
- Zero-volume playback (.mixWithOthers audio session)

### Integration Points

**`BackgroundRefreshAppsOperation.swift`**:
```swift
override func main() {
    // Wrap entire signing operation in silent audio
    BackgroundTaskManager.shared.performExtendedBackgroundTask { (taskResult, taskCompletionHandler) in
        // ... perform signing ...
        group.completionHandler = { (results) in
            taskCompletionHandler()  // Stop audio after signing
            self.finish(.success(results))
        }
    }
}
```

**Called from**:
- `AppDelegate+SigningRefresh.swift`: BGProcessingTask handler
- `AppDelegate.swift`: Foreground fallback (applicationDidBecomeActive)

Both paths execute the same protected operation.

## Build Configuration

**`project.yml`**:
```yaml
sources:
  - path: Sources
  - path: Resources
    type: folder
    buildPhase: resources
```

Resources directory includes Silence.m4a as bundle resource.

## Technical Details

**Audio Session Configuration**:
- Category: `.playback`
- Options: `.mixWithOthers` (doesn't interrupt other audio)
- Volume: 0.0 (silent)

**Looping Logic**:
- Two buffers scheduled initially
- Each buffer completion reschedules itself
- Continues until `taskCompletionHandler()` called

**Thread Safety**:
- Operations run on dedicated `DispatchQueue` (`com.scalecloud.BackgroundTaskManager`)
- Prevents audio engine race conditions

## Testing Notes

- Audio protection applies regardless of foreground/background state
- No user-visible or audible impact
- Error handling: if audio fails to start, signing operation aborts safely
- Completion handler MUST be called to stop audio (prevents battery drain)

## Phase 1 Status Update

**Original extraction**: 47 files + ldid  
**Updated extraction**: 49 files + ldid + Silence.m4a  

**New files**:
- `Sources/Utilities/BackgroundTaskManager.swift`
- `Resources/Silence.m4a`

**Modified files**:
- `Sources/Operations/BackgroundRefreshAppsOperation.swift` (wrapped in audio protection)
- `project.yml` (added Resources build phase)
- `PHASE1_EXTRACTION.md` (updated file count and manifest)
------------------


## Next: Phase 2
- Strip UI from FetchAnisetteDataOperation
- Strip minimuxer/em_proxy from Operations
- Inject Tailscale proxy into URLSession creation points
