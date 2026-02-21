import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
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

  /// Get valid transfer targets for the current source player.
  /// - Sonos source: all other players (Sonos→Sonos and Sonos→BluOS work)
  /// - BluOS source: only other BluOS players (BluOS→Sonos not supported)
  List<PlayerInfo> _getTransferTargets(PlayersState playersState) {
    final selected = playersState.selectedPlayer;
    if (selected == null) return [];

    return playersState.players.where((p) {
      if (p.ip == selected.ip) return false;
      // BluOS source can only transfer to other BluOS players
      if (selected.isBluOS && p.isSonos) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statusState = ref.watch(statusProvider);
    final status = statusState.status;
    final isLoading = statusState.isLoading;
    final playersState = ref.watch(playersProvider);

    final iconSize = large ? 48.0 : 32.0;
    final mainIconSize = large ? 64.0 : 48.0;

    final transferTargets = _getTransferTargets(playersState);
    final showTransfer =
        transferTargets.isNotEmpty && statusState.isTransferable;

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

        // Transfer button - only shown when content is transferable and valid targets exist
        if (showTransfer) ...[
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.swap_horiz, size: iconSize * 0.75),
            onPressed: isLoading
                ? null
                : () => _showTransferDialog(context, ref, transferTargets),
            tooltip: l10n.transfer,
          ),
        ],
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

  void _showTransferDialog(
      BuildContext context, WidgetRef ref, List<PlayerInfo> targets) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.transferTo),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                return ListTile(
                  leading: Icon(
                    target.isSonos ? Icons.speaker_group : Icons.speaker,
                  ),
                  title: Text(target.shortName),
                  subtitle: Text('${target.brand} ${target.model}'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _executeTransfer(context, ref, target);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeTransfer(
    BuildContext context,
    WidgetRef ref,
    PlayerInfo targetPlayer,
  ) async {
    final l10n = AppLocalizations.of(context);
    final sourceClient = ref.read(playersProvider.notifier).currentClient;
    if (sourceClient == null) return;

    try {
      // 1. Get playback info from source
      final playbackInfo = await sourceClient.getPlaybackInfo();
      if (playbackInfo == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.nothingPlaying)),
          );
        }
        return;
      }

      // 2. Create target client
      final AudioClient targetClient;
      switch (targetPlayer.type) {
        case DeviceType.bluos:
          targetClient = BluOSClient(targetPlayer.ip);
        case DeviceType.sonos:
          targetClient = SonosClient(targetPlayer.ip);
      }

      // 3. Start playback on target
      final bool crossPlatform =
          sourceClient.deviceType != targetClient.deviceType;

      if (!crossPlatform) {
        // Same platform: use abstract URI + metadata
        await targetClient.playUri(playbackInfo.uri, playbackInfo.metadata);
      } else {
        // Sonos→BluOS: use resolved HTTP URL
        final transferUri = playbackInfo.resolvedUri ?? playbackInfo.uri;
        await targetClient.playUri(transferUri, '');
      }

      // 4. Stop source
      await sourceClient.stop();

      // 5. Switch to target player
      ref.read(playersProvider.notifier).selectPlayer(targetPlayer);

      // 6. Refresh status
      await Future.delayed(const Duration(milliseconds: 500));
      await ref.read(statusProvider.notifier).refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.transferSuccess}: ${targetPlayer.shortName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.transferFailed}: $e')),
        );
      }
    }
  }
}
