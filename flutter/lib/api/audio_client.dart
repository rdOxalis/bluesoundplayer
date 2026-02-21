import '../models/models.dart';

/// Abstract interface for audio player clients.
///
/// Both BluOS and Sonos clients implement this interface,
/// allowing uniform control regardless of device type.
abstract class AudioClient {
  /// The IP address of the connected player.
  String get ip;

  /// The type of device this client controls.
  DeviceType get deviceType;

  /// Get current playback status.
  Future<Status> getStatus();

  /// Get available presets/favorites.
  Future<List<Preset>> getPresets();

  /// Play a specific preset by ID.
  Future<void> playPreset(int id);

  /// Start or resume playback.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Stop playback.
  Future<void> stop();

  /// Skip to next track.
  Future<void> next();

  /// Go to previous track.
  Future<void> previous();

  /// Set volume level (0-100).
  ///
  /// Throws [ArgumentError] if level is not in range 0-100.
  Future<void> setVolume(int level);

  /// Add a slave player to this master's group.
  ///
  /// For BluOS: master calls AddSlave with slave IP.
  /// For Sonos: slave calls SetAVTransportURI with x-rincon:<master-UUID>.
  /// [slaveIP] is the IP of the player to add.
  /// [slaveUuid] is the Sonos RINCON UUID (required for Sonos).
  /// [masterUuid] is this player's Sonos RINCON UUID (required for Sonos).
  Future<void> addSlave(String slaveIP, {String? slaveUuid, String? masterUuid});

  /// Remove a slave player from this master's group.
  ///
  /// For BluOS: master calls RemoveSlave.
  /// For Sonos: slave calls BecomeCoordinatorOfStandaloneGroup.
  Future<void> removeSlave(String slaveIP);

  /// Remove all slaves from this master's group.
  Future<void> removeAllSlaves();

  /// Leave the current group (as a slave).
  Future<void> leaveGroup();

  /// Get group info: returns a map of coordinator IP -> list of member IPs.
  /// Used to visualize which players are grouped together.
  Future<Map<String, List<String>>> getGroupInfo();

  /// Get current playback URI and metadata for transfer.
  /// [uri] is the abstract/service URI (for same-platform transfer).
  /// [metadata] is the associated metadata (DIDL-Lite for Sonos, empty for BluOS).
  /// [resolvedUri] is the actual stream URL (for cross-platform transfer).
  /// Returns null if nothing is playing or transfer not possible.
  Future<({String uri, String metadata, String? resolvedUri})?> getPlaybackInfo();

  /// Start playback of given URI with metadata (for transfer).
  Future<void> playUri(String uri, String metadata);

  /// Get debug information about API endpoints.
  String debugAPI();
}

/// Exception thrown when an API operation fails.
class AudioClientException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const AudioClientException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AudioClientException: $message';
}

/// Exception thrown when an operation is not supported.
class UnsupportedOperationException extends AudioClientException {
  const UnsupportedOperationException(String operation)
      : super('$operation is not supported for this device type');
}
