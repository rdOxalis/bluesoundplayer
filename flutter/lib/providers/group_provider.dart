import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../models/models.dart';
import 'players_provider.dart';
import 'status_provider.dart';

/// Group topology plus the individual volume of every grouped player.
class GroupState {
  /// Coordinator/master IP -> IPs of its members (coordinator not included).
  final Map<String, List<String>> groups;

  /// Player IP -> its own volume (0-100), -1 if unknown.
  final Map<String, int> volumes;

  const GroupState({
    this.groups = const {},
    this.volumes = const {},
  });

  GroupState copyWith({
    Map<String, List<String>>? groups,
    Map<String, int>? volumes,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      volumes: volumes ?? this.volumes,
    );
  }

  /// The coordinator IP of the group [ip] belongs to, or null if ungrouped.
  String? coordinatorOf(String ip) {
    if (groups.containsKey(ip)) return ip;
    for (final entry in groups.entries) {
      if (entry.value.contains(ip)) return entry.key;
    }
    return null;
  }

  /// Group role of [ip]: 'coordinator', 'member' or null when ungrouped.
  String? roleOf(String ip) {
    if (groups.containsKey(ip)) return 'coordinator';
    for (final entry in groups.entries) {
      if (entry.value.contains(ip)) return 'member';
    }
    return null;
  }

  bool isGrouped(String ip) => roleOf(ip) != null;

  /// All IPs of the group [ip] belongs to, coordinator first.
  /// Returns an empty list when the player is not grouped.
  List<String> groupMemberIps(String ip) {
    final coordinator = coordinatorOf(ip);
    if (coordinator == null) return const [];
    return [coordinator, ...?groups[coordinator]];
  }

  /// Known volume of [ip], or -1 when unknown.
  int volumeOf(String ip) => volumes[ip] ?? -1;
}

/// Keeps track of which players are grouped and how loud each of them is.
class GroupNotifier extends StateNotifier<GroupState> {
  /// Topology rarely changes and is expensive to read (Sonos returns the full
  /// zone XML), so it is only re-read this often unless a refresh is forced.
  static const _topologyInterval = Duration(seconds: 15);

  /// Minimum spacing between volume polls, independent of the status poll.
  static const _volumeInterval = Duration(seconds: 3);

  /// How long a value the user just set wins over a concurrently polled one.
  static const _writeGrace = Duration(seconds: 3);

  final Ref _ref;
  bool _refreshing = false;
  bool _interacting = false;
  DateTime? _topologyAt;
  DateTime? _volumesAt;
  final Map<String, DateTime> _lastWrite = {};

  GroupNotifier(this._ref) : super(const GroupState());

  /// While the user drags a slider, polling must not fight the drag.
  void setInteracting(bool value) => _interacting = value;

  /// Re-read the group topology and the volume of every grouped player.
  ///
  /// Pass [force] after an action that changed the setup (grouping, manual
  /// refresh) to bypass the poll intervals.
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    if (_interacting && !force) return;

    final now = DateTime.now();
    if (!force &&
        _volumesAt != null &&
        now.difference(_volumesAt!) < _volumeInterval) {
      return;
    }

    _refreshing = true;
    try {
      final players = _ref.read(playersProvider).players;
      if (players.isEmpty) {
        state = const GroupState();
        return;
      }

      final reuseTopology = !force &&
          state.groups.isNotEmpty &&
          _topologyAt != null &&
          now.difference(_topologyAt!) < _topologyInterval;

      final groups =
          reuseTopology ? state.groups : await _loadTopology(players);
      if (!reuseTopology) _topologyAt = DateTime.now();

      final startedAt = DateTime.now();
      final fetched = await _loadVolumes(players, groups);
      _volumesAt = DateTime.now();

      state = GroupState(
        groups: groups,
        volumes: _mergeVolumes(groups, fetched, startedAt),
      );
    } catch (_) {
      // Keep the previous state; the next poll tries again.
    } finally {
      _refreshing = false;
    }
  }

  /// Set the volume of a single player, independent of its group.
  Future<void> setVolume(PlayerInfo player, int level) async {
    final value = level.clamp(0, 100);
    // Show the new value immediately - the device confirms it on the next poll.
    _lastWrite[player.ip] = DateTime.now();
    state = state.copyWith(volumes: {...state.volumes, player.ip: value});

    final client = _ref.read(playersProvider.notifier).clientFor(player);
    await client.setVolume(value);
    _lastWrite[player.ip] = DateTime.now();
  }

  /// Merge freshly polled volumes into the known ones.
  ///
  /// A player the user just changed keeps its local value: the poll may have
  /// been started before the change reached the device, and letting that stale
  /// answer win makes the slider jump back.
  Map<String, int> _mergeVolumes(
    Map<String, List<String>> groups,
    Map<String, int> fetched,
    DateTime pollStartedAt,
  ) {
    final groupedIps = <String>{
      ...groups.keys,
      ...groups.values.expand((members) => members),
    };

    final merged = <String, int>{};
    final now = DateTime.now();
    for (final ip in groupedIps) {
      final writtenAt = _lastWrite[ip];
      final justWritten = writtenAt != null &&
          (writtenAt.isAfter(pollStartedAt) ||
              now.difference(writtenAt) < _writeGrace);

      // Prefer: own recent change > fresh poll > last known value.
      final local = state.volumes[ip];
      final value =
          justWritten ? (local ?? fetched[ip]) : (fetched[ip] ?? local);
      if (value != null && value >= 0) merged[ip] = value;
    }
    return merged;
  }

  Future<Map<String, List<String>>> _loadTopology(
      List<PlayerInfo> players) async {
    final merged = <String, List<String>>{};

    // Sonos: a single query returns the full topology.
    final sonosPlayers = players.where((p) => p.isSonos).toList();
    if (sonosPlayers.isNotEmpty) {
      try {
        final info = await SonosClient(sonosPlayers.first.ip).getGroupInfo();
        merged.addAll(info);
      } catch (_) {}
    }

    // BluOS: every player reports its own /SyncStatus.
    for (final player in players.where((p) => p.isBluOS)) {
      try {
        final info = await BluOSClient(player.ip).getGroupInfo();
        for (final entry in info.entries) {
          final existing = merged[entry.key];
          if (existing != null) {
            for (final ip in entry.value) {
              if (!existing.contains(ip)) existing.add(ip);
            }
          } else {
            merged[entry.key] = List.from(entry.value);
          }
        }
      } catch (_) {}
    }

    return merged;
  }

  Future<Map<String, int>> _loadVolumes(
    List<PlayerInfo> players,
    Map<String, List<String>> groups,
  ) async {
    final groupedIps = <String>{
      ...groups.keys,
      ...groups.values.expand((members) => members),
    };
    if (groupedIps.isEmpty) return const {};

    final volumes = <String, int>{};
    await Future.wait(groupedIps.map((ip) async {
      final matches = players.where((p) => p.ip == ip);
      if (matches.isEmpty) return;
      try {
        final volume = await _ref
            .read(playersProvider.notifier)
            .clientFor(matches.first)
            .getVolume();
        if (volume >= 0) volumes[ip] = volume;
      } catch (_) {}
    }));

    return volumes;
  }
}

/// The group provider.
final groupProvider =
    StateNotifierProvider<GroupNotifier, GroupState>((ref) {
  final notifier = GroupNotifier(ref);

  // Re-read topology whenever the player list or the playback status changes.
  ref.listen<PlayersState>(playersProvider, (previous, next) {
    if (previous?.players.length != next.players.length ||
        previous?.selectedPlayer != next.selectedPlayer) {
      notifier.refresh(force: true);
    }
  });

  ref.listen<StatusState>(statusProvider, (previous, next) {
    if (previous?.status != next.status) notifier.refresh();
  });

  return notifier;
});
