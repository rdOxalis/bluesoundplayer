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
        child: Center(
          child: Text(
            '${preset.id}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
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
