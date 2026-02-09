import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Widget for playback control buttons.
class PlaybackControls extends ConsumerWidget {
  final bool large;

  const PlaybackControls({
    super.key,
    this.large = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statusState = ref.watch(statusProvider);
    final status = statusState.status;
    final isLoading = statusState.isLoading;

    final iconSize = large ? 48.0 : 32.0;
    final mainIconSize = large ? 64.0 : 48.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        IconButton(
          icon: Icon(Icons.skip_previous, size: iconSize),
          onPressed: isLoading ? null : () => _previous(ref),
          tooltip: l10n.previous,
        ),

        const SizedBox(width: 8),

        // Play/Pause button
        IconButton(
          icon: Icon(
            status?.isPlaying == true ? Icons.pause_circle : Icons.play_circle,
            size: mainIconSize,
          ),
          onPressed: isLoading ? null : () => _togglePlayPause(ref, status),
          tooltip: status?.isPlaying == true ? l10n.pause : l10n.play,
        ),

        const SizedBox(width: 8),

        // Stop button
        IconButton(
          icon: Icon(Icons.stop_circle, size: iconSize),
          onPressed: isLoading ? null : () => _stop(ref),
          tooltip: l10n.stop,
        ),

        const SizedBox(width: 8),

        // Next button
        IconButton(
          icon: Icon(Icons.skip_next, size: iconSize),
          onPressed: isLoading ? null : () => _next(ref),
          tooltip: l10n.next,
        ),
      ],
    );
  }

  Future<void> _togglePlayPause(WidgetRef ref, Status? status) async {
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    final statusNotifier = ref.read(statusProvider.notifier);

    if (status?.isPlaying == true) {
      await statusNotifier.executeAndRefresh(() => client.pause());
    } else {
      await statusNotifier.executeAndRefresh(() => client.play());
    }
  }

  Future<void> _stop(WidgetRef ref) async {
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    await ref.read(statusProvider.notifier).executeAndRefresh(() => client.stop());
  }

  Future<void> _next(WidgetRef ref) async {
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    await ref.read(statusProvider.notifier).executeAndRefresh(() => client.next());
  }

  Future<void> _previous(WidgetRef ref) async {
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    await ref.read(statusProvider.notifier).executeAndRefresh(() => client.previous());
  }
}
