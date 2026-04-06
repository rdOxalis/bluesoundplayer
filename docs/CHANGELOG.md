# Changelog

## v1.0.0 (2026-04-06)

### Flutter App
- Full Flutter UI for Android and Linux desktop
- Automatic network scanning for BluOS and Sonos players
- Playback controls: play, pause, stop, next, previous
- Volume control with slider
- Preset/favorites management with category grouping (stations, playlists, albums, songs)
- Multi-player support with player switching
- Player grouping (BluOS multi-room)
- Playback transfer between players (Sonos<->Sonos, Sonos->BluOS, BluOS<->BluOS)
- Show master track info for grouped players
- Multi-language support: English, German, Swahili
- Licenses page, dynamic version display, donate button
- Proper UTF-8 encoding and mobile layout polish

### Go CLI
- Interactive terminal UI with real-time updates
- Non-interactive CLI mode
- BluOS REST API and Sonos UPnP/SOAP API integration
- Cross-compilation for 7 platforms (Linux, Windows, macOS, FreeBSD -- amd64/arm64)

### Distribution
- GitHub Releases: Android APK, Linux desktop binary, Go CLI (7 platforms)
- F-Droid: Submission MR !34693 (pipeline passing, awaiting merge)
- Snap Store: Name registered, build deferred
- Google Play: Developer account created, verification pending
- Flathub: Closed (source build requirement too complex for Flutter)

### Build Fixes
- Gradle 8.5 for Java 21 compatibility on F-Droid servers
- AGP 8.3.0 to fix JdkImageTransform/jlink bug with Java 21
- Kotlin 1.9.0, Java target 17
- Fixed scandelete path for F-Droid scanner (`flutter/.pub-cache`)
