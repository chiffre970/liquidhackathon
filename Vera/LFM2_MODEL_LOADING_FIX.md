# LFM2 Model Loading Fix Summary

## Problem
The Vera app was unable to load the LFM2-350M model on iOS, showing various errors including:
- `modelNotFound` - Bundle not found in app
- `Executorch Error 34` - Read/write permission issues
- `Executorch Error 32` - XnnpackBackend not registered

## Root Causes
1. **Model Bundle Format**: The `.bundle` file needs to be the original archive file from Liquid AI, not an extracted folder
2. **Write Permissions**: iOS app bundles are read-only; the model needs to be copied to a writable location
3. **Missing Backend**: The LEAP SDK v0.3.0 didn't have XnnpackBackend properly registered for iOS

## Solution Steps

### 1. Model Bundle Setup
- Use the original `.bundle` archive file (not extracted folder)
- Add it to Xcode by dragging into the `Vera/Vera/Vera/` folder
- Ensure "Copy items if needed" and "Add to targets: Vera" are checked

### 2. Code Changes
- **LEAPSDKManager.swift**: Added logic to copy model bundle to Library directory (writable location)
- **Model Loading**: Pass the bundle directory path to LEAP SDK, not individual files

### 3. Framework Dependencies
Added required system frameworks in Xcode:
- Accelerate.framework
- Metal.framework
- MetalPerformanceShaders.framework
- CoreML.framework

### 4. Linker Flags
Added to Build Settings → Other Linker Flags:
- `-ObjC`
- `-all_load`

### 5. LEAP SDK Update (THE FIX)
**Changed from v0.3.0 to main branch**:
- In Package Dependencies, changed LeapSDK from version 0.3.0 to branch: main
- Removed LeapSDKConstrainedGeneration dependency (not available in main)
- The main branch has the XnnpackBackend properly registered

## Final Working Configuration
- **LEAP SDK**: main branch from https://github.com/Liquid4All/leap-ios.git
- **Model**: Original .bundle archive file in app bundle
- **Runtime**: Model copied to ~/Library/ for write access
- **Frameworks**: All neural network frameworks linked
- **Linker Flags**: -ObjC and -all_load set

## Key Insight
The XnnpackBackend registration issue was fixed in the LEAP SDK main branch but not in the v0.3.0 release. Updating to the latest code from main branch resolved the backend loading error.