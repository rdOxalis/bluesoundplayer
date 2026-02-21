import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'players_provider.dart';

/// State for playback status.
class StatusState {
  final Status? status;
  final bool isLoading;
  final String? error;
  final bool isTransferable;

  const StatusState({
    this.status,
    this.isLoading = false,
    this.error,
    this.isTransferable = false,
  });

  StatusState copyWith({
    Status? status,
    bool? isLoading,
    String? error,
    bool? isTransferable,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return StatusState(
      status: clearStatus ? null : (status ?? this.status),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isTransferable: isTransferable ?? this.isTransferable,
    );
  }
}

/// Provider for managing playback status.
class StatusNotifier extends StateNotifier<StatusState> {
  final Ref _ref;
  Timer? _refreshTimer;

  StatusNotifier(this._ref) : super(const StatusState());

  /// Refresh the playback status.
  Future<void> refresh() async {
    final client = _ref.read(playersProvider).selectedPlayer != null
        ? _ref.read(playersProvider.notifier).currentClient
        : null;

    if (client == null) {
      state = state.copyWith(
          clearStatus: true, clearError: true, isTransferable: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final status = await client.getStatus();

      // Check if current content is transferable
      bool transferable = false;
      if (!status.isStopped) {
        try {
          final info = await client.getPlaybackInfo();
          transferable = info != null;
        } catch (_) {}
      }

      state = state.copyWith(
          status: status, isLoading: false, isTransferable: transferable);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isTransferable: false,
        error: 'Failed to get status: $e',
      );
    }
  }

  /// Start auto-refreshing status.
  void startAutoRefresh({Duration interval = const Duration(seconds: 5)}) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(interval, (_) => refresh());
  }

  /// Stop auto-refreshing status.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Execute an action and refresh status afterward.
  Future<void> executeAndRefresh(Future<void> Function() action) async {
    try {
      await action();
      // Small delay to let the device update
      await Future.delayed(const Duration(milliseconds: 500));
      await refresh();
    } catch (e) {
      state = state.copyWith(error: '$e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

/// The status provider.
final statusProvider =
    StateNotifierProvider<StatusNotifier, StatusState>((ref) {
  final notifier = StatusNotifier(ref);

  // Listen to player selection changes
  ref.listen<PlayersState>(playersProvider, (previous, next) {
    if (previous?.selectedPlayer != next.selectedPlayer) {
      notifier.refresh();
    }
  });

  return notifier;
});
