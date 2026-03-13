# F-Droid Submission Plan – BluesoundPlayer
## Ziel: Aufnahme ins offizielle F-Droid Repository via Merge Request (Weg B)

---

## Übersicht

F-Droid baut Apps selbst aus dem Quellcode. Es wird keine APK eingereicht,
sondern eine YAML-Metadaten-Datei, die als Build-Anweisung dient.

**Involvierte Repositories:**
- `github.com/[USER]/bluesoundplayer` – das eigene App-Repo (Quellcode)
- `gitlab.com/fdroid/fdroiddata` – F-Droid's Metadaten-Repo (Merge Request Ziel)

---

## Phase 1: GitHub-Repo vorbereiten

### 1.1 Lizenz prüfen
```bash
# Sicherstellen dass eine LICENSE-Datei im Root vorhanden ist
ls LICENSE*
# Gültige SPDX-Bezeichner: GPL-3.0-or-later, MIT, Apache-2.0, etc.
```

**Aufgabe:** Falls keine Lizenz vorhanden → `LICENSE`-Datei anlegen und committen.

### 1.2 applicationId ermitteln
```bash
# In app/build.gradle oder app/build.gradle.kts
grep -r "applicationId" app/build.gradle*
# Beispiel-Ergebnis: applicationId "com.carl.bluesoundplayer"
# Diese ID wird der Name der YAML-Datei bei F-Droid
```

### 1.3 versionName und versionCode prüfen
```bash
grep -E "versionName|versionCode" app/build.gradle*
# Beide müssen gesetzt sein, z.B.:
# versionName "1.0"
# versionCode 1
```

### 1.4 Git-Tag für aktuellen Release setzen
```bash
# Tag muss exakt dem versionName entsprechen (mit "v"-Prefix)
git tag v1.0
git push origin v1.0

# Alle vorhandenen Tags prüfen
git tag -l
```

### 1.5 Fastlane-Metadaten anlegen
```bash
mkdir -p fastlane/metadata/android/en-US/changelogs
```

**Datei: `fastlane/metadata/android/en-US/short_description.txt`**
```
Bluetooth speaker controller for Bluesound devices
```
*(max. 80 Zeichen, kein Punkt am Ende)*

**Datei: `fastlane/metadata/android/en-US/full_description.txt`**
```
BluesoundPlayer lets you control your Bluesound network speakers directly
from your Android device.

Features:
- Browse and play music
- Control volume and playback
- ...
```
*(max. 4000 Zeichen)*

**Datei: `fastlane/metadata/android/en-US/changelogs/1.txt`**
*(Dateiname = versionCode)*
```
Initial release.
```
*(max. 500 Zeichen)*

**Optional – Screenshots ablegen:**
```bash
mkdir -p fastlane/metadata/android/en-US/images/phoneScreenshots
# PNG-Dateien dort ablegen: 1.png, 2.png, ...
```

### 1.6 Non-FOSS-Abhängigkeiten bereinigen
```bash
# Gradle-Dateien auf proprietäre Bibliotheken prüfen
grep -r "firebase\|google-services\|gms\|crashlytics\|fabric" app/build.gradle*
grep -r "implementation" app/build.gradle* | grep -i "google\|firebase\|play-services"
```

**Falls proprietäre Abhängigkeiten gefunden:**
- Entweder entfernen
- Oder einen `fdroid`-Build-Flavor anlegen, der diese ausschließt

**Datei: `app/build.gradle.kts` (Pflicht für F-Droid):**
```kotlin
android {
    // ...
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}
```

### 1.7 Änderungen committen und pushen
```bash
git add fastlane/ app/build.gradle*
git commit -m "Add F-Droid metadata and fastlane descriptions"
git push origin main
```

---

## Phase 2: GitLab-Account & fdroiddata Fork

### 2.1 GitLab-Account erstellen
- Registrierung unter: https://gitlab.com/users/sign_up
- Hinweis: F-Droid CI läuft unter GitLab's FOSS-Programm, kein bezahltes Abo nötig

### 2.2 fdroiddata forken
```bash
# Im Browser: https://gitlab.com/fdroid/fdroiddata → "Fork"
# Dann lokal klonen (shallow clone spart Bandbreite ~2 GB Build-Umgebung)
git clone --depth=1 https://gitlab.com/DEIN_GITLAB_USER/fdroiddata ~/fdroiddata
cd ~/fdroiddata
```

---

## Phase 3: Metadaten-Datei erstellen

### 3.1 Neuen Branch anlegen
```bash
cd ~/fdroiddata
git checkout -b com.carl.bluesoundplayer
```

### 3.2 YAML-Metadaten-Datei anlegen
```bash
# Dateiname = applicationId aus build.gradle
touch metadata/com.carl.bluesoundplayer.yml
```

**Inhalt `metadata/com.carl.bluesoundplayer.yml`:**
```yaml
Categories:
  - Multimedia

License: GPL-3.0-or-later   # Anpassen an tatsächliche Lizenz

AuthorName: Carl
AuthorEmail: deine@email.de  # Optional

WebSite: https://github.com/DEIN_USER/bluesoundplayer
SourceCode: https://github.com/DEIN_USER/bluesoundplayer
IssueTracker: https://github.com/DEIN_USER/bluesoundplayer/issues

RepoType: git
Repo: https://github.com/DEIN_USER/bluesoundplayer

Builds:
  - versionName: '1.0'
    versionCode: 1
    commit: v1.0          # Muss dem Git-Tag entsprechen
    subdir: app           # Verzeichnis mit build.gradle
    gradle:
      - yes               # Standard Gradle-Build

AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: '1.0'
CurrentVersionCode: 1
```

**Anpassen falls nötig:**
- `subdir`: Pfad zu `build.gradle` (meist `app`)
- `sudo`: Nur wenn besondere System-Pakete beim Build benötigt werden
- `gradle`: Bei Flavors z.B. `- fdroid` statt `- yes`

---

## Phase 4: Metadaten lokal testen

### 4.1 fdroidserver installieren
```bash
pip install fdroidserver
# oder via apt:
# sudo apt-get install fdroidserver
```

### 4.2 Metadaten-Syntax prüfen
```bash
cd ~/fdroiddata
fdroid readmeta
# Muss fehlerfrei durchlaufen
```

### 4.3 App lokal bauen (optional, aber empfohlen)
```bash
# Android SDK muss installiert sein
# ANDROID_HOME setzen falls nötig
export ANDROID_HOME=/path/to/android-sdk

fdroid build com.carl.bluesoundplayer
# Bei Erfolg: Build-Artefakt in ~/fdroiddata/unsigned/
```

---

## Phase 5: Merge Request einreichen

### 5.1 Committen und pushen
```bash
cd ~/fdroiddata
git add metadata/com.carl.bluesoundplayer.yml
git commit -m "New App: BluesoundPlayer"
git push origin com.carl.bluesoundplayer
```

### 5.2 Merge Request auf GitLab erstellen
- URL: `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/new`
- Source branch: `DEIN_GITLAB_USER/fdroiddata:com.carl.bluesoundplayer`
- Target branch: `fdroid/fdroiddata:master`
- Titel: `New App: BluesoundPlayer`
- Beschreibung: Kurze App-Beschreibung + Link zum GitHub-Repo

### 5.3 Nach dem Einreichen
- F-Droid CI läuft automatisch und prüft die Metadaten
- Das F-Droid-Team reviewt und gibt Feedback im MR
- **Antworten auf Kommentare zeitnah** – sonst kann der MR stagnieren
- Bei Erfolg: App erscheint beim nächsten Build-Zyklus (kann einige Tage dauern)

---

## Hilfreiche Links

| Ressource | URL |
|---|---|
| F-Droid Quick Start Guide | https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/ |
| Inclusion Policy | https://f-droid.org/docs/Inclusion_Policy/ |
| Build Metadata Reference | https://f-droid.org/docs/Build_Metadata_Reference/ |
| fdroiddata Repository | https://gitlab.com/fdroid/fdroiddata |
| Submission Queue (Weg A) | https://gitlab.com/fdroid/rfp/issues |
| F-Droid Forum / Matrix | https://f-droid.org/en/contribute/ |

---

## Checkliste

- [ ] `LICENSE`-Datei im Repo vorhanden
- [ ] `applicationId` in `build.gradle` gesetzt
- [ ] `versionName` und `versionCode` korrekt
- [ ] Git-Tag `v1.0` gesetzt und gepusht
- [ ] `fastlane/metadata/android/en-US/` Dateien angelegt
- [ ] `dependenciesInfo` Block in `build.gradle` eingetragen
- [ ] Keine proprietären Abhängigkeiten in Gradle-Dateien
- [ ] GitLab-Account erstellt
- [ ] `fdroiddata` geforkt und geklont
- [ ] YAML-Datei `metadata/com.carl.bluesoundplayer.yml` angelegt
- [ ] `fdroid readmeta` ohne Fehler
- [ ] Merge Request eingereicht
