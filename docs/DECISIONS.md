# Architecture & Design Decisions

## Distribution

### F-Droid
- **Application ID:** `com.bluesound.bluesoundplayer`
- **MR:** https://gitlab.com/fdroid/fdroiddata/-/merge_requests/34693
- Metadata uses `AutoUpdateMode: None` / `UpdateCheckMode: None` because Flutter auto-update via tags doesn't work reliably
- `scandelete: flutter/.pub-cache` required to remove binaries/ZIPs from Dart packages before F-Droid scan
- Paths in fdroiddata YAML are relative to repo root, not to `subdir`
- Use full commit hash in `commit:` field, not tag names (tags can be moved)
- No `Summary`/`Description` in YAML -- use fastlane structure instead

### Flathub (closed)
- PR #8087 closed. Source build requirement too complex for Flutter apps (requires full Flutter SDK build from source).

### Snap Store
- Name `bluesound-controller` registered under account `ooocp`
- Build blocked by LXD/Docker conflict and missing `libunistring.so.2`. Deferred.

### Google Play
- Developer account "CarlDarkman" (ID: 7741871036413057781) created 2026-03-14
- Identity verification pending

### Apple App Store
- Not started. Requires Mac hardware + Apple Developer Account (99$/yr)

## Build Toolchain

### Gradle / AGP / Kotlin Versions
- **Gradle 8.5** required because F-Droid build servers run Java 21 (Gradle 7.x only supports up to Java 19)
- **AGP 8.3.0** required because AGP 8.1.0 has a `JdkImageTransform`/`jlink` bug with Java 21
- **Kotlin 1.9.0** for compatibility with AGP 8.3.0
- **Java target 17** for both `compileOptions` and `kotlinOptions` (must match)

### Flutter Version Pinning
- F-Droid builds use `flutter@3.22.0` (pinned via `srclibs` in metadata)
- This ensures reproducible builds on F-Droid servers

## Playback Transfer

### What works
- **Sonos -> Sonos:** Radio streams via abstract URI from `GetMediaInfo` + metadata
- **Sonos -> BluOS:** Radio streams via resolved HTTP URL from `GetPositionInfo` (stripped of codec prefix like `aac://`)
- **BluOS -> BluOS:** Radio streams via `streamUrl` from `/Status`, played via `/Play?url=`

### What doesn't work (by design, button hidden)
- **BluOS -> Sonos:** Error 714 "Illegal URI" -- Sonos rejects external HTTP URLs via `SetAVTransportURI`
- **Streaming service content** (Deezer, Spotify): Session-bound URIs (`x-rincon-queue:`, `x-sonos-http:`) are non-transferable
- **BluOS playlists:** No `streamUrl` in `/Status` for service-managed content

### Why transfer instead of grouping?
- Sonos S1 and S2 players cannot be grouped together
- BluOS and Sonos players cannot be grouped cross-platform
- Transfer is the alternative for moving playback between incompatible players

## F-Droid YAML Lessons Learned
1. No quotes on `versionName` and `CurrentVersion` values
2. Run `fdroid rewritemeta <appid>` locally before pushing
3. Don't include `WebSite`, `IssueTracker`, `AuthorName` when `Repo` is a GitHub URL (auto-derived)
4. Do include `SourceCode` (required field even if it matches Repo)
5. Install fdroidserver via `pipx install fdroidserver` (PEP 668)
