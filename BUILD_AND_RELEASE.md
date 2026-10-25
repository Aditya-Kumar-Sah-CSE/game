# OPERATION SHADOW — Build & Release Guide

## Prerequisites
- Godot 4.x (stable) with export templates
- Android SDK (API level 33+)
- Android NDK
- JDK 17+
- Debug/Release keystore

## Development (Desktop)
```bash
# Open project in Godot Editor
godot --editor --path d:\game

# Run from command line
godot --path d:\game
```

## Android Export Configuration
1. **Application ID**: `com.operationshadow.game`
2. **Display Name**: Operation Shadow
3. **Orientation**: Landscape
4. **Min SDK**: 24 (Android 7.0)
5. **Target SDK**: 34
6. **Renderer**: Compatibility (OpenGL ES 3.0)
7. **Permissions**: None required (offline single-player)

## Build Steps

### Debug APK
```bash
godot --headless --export-debug "Android" export/operation_shadow_debug.apk
```

### Release APK
```bash
godot --headless --export-release "Android" export/operation_shadow.apk
```

## APK Size Budget
| Category | Target | Actual |
|----------|--------|--------|
| Engine/Code | ~15 MB | TBD |
| 3D Models | ~10 MB | TBD |
| Textures | ~10 MB | TBD |
| Audio | ~5 MB | TBD |
| Fonts/UI | ~2 MB | TBD |
| Other | ~3 MB | TBD |
| **Total** | **< 50 MB** | **TBD** |

## Post-Build Validation
- [ ] APK installs on target device/emulator
- [ ] App launches without crash
- [ ] Touch controls responsive
- [ ] Audio plays correctly
- [ ] No network requests (offline mode)
- [ ] Save data persists after restart
- [ ] Orientation stays landscape
- [ ] No exposed debug keys or secrets

## Known Limitations
- Android export requires Godot export templates installed locally
- Device testing requires physical Android device or emulator
- APK size measurements must come from actual exported APK, not project size
