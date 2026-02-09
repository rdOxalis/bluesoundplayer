import '../models/models.dart';
import '../api/api.dart';

/// Service for managing audio playback across players.
class AudioService {
  AudioClient? _currentClient;
  PlayerInfo? _currentPlayer;

  /// The currently selected player.
  PlayerInfo? get currentPlayer => _currentPlayer;

  /// Whether a player is currently selected.
  bool get hasPlayer => _currentClient != null;

  /// Select a player to control.
  void selectPlayer(PlayerInfo player) {
    _currentPlayer = player;
    _currentClient = _createClient(player);
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

  /// Get current playback status.
  Future<Status> getStatus() async {
    _ensureClient();
    return _currentClient!.getStatus();
  }

  /// Get available presets.
  Future<List<Preset>> getPresets() async {
    _ensureClient();
    return _currentClient!.getPresets();
  }

  /// Play a preset by ID.
  Future<void> playPreset(int id) async {
    _ensureClient();
    await _currentClient!.playPreset(id);
  }

  /// Start playback.
  Future<void> play() async {
    _ensureClient();
    await _currentClient!.play();
  }

  /// Pause playback.
  Future<void> pause() async {
    _ensureClient();
    await _currentClient!.pause();
  }

  /// Stop playback.
  Future<void> stop() async {
    _ensureClient();
    await _currentClient!.stop();
  }

  /// Next track.
  Future<void> next() async {
    _ensureClient();
    await _currentClient!.next();
  }

  /// Previous track.
  Future<void> previous() async {
    _ensureClient();
    await _currentClient!.previous();
  }

  /// Set volume (0-100).
  Future<void> setVolume(int level) async {
    _ensureClient();
    await _currentClient!.setVolume(level);
  }

  /// Add a slave to the current player's group.
  Future<void> addSlave(String slaveIP) async {
    _ensureClient();
    await _currentClient!.addSlave(slaveIP);
  }

  /// Remove a slave from the current player's group.
  Future<void> removeSlave(String slaveIP) async {
    _ensureClient();
    await _currentClient!.removeSlave(slaveIP);
  }

  /// Remove all slaves from the current player's group.
  Future<void> removeAllSlaves() async {
    _ensureClient();
    await _currentClient!.removeAllSlaves();
  }

  /// Leave the current group (as a slave).
  Future<void> leaveGroup() async {
    _ensureClient();
    await _currentClient!.leaveGroup();
  }

  /// Check if grouping is supported for current player.
  bool get supportsGrouping => _currentPlayer != null;

  /// Get debug API info.
  String debugAPI() {
    return _currentClient?.debugAPI() ?? 'No player selected';
  }

  void _ensureClient() {
    if (_currentClient == null) {
      throw StateError('No player selected');
    }
  }
}
