# Fix app launch crashes and thread safety issues

## Problem
The app crashes at launch or shortly after reaching the start screen. The root causes are:

1. **Thread safety conflicts** — Background network callbacks create and use data objects that are silently restricted to the main thread by the build system, causing crashes when they run on background threads
2. **Unsafe app lifecycle code** — Some shutdown/background code blocks the main thread and accesses shared resources without proper safety
3. **Aggressive startup** — Too much network initialization happens simultaneously at launch, creating race conditions

## Fixes

### 1. Thread Safety for Data Types
- Mark all pure data models (messages, device info, connection states, configs, etc.) as safe to use from any thread
- This prevents crashes when network delegate callbacks create these objects on background threads

### 2. Safer App Lifecycle
- Remove the blocking sleep call during app termination that can freeze the main thread
- Make background/termination handlers dispatch work properly instead of directly calling shared resources
- Wrap background task registration in safety checks

### 3. Safer Network Session Startup
- Delay network session initialization slightly after app launch to avoid overwhelming the system
- Add guards to prevent multiple simultaneous initialization attempts
- Protect against crashes when creating network sessions

### 4. Safer Delegate Callbacks
- Ensure all network delegate callbacks properly handle the case where the session has been replaced or destroyed
- Add nil checks and guards to prevent accessing deallocated resources

These changes are targeted fixes — no architecture changes, no new features. The goal is to eliminate the launch crashes while keeping all existing functionality intact.