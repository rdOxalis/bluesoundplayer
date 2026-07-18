import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'players_provider.dart';
import 'status_provider.dart';

/// State for presets list.
class PresetsState {
  final List<Preset> presets;
  final bool isLoading;
  final String? error;

  const PresetsState({
    this.presets = const [],
    this.isLoading = false,
    this.error,
  });

  List<Preset> get stations =>
      presets.where((p) => p.category == PresetCategory.station).toList();
  List<Preset> get playlists =>
      presets.where((p) => p.category == PresetCategory.playlist).toList();
  List<Preset> get albums =>
      presets.where((p) => p.category == PresetCategory.album).toList();
  List<Preset> get songs =>
      presets.where((p) => p.category == PresetCategory.song).toList();

  PresetsState copyWith({
    List<Preset>? presets,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PresetsState(
      presets: presets ?? this.presets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for managing presets/favorites.
class PresetsNotifier extends StateNotifier<PresetsState> {
  final Ref _ref;

  PresetsNotifier(this._ref) : super(const PresetsState());

  /// Load presets from the selected player.
  Future<void> load() async {
    final client = _ref.read(playersProvider.notifier).currentClient;

    if (client == null) {
      state = state.copyWith(presets: [], clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final presets = await client.getPresets();
      state = state.copyWith(presets: presets, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load presets: $e',
      );
    }
  }

  /// Play a preset by ID.
  Future<void> playPreset(int id) async {
    final client = _ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    await client.playPreset(id);
    // Refresh status after playing
    await Future.delayed(const Duration(milliseconds: 500));
    await _ref.read(statusProvider.notifier).refresh();
  }
}

/// The presets provider.
final presetsProvider =
    StateNotifierProvider<PresetsNotifier, PresetsState>((ref) {
  final notifier = PresetsNotifier(ref);

  // Listen to player selection changes
  ref.listen<PlayersState>(playersProvider, (previous, next) {
    if (previous?.selectedPlayer != next.selectedPlayer) {
      notifier.load();
    }
  });

  return notifier;
});
