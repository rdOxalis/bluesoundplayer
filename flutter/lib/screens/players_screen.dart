import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/bluos_client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

/// Screen showing available players.
class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersState = ref.watch(playersProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(playersProvider.notifier).scan(),
        child: Column(
          children: [
            // Scan status
            if (playersState.isScanning || playersState.scanMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    if (playersState.isScanning)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        playersState.scanMessage ?? AppLocalizations.of(context).scanningNetwork,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

            // Error message
            if (playersState.error != null)
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
                        playersState.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          ref.read(playersProvider.notifier).clearError(),
                    ),
                  ],
                ),
              ),

            // Players list
            const Expanded(child: PlayersListView()),
          ],
        ),
      ),
    );
  }
}

/// List view of available players with grouping controls.
class PlayersListView extends ConsumerStatefulWidget {
  const PlayersListView({super.key});

  @override
  ConsumerState<PlayersListView> createState() => _PlayersListViewState();
}

class _PlayersListViewState extends ConsumerState<PlayersListView> {
  @override
  void initState() {
    super.initState();
    // Load group info after first frame
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(groupProvider.notifier).refresh(force: true));
  }

  Future<void> _refreshGroupInfo() =>
      ref.read(groupProvider.notifier).refresh(force: true);

  /// Get the coordinator's name for a grouped player.
  String? _getGroupCoordinatorName(
      GroupState groupState, PlayerInfo player, List<PlayerInfo> allPlayers) {
    if (groupState.roleOf(player.ip) != 'member') return null;
    final coordIp = groupState.coordinatorOf(player.ip);
    if (coordIp == null) return null;
    final coord = allPlayers.where((p) => p.ip == coordIp);
    return coord.isNotEmpty ? coord.first.shortName : coordIp;
  }

  /// Get member names for a coordinator.
  List<String> _getGroupMemberNames(
      GroupState groupState, PlayerInfo player, List<PlayerInfo> allPlayers) {
    final memberIps = groupState.groups[player.ip];
    if (memberIps == null) return [];
    return memberIps.map((ip) {
      final p = allPlayers.where((p) => p.ip == ip);
      return p.isNotEmpty ? p.first.shortName : ip;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playersState = ref.watch(playersProvider);
    final groupState = ref.watch(groupProvider);

    if (playersState.players.isEmpty && !playersState.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.speaker_group,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noPlayersFound,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(playersProvider.notifier).scan(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.scanNetwork),
            ),
          ],
        ),
      );
    }

    final selectedPlayer = playersState.selectedPlayer;
    final hasMultiplePlayers = playersState.players.length > 1;
    final canGroup = hasMultiplePlayers &&
        selectedPlayer != null &&
        playersState.players
            .where((p) => p.type == selectedPlayer.type && p != selectedPlayer)
            .isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: playersState.players.length,
            itemBuilder: (context, index) {
              final player = playersState.players[index];
              final isSelected = player == selectedPlayer;
              final groupRole = groupState.roleOf(player.ip);
              final memberNames =
                  _getGroupMemberNames(groupState, player, playersState.players);
              final coordName = _getGroupCoordinatorName(
                  groupState, player, playersState.players);

              // Build subtitle with group info
              String? groupSubtitle;
              if (groupRole == 'coordinator' && memberNames.isNotEmpty) {
                groupSubtitle = '+ ${memberNames.join(', ')}';
              } else if (groupRole == 'member' && coordName != null) {
                groupSubtitle = '@ $coordName';
              }

              return PlayerCard(
                player: player,
                isSelected: isSelected,
                groupRole: groupRole,
                groupSubtitle: groupSubtitle,
                onTap: () {
                  ref.read(playersProvider.notifier).selectPlayer(player);
                },
              );
            },
          ),
        ),
        if (canGroup)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showGroupDialog(context),
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(l10n.groupPlayers),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _ungroupAll(context),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: Text(l10n.ungroupAll),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showGroupDialog(BuildContext context) {
    final playersState = ref.read(playersProvider);
    final selectedPlayer = playersState.selectedPlayer;
    if (selectedPlayer == null) return;

    final availableSlaves = playersState.players
        .where((p) => p.type == selectedPlayer.type && p != selectedPlayer)
        .toList();

    final l10n = AppLocalizations.of(context);
    final selected = <PlayerInfo>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.groupPlayers),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.selectPlayersToGroup} ${selectedPlayer.shortName}:',
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...availableSlaves.map((slave) => CheckboxListTile(
                      value: selected.contains(slave),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selected.add(slave);
                          } else {
                            selected.remove(slave);
                          }
                        });
                      },
                      secondary: Icon(
                        slave.isBluOS ? Icons.speaker_group : Icons.speaker,
                      ),
                      title: Text(slave.shortName),
                      subtitle: Text(slave.ip),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _groupMultiplePlayers(
                          context, selectedPlayer, selected.toList());
                    },
              child: Text('${l10n.groupPlayers} (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _groupMultiplePlayers(
    BuildContext context,
    PlayerInfo master,
    List<PlayerInfo> slaves,
  ) async {
    final l10n = AppLocalizations.of(context);
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    final names = <String>[];
    var errors = 0;

    for (final slave in slaves) {
      try {
        await client.addSlave(
          slave.ip,
          slaveUuid: slave.uuid,
          masterUuid: master.uuid,
        );
        names.add(slave.shortName);
      } catch (e) {
        errors++;
      }
    }

    if (context.mounted) {
      if (names.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.grouped}: ${master.shortName} + ${names.join(', ')}',
            ),
          ),
        );
      }
      if (errors > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.groupingFailed}: $errors')),
        );
      }
    }
    await ref.read(statusProvider.notifier).refresh();
    await _refreshGroupInfo();
  }

  Future<void> _ungroupAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final playersState = ref.read(playersProvider);
    final selectedPlayer = playersState.selectedPlayer;
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null || selectedPlayer == null) return;

    try {
      if (selectedPlayer.isSonos) {
        await client.removeAllSlaves();
      } else {
        final otherPlayers = playersState.players
            .where((p) => p.type == selectedPlayer.type && p != selectedPlayer);
        for (final other in otherPlayers) {
          try {
            await client.removeSlave(other.ip);
          } catch (_) {}
          try {
            final otherClient = BluOSClient(other.ip);
            await otherClient.removeSlave(selectedPlayer.ip);
          } catch (_) {}
        }
        for (final player in playersState.players.where((p) => p.isBluOS)) {
          try {
            final c = BluOSClient(player.ip);
            await c.removeAllSlaves();
          } catch (_) {}
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ungrouped)),
        );
      }
      await ref.read(statusProvider.notifier).refresh();
      await _refreshGroupInfo();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.ungroupingFailed}: $e')),
        );
      }
    }
  }
}
