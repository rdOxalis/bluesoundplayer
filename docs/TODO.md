# TODO

## Distribution

- [ ] **F-Droid:** Pipeline passing, MR !34693 awaiting merge by reviewer linsui
- [ ] **Google Play:** Identity verification pending, then upload APK
- [ ] **Snap Store:** Resolve LXD/Docker conflict and `libunistring.so.2` issue
- [ ] **Apple App Store:** Requires Mac + Apple Developer Account (99$/yr)

## Features

- [ ] **BluOS native playlist transfer:** Implement `<canMovePlayback>` API for BluOS-to-BluOS playlist transfer
- [ ] **Sonos preset deduplication:** Fix duplicate display in Flutter UI
- [ ] **Queue management:** Display and manipulate playback queue
- [ ] **Equalizer control:** If supported by BluOS API
- [ ] **Sleep timer / Alarm scheduler**

## Technical Debt

- [ ] Upgrade Flutter dependencies (69 packages have newer versions)
- [ ] Add unit tests for API clients
- [ ] Add widget tests for UI components
