import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

/// Screen showing available presets/favorites.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsState = ref.watch(presetsProvider);
    final playersState = ref.watch(playersProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(presetsProvider.notifier).load(),
        child: Column(
          children: [
            // Player info header
            if (playersState.selectedPlayer != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.speaker, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      playersState.selectedPlayer!.shortName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),

            // Error message
            if (presetsState.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        presetsState.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Presets list
            const Expanded(child: PresetsListView()),
          ],
        ),
      ),
    );
  }
}

/// List view of available presets.
class PresetsListView extends ConsumerWidget {
  const PresetsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final presetsState = ref.watch(presetsProvider);
    final playersState = ref.watch(playersProvider);

    if (playersState.selectedPlayer == null) {
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
              l10n.selectPlayerFirst,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
          ],
        ),
      );
    }

    if (presetsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (presetsState.presets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noPresetsFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(presetsProvider.notifier).load(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reload),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: presetsState.presets.length,
      itemBuilder: (context, index) {
        final preset = presetsState.presets[index];

        return PresetTile(
          preset: preset,
          onTap: () async {
            try {
              await ref.read(presetsProvider.notifier).playPreset(preset.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l10n.playingPreset}: ${preset.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l10n.failedToPlayPreset}: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
