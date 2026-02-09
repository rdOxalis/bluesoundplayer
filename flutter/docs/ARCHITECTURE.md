# BluOS Multi-Room Audio Controller - Flutter Architecture Design

## Phase 1: Analyse & Architektur-Design

**Erstellt:** 2026-02-04
**Status:** Design-Phase
**Basiert auf:** Go CLI Implementierung v1.0

---

## 1. Requirements Analysis

### 1.1 Funktionale Anforderungen (aus CLI)

#### Geräte-Discovery
| Anforderung | Priorität | CLI-Referenz |
|-------------|-----------|--------------|
| BluOS-Geräte im Netzwerk finden | Hoch | `network.go:checkBluOS()` |
| Sonos-Geräte im Netzwerk finden | Hoch | `network.go:checkSonos()` |
| Paralleles Scanning (1-254 pro Subnetz) | Hoch | `network.go:scanSubnet()` |
| Multi-Interface-Support | Mittel | `network.go:getNetworkInterfaces()` |
| Geräteinformationen anzeigen (Name, Modell, IP) | Hoch | `common.go:PlayerInfo` |

#### Wiedergabe-Steuerung
| Anforderung | Priorität | CLI-Referenz |
|-------------|-----------|--------------|
| Play/Pause/Stop | Hoch | `AudioClient` Interface |
| Nächster/Vorheriger Track | Hoch | `Next()`, `Previous()` |
| Lautstärke (0-100%) | Hoch | `SetVolume()` |
| Preset/Favoriten abspielen | Hoch | `PlayPreset()` |
| Status-Anzeige (Song, Artist, Album) | Hoch | `GetStatus()` |

#### Multi-Room
| Anforderung | Priorität | CLI-Referenz |
|-------------|-----------|--------------|
| Player-Gruppierung (Master-Slave) | Mittel | `AddSlave()`, `RemoveSlave()` |
| Gruppe auflösen | Mittel | `RemoveAllSlaves()` |
| Nur BluOS (Sonos nicht unterstützt) | Info | Sonos: "not implemented" |

#### Lokalisierung
| Anforderung | Priorität | CLI-Referenz |
|-------------|-----------|--------------|
| Englisch | Hoch | `localization.go` |
| Deutsch | Hoch | `localization.go` |
| Swahili | Mittel | `localization.go` |

### 1.2 Nicht-Funktionale Anforderungen

| Anforderung | Ziel | Messung |
|-------------|------|---------|
| Discovery-Zeit | < 5 Sekunden | Vom Start bis Player-Liste |
| API-Timeout | 10 Sekunden | HTTP Request Timeout |
| Scan-Timeout | 3 Sekunden | Pro Gerät |
| Responsiveness | Sofort | UI-Feedback bei Aktionen |
| Plattformen | 5 | Linux, Windows, macOS, iOS, Android |

### 1.3 Benutzer-Workflows

```
Workflow 1: Erste Nutzung
┌─────────────────────────────────────────────────────────┐
│ App starten → Netzwerk scannen → Player anzeigen →      │
│ Player auswählen → Status sehen → Musik steuern         │
└─────────────────────────────────────────────────────────┘

Workflow 2: Preset abspielen
┌─────────────────────────────────────────────────────────┐
│ Player auswählen → Presets laden → Preset wählen →      │
│ Wiedergabe startet → Status aktualisiert                │
└─────────────────────────────────────────────────────────┘

Workflow 3: Multi-Room (BluOS)
┌─────────────────────────────────────────────────────────┐
│ Master auswählen → Slave(s) hinzufügen → Gruppe aktiv → │
│ Master steuert alle → Ungroup bei Bedarf                │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Technical Architecture

### 2.1 Architektur-Übersicht

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Screens   │  │   Widgets   │  │   Platform Adapters     │  │
│  │  - Home     │  │  - Player   │  │  - Desktop Layout       │  │
│  │  - Players  │  │  - Controls │  │  - Mobile Layout        │  │
│  │  - Presets  │  │  - Volume   │  │  - Responsive Breakpts  │  │
│  │  - Settings │  │  - Status   │  │                         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT (Riverpod)                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ PlayersProvider │  │ StatusProvider  │  │ SettingsProvider│  │
│  │ - discovered    │  │ - currentStatus │  │ - language      │  │
│  │ - selected      │  │ - isPlaying     │  │ - theme         │  │
│  │ - groups        │  │ - volume        │  │ - autoRefresh   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │ PresetsProvider │  │ NetworkProvider │                       │
│  │ - presets       │  │ - isScanning    │                       │
│  │ - favorites     │  │ - interfaces    │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        SERVICE LAYER                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ NetworkScanner  │  │ AudioService    │  │ StorageService  │  │
│  │ - scanSubnet()  │  │ - play/pause    │  │ - preferences   │  │
│  │ - detectDevice()│  │ - volume        │  │ - cache         │  │
│  └─────────────────┘  │ - presets       │  └─────────────────┘  │
│                       └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API LAYER                                │
│  ┌─────────────────────────┐  ┌─────────────────────────────┐   │
│  │     BluOSClient         │  │       SonosClient           │   │
│  │  ┌─────────────────┐    │  │  ┌─────────────────────┐    │   │
│  │  │ HTTP GET Requests│    │  │  │ SOAP/UPnP Requests  │    │   │
│  │  │ Port: 11000      │    │  │  │ Port: 1400          │    │   │
│  │  │ XML Responses    │    │  │  │ XML/DIDL Responses  │    │   │
│  │  └─────────────────┘    │  │  └─────────────────────┘    │   │
│  └─────────────────────────┘  └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER (Models)                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │PlayerInfo│ │  Status  │ │  Preset  │ │  Group   │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Projektstruktur

```
bluesoundplayer_flutter/
├── lib/
│   ├── main.dart                      # App Entry Point
│   │
│   ├── models/                        # Domain Models
│   │   ├── player_info.dart           # PlayerInfo
│   │   ├── status.dart                # Status
│   │   ├── preset.dart                # Preset
│   │   └── device_type.dart           # DeviceType Enum
│   │
│   ├── api/                           # API Clients
│   │   ├── audio_client.dart          # Abstract Interface
│   │   ├── bluos_client.dart          # BluOS REST Client
│   │   └── sonos_client.dart          # Sonos SOAP Client
│   │
│   ├── services/                      # Business Logic
│   │   ├── network_scanner.dart       # Device Discovery
│   │   ├── audio_service.dart         # Playback Control
│   │   └── storage_service.dart       # Local Storage
│   │
│   ├── providers/                     # State Management
│   │   ├── players_provider.dart      # Player State
│   │   ├── status_provider.dart       # Playback Status
│   │   ├── presets_provider.dart      # Presets State
│   │   ├── settings_provider.dart     # App Settings
│   │   └── network_provider.dart      # Network State
│   │
│   ├── screens/                       # Full Screens
│   │   ├── home_screen.dart           # Main Screen
│   │   ├── players_screen.dart        # Player Selection
│   │   ├── presets_screen.dart        # Presets List
│   │   └── settings_screen.dart       # Settings
│   │
│   ├── widgets/                       # Reusable Widgets
│   │   ├── player_card.dart           # Player Display
│   │   ├── playback_controls.dart     # Play/Pause/Stop
│   │   ├── volume_slider.dart         # Volume Control
│   │   ├── now_playing.dart           # Current Track
│   │   ├── preset_tile.dart           # Preset Item
│   │   └── group_dialog.dart          # Grouping UI
│   │
│   ├── layouts/                       # Responsive Layouts
│   │   ├── desktop_layout.dart        # Desktop Shell
│   │   ├── mobile_layout.dart         # Mobile Shell
│   │   └── responsive_builder.dart    # Breakpoint Logic
│   │
│   └── l10n/                          # Localization
│       ├── app_en.arb                 # English
│       ├── app_de.arb                 # German
│       └── app_sw.arb                 # Swahili
│
├── test/                              # Tests
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml                       # Dependencies
└── README.md                          # Documentation
```

### 2.3 Datenmodelle (Dart)

```dart
// device_type.dart
enum DeviceType {
  bluos('bluos'),
  sonos('sonos');

  final String value;
  const DeviceType(this.value);
}

// player_info.dart
class PlayerInfo {
  final String ip;
  final String name;
  final String brand;
  final String model;
  final DeviceType type;

  const PlayerInfo({
    required this.ip,
    required this.name,
    required this.brand,
    required this.model,
    required this.type,
  });
}

// status.dart
class Status {
  final String state;        // "playing", "paused", "stopped"
  final String song;
  final String artist;
  final String album;
  final int volume;          // 0-100, -1 = N/A

  const Status({
    required this.state,
    this.song = '',
    this.artist = '',
    this.album = '',
    this.volume = -1,
  });

  bool get isPlaying => state == 'playing';
  bool get isPaused => state == 'paused';
  bool get isStopped => state == 'stopped';
  bool get hasVolume => volume >= 0;
}

// preset.dart
class Preset {
  final int id;
  final String name;
  final String url;
  final String image;

  const Preset({
    required this.id,
    required this.name,
    this.url = '',
    this.image = '',
  });
}
```

### 2.4 API Client Interface

```dart
// audio_client.dart
abstract class AudioClient {
  DeviceType get deviceType;

  // Status
  Future<Status> getStatus();

  // Presets
  Future<List<Preset>> getPresets();
  Future<void> playPreset(int id);

  // Playback
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();

  // Volume
  Future<void> setVolume(int level);

  // Grouping (BluOS only)
  Future<void> addSlave(String slaveIP);
  Future<void> removeSlave(String slaveIP);
  Future<void> removeAllSlaves();
  Future<void> leaveGroup();

  // Debug
  String debugAPI();
}
```

### 2.5 State Management (Riverpod)

```dart
// players_provider.dart
@riverpod
class PlayersNotifier extends _$PlayersNotifier {
  @override
  PlayersState build() => const PlayersState();

  Future<void> scan() async { ... }
  void selectPlayer(PlayerInfo player) { ... }
}

class PlayersState {
  final List<PlayerInfo> discovered;
  final PlayerInfo? selected;
  final bool isScanning;
  final String? error;

  const PlayersState({
    this.discovered = const [],
    this.selected,
    this.isScanning = false,
    this.error,
  });
}

// status_provider.dart
@riverpod
class StatusNotifier extends _$StatusNotifier {
  Timer? _refreshTimer;

  @override
  AsyncValue<Status> build() => const AsyncValue.loading();

  Future<void> refresh() async { ... }
  void startAutoRefresh(Duration interval) { ... }
  void stopAutoRefresh() { ... }
}

// presets_provider.dart
@riverpod
class PresetsNotifier extends _$PresetsNotifier {
  @override
  AsyncValue<List<Preset>> build() => const AsyncValue.loading();

  Future<void> load() async { ... }
  Future<void> playPreset(int id) async { ... }
}
```

### 2.6 Netzwerk-Konfiguration

```dart
// network_scanner.dart
class NetworkScanner {
  static const bluosPort = 11000;
  static const sonosPort = 1400;
  static const scanTimeout = Duration(seconds: 3);
  static const httpTimeout = Duration(seconds: 10);

  // Subnet-Bereiche
  static const allowedPrefixes = ['192.168.', '10.0.0.', '10.0.1.', '172.16.'];
  static const blockedPrefixes = ['10.0.2.', '172.17.'];  // VirtualBox, Docker

  Future<List<PlayerInfo>> scanNetwork() async {
    final interfaces = await _getNetworkInterfaces();
    final futures = <Future<List<PlayerInfo>>>[];

    for (final interface in interfaces) {
      if (_isUsefulNetwork(interface.subnet)) {
        futures.add(_scanSubnet(interface.subnet));
      }
    }

    final results = await Future.wait(futures);
    return _deduplicateAndSort(results.expand((x) => x).toList());
  }

  Future<List<PlayerInfo>> _scanSubnet(String subnet) async {
    final futures = List.generate(254, (i) => _checkHost('$subnet.${i + 1}'));
    final results = await Future.wait(futures);
    return results.whereType<PlayerInfo>().toList();
  }
}
```

---

## 3. UI/UX Design Decisions

### 3.1 Responsive Breakpoints

| Breakpoint | Breite | Layout | Zielgerät |
|------------|--------|--------|-----------|
| Compact | < 600px | Mobile | Smartphones |
| Medium | 600-840px | Tablet Portrait | Tablets |
| Expanded | > 840px | Desktop | Desktop, Tablet Landscape |

### 3.2 Desktop Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  🎵 BluOS Controller                    [DE ▼] [🌙] [⚙️]        │
├────────────────┬─────────────────────────────┬───────────────────┤
│                │                             │                   │
│  📱 PLAYERS    │      NOW PLAYING            │  📋 PRESETS       │
│                │                             │                   │
│  ┌──────────┐  │   ┌─────────────────────┐   │  ┌─────────────┐  │
│  │ Kitchen  │◀─│   │                     │   │  │ 1. Jazz FM  │  │
│  │ BluOS    │  │   │   🎨 Album Art      │   │  ├─────────────┤  │
│  └──────────┘  │   │                     │   │  │ 2. Classic  │  │
│  ┌──────────┐  │   └─────────────────────┘   │  ├─────────────┤  │
│  │ Living   │  │                             │  │ 3. News     │  │
│  │ Sonos    │  │   Song Title                │  ├─────────────┤  │
│  └──────────┘  │   Artist Name               │  │ 4. Podcast  │  │
│  ┌──────────┐  │   Album Name                │  └─────────────┘  │
│  │ Bedroom  │  │                             │                   │
│  │ BluOS    │  │    advancement bar ───────   │  [🔍 Search...]   │
│  └──────────┘  │                             │                   │
│                │                             │                   │
│  [+ Group]     │                             │                   │
│                │                             │                   │
├────────────────┴─────────────────────────────┴───────────────────┤
│     ⏮️    ▶️/⏸️    ⏹️    ⏭️          🔊 ═══════════○═══ 75%       │
└──────────────────────────────────────────────────────────────────┘
```

### 3.3 Mobile Layout

```
┌────────────────────────┐
│  🎵 BluOS Controller   │
├────────────────────────┤
│                        │
│   ┌────────────────┐   │
│   │                │   │
│   │  🎨 Album Art  │   │
│   │                │   │
│   └────────────────┘   │
│                        │
│   Song Title           │
│   Artist Name          │
│   Album Name           │
│                        │
│   ═══════○═══════      │
│   0:45 ────── 3:21     │
│                        │
│   🔊 ═══════○═══ 75%   │
│                        │
│    ⏮️   ▶️/⏸️   ⏭️     │
│                        │
├────────────────────────┤
│  🏠    📱    📋    ⚙️   │
│ Home Players Presets Set│
└────────────────────────┘
```

### 3.4 Farb-Schema

```dart
// Light Theme
const lightColors = ColorScheme(
  primary: Color(0xFF1976D2),        // Blue
  onPrimary: Colors.white,
  secondary: Color(0xFF26A69A),      // Teal
  surface: Colors.white,
  background: Color(0xFFF5F5F5),
  error: Color(0xFFD32F2F),
);

// Dark Theme
const darkColors = ColorScheme(
  primary: Color(0xFF64B5F6),        // Light Blue
  onPrimary: Colors.black,
  secondary: Color(0xFF80CBC4),      // Light Teal
  surface: Color(0xFF1E1E1E),
  background: Color(0xFF121212),
  error: Color(0xFFEF5350),
);
```

### 3.5 Interaktionsmuster

| Aktion | Desktop | Mobile |
|--------|---------|--------|
| Player wählen | Klick in Liste | Tab "Players" + Tap |
| Volume | Horizontaler Slider | Vertikaler Slider / Wheel |
| Preset spielen | Doppelklick | Single Tap |
| Player gruppieren | Drag & Drop | Multi-Select + FAB |
| Refresh | Button + Keyboard (F5) | Pull-to-Refresh |
| Einstellungen | Toolbar Icons | Bottom Navigation |

---

## 4. Feature Parity Mapping

### 4.1 Vollständige Feature-Matrix

| CLI Feature | Flutter Implementierung | Priorität | Notizen |
|-------------|------------------------|-----------|---------|
| **Netzwerk Scan** | `NetworkScanner.scanNetwork()` | P0 | Parallel mit Future.wait |
| **BluOS Detection** | GET `/SyncStatus` | P0 | Port 11000 |
| **Sonos Detection** | GET `/xml/device_description.xml` | P0 | Port 1400 |
| **Player Liste** | `PlayersProvider` + ListView | P0 | Mit Status-Badges |
| **Player Auswahl** | `selectPlayer()` Methode | P0 | |
| **Status Anzeige** | `StatusProvider` + Now Playing Widget | P0 | Auto-Refresh |
| **Play** | `AudioClient.play()` | P0 | |
| **Pause** | `AudioClient.pause()` | P0 | |
| **Stop** | `AudioClient.stop()` | P0 | |
| **Next Track** | `AudioClient.next()` | P0 | |
| **Previous Track** | `AudioClient.previous()` | P0 | |
| **Volume Slider** | `VolumeSlider` Widget | P0 | 0-100% |
| **Volume -1 Handling** | Slider disabled | P1 | Für grouped slaves |
| **Presets laden** | `PresetsProvider.load()` | P0 | |
| **Preset abspielen** | `AudioClient.playPreset(id)` | P0 | |
| **Presets Liste** | `PresetsScreen` | P0 | Mit Suche |
| **Sprache: EN** | `app_en.arb` | P0 | |
| **Sprache: DE** | `app_de.arb` | P0 | |
| **Sprache: SW** | `app_sw.arb` | P1 | |
| **Player Gruppierung** | `GroupDialog` + Drag&Drop | P1 | Nur BluOS |
| **Ungroup All** | `AudioClient.removeAllSlaves()` | P1 | |
| **Leave Group** | `AudioClient.leaveGroup()` | P1 | |
| **Debug API** | Settings > Debug | P2 | Für Entwicklung |
| **Error Handling** | SnackBar + Error States | P0 | Graceful degradation |
| **Auto-Refresh** | Timer 5s (konfigurierbar) | P1 | Wie CLI nach Kommando |

### 4.2 API Endpoint Mapping

#### BluOS (HTTP GET, Port 11000)

| CLI Funktion | Endpoint | Flutter Methode |
|--------------|----------|-----------------|
| `GetStatus()` | `/Status` | `BluOSClient.getStatus()` |
| `GetPresets()` | `/Presets` | `BluOSClient.getPresets()` |
| `Play()` | `/Play` | `BluOSClient.play()` |
| `Pause()` | `/Pause` | `BluOSClient.pause()` |
| `Stop()` | `/Stop` | `BluOSClient.stop()` |
| `Next()` | `/Skip` | `BluOSClient.next()` |
| `Previous()` | `/Back` | `BluOSClient.previous()` |
| `SetVolume(n)` | `/Volume?level=n` | `BluOSClient.setVolume(n)` |
| `PlayPreset(n)` | `/Preset?id=n` | `BluOSClient.playPreset(n)` |
| `AddSlave(ip)` | `/AddSlave?slave=ip` | `BluOSClient.addSlave(ip)` |
| `RemoveSlave(ip)` | `/RemoveSlave?slave=ip` | `BluOSClient.removeSlave(ip)` |
| `RemoveAllSlaves()` | `/RemoveAllSlaves` | `BluOSClient.removeAllSlaves()` |
| `LeaveGroup()` | `/LeaveGroup` | `BluOSClient.leaveGroup()` |
| Device Info | `/SyncStatus` | `NetworkScanner._checkBluOS()` |

#### Sonos (SOAP/UPnP, Port 1400)

| CLI Funktion | SOAP Action | Service Path |
|--------------|-------------|--------------|
| `GetStatus()` | `GetTransportInfo` + `GetPositionInfo` + `GetVolume` | AVTransport + RenderingControl |
| `GetPresets()` | `Browse` (ContentDirectory) | `/MediaServer/ContentDirectory/Control` |
| `Play()` | `Play` | `/MediaRenderer/AVTransport/Control` |
| `Pause()` | `Pause` | `/MediaRenderer/AVTransport/Control` |
| `Stop()` | `Stop` | `/MediaRenderer/AVTransport/Control` |
| `Next()` | `Next` | `/MediaRenderer/AVTransport/Control` |
| `Previous()` | `Previous` | `/MediaRenderer/AVTransport/Control` |
| `SetVolume(n)` | `SetVolume` | `/MediaRenderer/RenderingControl/Control` |
| `PlayPreset(n)` | `SetAVTransportURI` + `Play` | AVTransport |
| Device Info | GET `/xml/device_description.xml` | Plain HTTP |

### 4.3 Lokalisierungs-Keys (ARB Format)

```json
// app_en.arb
{
  "@@locale": "en",
  "appTitle": "Multi-Room Audio Controller",
  "availablePlayers": "Available Players",
  "currentPlayer": "Current Player",
  "availablePresets": "Available Presets/Favorites",
  "statusVolume": "Status: {state} | Volume: {volume}",
  "@statusVolume": {
    "placeholders": {
      "state": {"type": "String"},
      "volume": {"type": "String"}
    }
  },
  "volumeUnknown": "N/A",
  "noSongPlaying": "No song playing",
  "playbackStarted": "Playback started",
  "paused": "Paused",
  "stopped": "Stopped",
  "volumeSet": "Volume set to {level}%",
  "@volumeSet": {
    "placeholders": {"level": {"type": "int"}}
  },
  "playingPreset": "Playing preset {id}",
  "switchedToPlayer": "Switched to player {index}: {name}",
  "groupedPlayers": "Grouped players: {master} as master",
  "ungroupedAll": "All player groups removed",
  "errorRetrievingStatus": "Error retrieving status",
  "errorLoadingPresets": "Error loading presets/favorites",
  "invalidPresetId": "Invalid preset/favorite ID",
  "scanning": "Scanning network for audio players...",
  "noPlayersFound": "No audio players found",
  "groupingNotSupported": "Grouping only supported for BluOS devices"
}
```

---

## 5. Dependencies (pubspec.yaml)

```yaml
name: bluesoundplayer_flutter
description: BluOS Multi-Room Audio Controller
version: 1.0.0

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Networking
  http: ^1.2.0
  xml: ^6.5.0

  # Localization
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

  # Storage
  shared_preferences: ^2.2.2

  # UI
  flutter_adaptive_scaffold: ^0.1.7  # Responsive layouts

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.8
  mockito: ^5.4.4

flutter:
  uses-material-design: true
  generate: true  # For localization
```

---

## 6. Implementierungs-Reihenfolge

### Sprint 1: Foundation (Woche 1-2)
1. Projekt-Setup mit Riverpod
2. Domain Models implementieren
3. BluOS Client (einfacher als Sonos)
4. Basis Network Scanner
5. Einfache Player-Liste UI

### Sprint 2: Core Features (Woche 3-4)
1. Sonos Client (SOAP)
2. Playback Controls Widget
3. Volume Slider
4. Now Playing Widget
5. Presets Screen

### Sprint 3: Polish (Woche 5-6)
1. Responsive Layouts (Desktop/Mobile)
2. Lokalisierung (EN, DE, SW)
3. Error Handling & Loading States
4. Theme Support (Light/Dark)
5. Settings Screen

### Sprint 4: Advanced (Woche 7-8)
1. Player Grouping UI (BluOS)
2. Auto-Refresh Timer
3. Keyboard Shortcuts (Desktop)
4. Pull-to-Refresh (Mobile)
5. Testing & Bug Fixes

---

## 7. Risiken & Mitigationen

| Risiko | Wahrscheinlichkeit | Impact | Mitigation |
|--------|-------------------|--------|------------|
| Sonos SOAP-Komplexität | Hoch | Mittel | Gründliche Tests, Fallback-Mechanismen |
| Netzwerk-Timeouts | Mittel | Niedrig | Konfigurierbare Timeouts, Retry-Logik |
| Cross-Platform Netzwerk | Mittel | Hoch | Platform-spezifische Implementierungen prüfen |
| Radio-Station-Detection (Sonos) | Hoch | Niedrig | Regex-Pattern aus Go übernehmen |
| Volume -1 Edge Case | Niedrig | Niedrig | UI disabled state |

---

## 8. Erfolgskriterien

- [ ] Alle CLI-Features in Flutter verfügbar
- [ ] Läuft auf Linux, Windows, macOS, iOS, Android
- [ ] Device Discovery < 5 Sekunden
- [ ] Keine Crashes bei Netzwerk-Fehlern
- [ ] 3 Sprachen vollständig übersetzt
- [ ] Responsive auf allen Bildschirmgrößen
- [ ] Unit Test Coverage > 80%

---

## Anhang: Go zu Dart Konvertierungstabelle

| Go | Dart |
|----|------|
| `struct` | `class` / `@freezed` |
| `interface` | `abstract class` |
| `error` | `Exception` / `Result<T>` |
| `goroutine` | `Future` / `Isolate` |
| `channel` | `Stream` / `StreamController` |
| `xml.Unmarshal` | `xml.XmlDocument.parse()` |
| `http.Client` | `http.Client` |
| `fmt.Sprintf` | `String interpolation` |
| `time.Duration` | `Duration` |
| `sync.WaitGroup` | `Future.wait()` |
