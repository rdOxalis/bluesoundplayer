import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

/// Widget showing the currently playing track.
class NowPlaying extends ConsumerWidget {
  final bool compact;

  const NowPlaying({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusState = ref.watch(statusProvider);
    final playersState = ref.watch(playersProvider);

    final status = statusState.status;
    final player = playersState.selectedPlayer;
    final isLoading = statusState.isLoading;

    final theme = Theme.of(context);

    if (player == null) {
      return _buildNoPlayer(context);
    }

    if (compact) {
      return _buildCompact(context, status, player, isLoading);
    }

    return _buildFull(context, status, player, isLoading, theme);
  }

  Widget _buildNoPlayer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speaker,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noPlayerSelected,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    status,
    player,
    bool isLoading,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        // Album art placeholder
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.music_note,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),

        // Track info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status?.song.isNotEmpty == true
                    ? status!.song
                    : l10n.noSongPlaying,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (status?.artist.isNotEmpty == true)
                Text(
                  status!.artist,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Status indicator
        if (isLoading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          _buildStatusBadge(context, status?.stateDisplay ?? l10n.stopped),
      ],
    );
  }

  Widget _buildFull(
    BuildContext context,
    status,
    player,
    bool isLoading,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Album art placeholder
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.music_note,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),

        // Song title
        Text(
          status?.song.isNotEmpty == true ? status!.song : l10n.noSongPlaying,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // Artist
        if (status?.artist.isNotEmpty == true)
          Text(
            status!.artist,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        // Album
        if (status?.album.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            status!.album,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 16),

        // Status and player info
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Flexible(
                child: _buildStatusBadge(context, status?.stateDisplay ?? l10n.stopped),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                player.shortName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayState = state;

    switch (state.toLowerCase()) {
      case 'playing':
      case 'play':
      case 'stream':
        backgroundColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green;
        icon = Icons.play_arrow;
        displayState = l10n.playing;
        break;
      case 'paused':
      case 'pause':
      case 'paused_playback':
        backgroundColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange;
        icon = Icons.pause;
        displayState = l10n.paused;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.stop;
        displayState = l10n.stopped;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            displayState,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
