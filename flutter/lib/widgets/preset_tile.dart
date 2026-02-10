import 'package:flutter/material.dart';

import '../models/models.dart';

/// Tile widget for displaying a preset/favorite.
class PresetTile extends StatelessWidget {
  final Preset preset;
  final VoidCallback? onTap;

  const PresetTile({
    super.key,
    required this.preset,
    this.onTap,
  });

  IconData _categoryIcon(PresetCategory category) {
    switch (category) {
      case PresetCategory.station:
        return Icons.radio;
      case PresetCategory.playlist:
        return Icons.playlist_play;
      case PresetCategory.album:
        return Icons.album;
      case PresetCategory.song:
        return Icons.music_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _categoryIcon(preset.category),
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        preset.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.play_circle_outline),
      onTap: onTap,
    );
  }
}
