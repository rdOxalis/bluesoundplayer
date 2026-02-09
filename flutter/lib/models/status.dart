/// Playback status of an audio player.
class Status {
  final String state; // "playing", "paused", "stopped"
  final String song;
  final String artist;
  final String album;
  final int volume; // 0-100, -1 = N/A (e.g., grouped slave)

  const Status({
    required this.state,
    this.song = '',
    this.artist = '',
    this.album = '',
    this.volume = -1,
  });

  /// Empty/initial status.
  static const empty = Status(state: 'stopped');

  bool get isPlaying =>
      state.toLowerCase() == 'playing' ||
      state.toLowerCase() == 'play' ||
      state.toLowerCase() == 'stream';
  bool get isPaused =>
      state.toLowerCase() == 'paused' ||
      state.toLowerCase() == 'pause' ||
      state.toLowerCase() == 'paused_playback';
  bool get isStopped =>
      state.toLowerCase() == 'stopped' ||
      state.toLowerCase() == 'stop';

  /// Whether volume is available (not -1).
  bool get hasVolume => volume >= 0;

  /// Volume as percentage string, or "N/A" if unavailable.
  String get volumeDisplay => hasVolume ? '$volume%' : 'N/A';

  /// Whether any track info is available.
  bool get hasTrackInfo => song.isNotEmpty || artist.isNotEmpty;

  /// Formatted state for display.
  String get stateDisplay {
    switch (state.toLowerCase()) {
      case 'playing':
      case 'play':
      case 'stream':
        return 'Playing';
      case 'paused':
      case 'pause':
      case 'paused_playback':
        return 'Paused';
      case 'stopped':
      case 'stop':
        return 'Stopped';
      default:
        return state;
    }
  }

  @override
  String toString() =>
      'Status($state, song: $song, artist: $artist, volume: $volume)';

  Status copyWith({
    String? state,
    String? song,
    String? artist,
    String? album,
    int? volume,
  }) {
    return Status(
      state: state ?? this.state,
      song: song ?? this.song,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      volume: volume ?? this.volume,
    );
  }
}
