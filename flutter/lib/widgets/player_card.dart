import 'package:flutter/material.dart';

import '../models/models.dart';

/// Card widget displaying a player's information.
class PlayerCard extends StatelessWidget {
  final PlayerInfo player;
  final bool isSelected;
  final String? groupRole;
  final String? groupSubtitle;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    this.isSelected = false,
    this.groupRole,
    this.groupSubtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGrouped = groupRole != null;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Device type icon with group indicator
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      player.isBluOS ? Icons.speaker_group : Icons.speaker,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isGrouped)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: groupRole == 'coordinator'
                              ? Colors.green
                              : Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          groupRole == 'coordinator'
                              ? Icons.hub
                              : Icons.link,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.shortName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${player.brand} ${player.model}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      player.ip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (groupSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        groupSubtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Device type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: player.isBluOS
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  player.isBluOS ? 'BluOS' : 'Sonos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: player.isBluOS ? Colors.blue : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
