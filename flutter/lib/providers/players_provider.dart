import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/network_scanner.dart';
import '../api/api.dart';

/// State for the players list.
class PlayersState {
  final List<PlayerInfo> players;
  final PlayerInfo? selectedPlayer;
  final bool isScanning;
  final String? error;
  final String? scanMessage;

  const PlayersState({
    this.players = const [],
    this.selectedPlayer,
    this.isScanning = false,
    this.error,
    this.scanMessage,
  });

  PlayersState copyWith({
    List<PlayerInfo>? players,
    PlayerInfo? selectedPlayer,
    bool? isScanning,
    String? error,
    String? scanMessage,
    bool clearSelectedPlayer = false,
    bool clearError = false,
    bool clearScanMessage = false,
  }) {
    return PlayersState(
      players: players ?? this.players,
      selectedPlayer:
          clearSelectedPlayer ? null : (selectedPlayer ?? this.selectedPlayer),
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : (error ?? this.error),
      scanMessage:
          clearScanMessage ? null : (scanMessage ?? this.scanMessage),
    );
  }
}

/// Provider for managing the list of discovered players.
class PlayersNotifier extends StateNotifier<PlayersState> {
  final NetworkScanner _scanner;
  AudioClient? _currentClient;
  final Map<String, AudioClient> _clients = {};

  PlayersNotifier({NetworkScanner? scanner})
      : _scanner = scanner ?? NetworkScanner(),
        super(const PlayersState());

  /// The currently active audio client.
  AudioClient? get currentClient => _currentClient;

  /// Scan the network for players.
  Future<void> scan() async {
    state = state.copyWith(
      isScanning: true,
      clearError: true,
      scanMessage: 'Starting network scan...',
    );

    try {
      final players = await _scanner.scan(
        onProgress: (message) {
          state = state.copyWith(scanMessage: message);
        },
        onPlayerFound: (player) {
          // Add player immediately when found
          if (!state.players.any((p) => p.ip == player.ip)) {
            state = state.copyWith(
              players: [...state.players, player],
            );
          }
        },
      );

      state = state.copyWith(
        players: players,
        isScanning: false,
        clearScanMessage: true,
      );

      // Auto-select first player if none selected
      if (state.selectedPlayer == null && players.isNotEmpty) {
        selectPlayer(players.first);
      }
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: 'Failed to scan network: $e',
        clearScanMessage: true,
      );
    }
  }

  /// Select a player to control.
  void selectPlayer(PlayerInfo player) {
    _currentClient = clientFor(player);
    state = state.copyWith(selectedPlayer: player);
  }

  /// Get (and cache) a client for any player, not just the selected one.
  ///
  /// Needed to control grouped players individually.
  AudioClient clientFor(PlayerInfo player) {
    return _clients.putIfAbsent(
      '${player.type.name}:${player.ip}',
      () => _createClient(player),
    );
  }

  /// Create the appropriate client for a player.
  AudioClient _createClient(PlayerInfo player) {
    switch (player.type) {
      case DeviceType.bluos:
        return BluOSClient(player.ip);
      case DeviceType.sonos:
        return SonosClient(player.ip);
    }
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }
}

/// The players provider.
final playersProvider =
    StateNotifierProvider<PlayersNotifier, PlayersState>((ref) {
  return PlayersNotifier();
});
