# F-Droid Release Process

## How Auto-Updates Work

Once the app is merged into fdroiddata, new releases are picked up automatically:

1. Update `version` in `flutter/pubspec.yaml` (e.g. `1.1.0+2`)
2. Update Flutter version in `.github/workflows/release.yml` if changed
3. Commit and push
4. Create and push a new tag (e.g. `v1.1.0`)
5. F-Droid scans tags periodically, reads the version from `pubspec.yaml`, builds the APK

No manual fdroiddata edits needed for regular releases.

## What F-Droid Reads

- **Version name and code:** from `flutter/pubspec.yaml` via `UpdateCheckData`
- **Flutter version:** extracted from `.github/workflows/release.yml` at build time
- **App name:** from `AndroidManifest.xml` (`AutoName` field)

## Checklist for a New Release

- [ ] Bump version in `flutter/pubspec.yaml` (format: `x.y.z+versionCode`)
- [ ] Update Flutter version in `.github/workflows/release.yml` if upgraded
- [ ] Test APK build locally: `cd flutter && flutter build apk --release`
- [ ] Commit and push to `main`
- [ ] Tag and push: `git tag vX.Y.Z && git push origin main --tags`
- [ ] Wait for F-Droid to pick it up (can take a few days)

## If Something Breaks

F-Droid builds run on Debian Trixie with Java 21. Common issues:

| Problem | Fix |
|---------|-----|
| Gradle/Java incompatibility | Upgrade Gradle + AGP in `flutter/android/` |
| JdkImageTransform/jlink error | AGP must be 8.3.0+ for Java 21 |
| Scanner finds binaries in .pub-cache | `scandelete: flutter/.pub-cache` handles this |
| `checkupdates` diff | Ensure `AutoName` and other auto-derived fields are present |

## Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | Pinned Flutter version (read by F-Droid at build time) |
| `flutter/pubspec.yaml` | App version (read by F-Droid for auto-update) |
| `flutter/android/settings.gradle` | Gradle, AGP, Kotlin versions |
| `flutter/android/app/build.gradle` | compileSdk, Java target, app config |
| `flutter/android/gradle/wrapper/gradle-wrapper.properties` | Gradle distribution version |

## fdroiddata Metadata

Repository: https://gitlab.com/fdroid/fdroiddata  
Fork: https://gitlab.com/ooocp/fdroiddata  
MR: https://gitlab.com/fdroid/fdroiddata/-/merge_requests/34693  
Metadata file: `metadata/com.bluesound.bluesoundplayer.yml`

### Lessons Learned

- No quotes on `versionName` and `CurrentVersion` values
- Use full commit hash, not tag names
- Run `fdroid rewritemeta com.bluesound.bluesoundplayer` before pushing
- Include `IssueTracker`, `AuthorName`, `AuthorWebSite` — linsui explicitly requested these
- Don't include `WebSite` (auto-derived from GitHub)
- Do include `SourceCode` (required even if same as Repo)
- `scandelete` paths are relative to repo root, not to `subdir`
- Install fdroidserver locally via `pipx install fdroidserver`
