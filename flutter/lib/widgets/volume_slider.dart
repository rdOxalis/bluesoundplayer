import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';

/// Widget for volume control.
///
/// Shows a single slider for a standalone player. When the selected player is
/// part of a group, one slider per group member is shown instead, because each
/// player keeps its own volume - changing only the coordinator's volume would
/// leave the other members untouched.
class VolumeSlider extends ConsumerStatefulWidget {
  final bool vertical;

  const VolumeSlider({
    super.key,
    this.vertical = false,
  });

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider> {
  @override
  void initState() {
    super.initState();
    // Make sure the group topology is known even without auto-refresh.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(groupProvider.notifier).refresh(force: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playersState = ref.watch(playersProvider);
    final groupState = ref.watch(groupProvider);
    final selected = playersState.selectedPlayer;

    if (selected != null) {
      final members = <PlayerInfo>[];
      for (final ip in groupState.groupMemberIps(selected.ip)) {
        final known = playersState.players.where((p) => p.ip == ip);
        if (known.isNotEmpty) members.add(known.first);
      }

      if (members.length > 1) {
        return _GroupVolume(players: members, vertical: widget.vertical);
      }
    }

    return _SingleVolume(vertical: widget.vertical);
  }
}

/// Drag handling shared by the single and the per-player slider.
///
/// Keeps the knob under the finger (the widget owns the value while dragging),
/// sends throttled updates so the speaker follows the movement, and keeps
/// showing the value just sent until the device confirms it - otherwise a poll
/// that started before the change would make the knob jump back.
mixin _VolumeDrag<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _sendInterval = Duration(milliseconds: 250);
  static const _confirmWindow = Duration(seconds: 4);

  double? _dragValue;
  int? _pendingValue;
  DateTime? _pendingAt;
  Timer? _sendTimer;
  int? _queuedValue;

  /// Push a value to the device. [isFinal] marks the end of an interaction.
  Future<void> sendVolume(int level, {required bool isFinal});

  /// Called when the user starts/stops dragging.
  void setInteracting(bool value) =>
      ref.read(groupProvider.notifier).setInteracting(value);

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  /// The value to render for a device that currently reports [deviceVolume].
  double displayValue(int deviceVolume) {
    final dragging = _dragValue;
    if (dragging != null) return dragging;

    final pending = _pendingValue;
    final pendingAt = _pendingAt;
    if (pending != null && pendingAt != null) {
      if (deviceVolume == pending ||
          DateTime.now().difference(pendingAt) > _confirmWindow) {
        // Confirmed (or given up on) - fall through to the device value.
        _pendingValue = null;
        _pendingAt = null;
      } else {
        return pending.toDouble();
      }
    }

    return deviceVolume < 0 ? 0 : deviceVolume.toDouble();
  }

  void onDragStart(double value) {
    setInteracting(true);
    setState(() => _dragValue = value);
  }

  void onDragUpdate(double value) {
    setState(() => _dragValue = value);
    _throttledSend(value.round());
  }

  void onDragEnd(double value) {
    _sendTimer?.cancel();
    _sendTimer = null;
    _queuedValue = null;
    setState(() {
      _dragValue = null;
      _pendingValue = value.round();
      _pendingAt = DateTime.now();
    });
    setInteracting(false);
    sendVolume(value.round(), isFinal: true);
  }

  /// Used by the +/- buttons.
  void stepTo(int level) {
    setState(() {
      _pendingValue = level;
      _pendingAt = DateTime.now();
    });
    sendVolume(level, isFinal: true);
  }

  void _throttledSend(int level) {
    if (_sendTimer != null) {
      _queuedValue = level;
      return;
    }
    sendVolume(level, isFinal: false);
    _sendTimer = Timer(_sendInterval, () {
      _sendTimer = null;
      final queued = _queuedValue;
      _queuedValue = null;
      if (queued != null && mounted) _throttledSend(queued);
    });
  }
}

/// Volume control for a single, ungrouped player (uses the polled status).
class _SingleVolume extends ConsumerStatefulWidget {
  final bool vertical;

  const _SingleVolume({required this.vertical});

  @override
  ConsumerState<_SingleVolume> createState() => _SingleVolumeState();
}

class _SingleVolumeState extends ConsumerState<_SingleVolume>
    with _VolumeDrag {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(statusProvider).status;
    final volume = status?.volume ?? -1;
    final enabled = volume >= 0;
    final value = displayValue(volume);

    if (widget.vertical) {
      return _VerticalVolumeBar(
        value: value,
        enabled: enabled,
        naLabel: l10n.volumeNA,
        onChangeStart: onDragStart,
        onChanged: onDragUpdate,
        onChangeEnd: onDragEnd,
        onStep: stepTo,
      );
    }

    return _HorizontalVolumeBar(
      value: value,
      enabled: enabled,
      naLabel: l10n.volumeNA,
      onChangeStart: onDragStart,
      onChanged: onDragUpdate,
      onChangeEnd: onDragEnd,
      onStep: stepTo,
    );
  }

  @override
  Future<void> sendVolume(int level, {required bool isFinal}) async {
    final l10n = AppLocalizations.of(context);
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    try {
      await client.setVolume(level.clamp(0, 100));
      if (isFinal) await ref.read(statusProvider.notifier).refresh();
    } catch (e) {
      if (mounted && isFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToSetVolume}: $e')),
        );
      }
    }
  }
}

/// One slider per player of the current group.
class _GroupVolume extends ConsumerWidget {
  final List<PlayerInfo> players;
  final bool vertical;

  const _GroupVolume({required this.players, required this.vertical});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (vertical) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final player in players)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PlayerVolume(
                key: ValueKey(player.ip),
                player: player,
                isCoordinator: player == players.first,
                vertical: true,
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.speaker_group,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '${l10n.groupVolume} (${players.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Keep large groups from overflowing small screens.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final player in players)
                  _PlayerVolume(
                    key: ValueKey(player.ip),
                    player: player,
                    isCoordinator: player == players.first,
                    vertical: false,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Volume control for one specific player of a group.
class _PlayerVolume extends ConsumerStatefulWidget {
  final PlayerInfo player;
  final bool isCoordinator;
  final bool vertical;

  const _PlayerVolume({
    super.key,
    required this.player,
    required this.isCoordinator,
    required this.vertical,
  });

  @override
  ConsumerState<_PlayerVolume> createState() => _PlayerVolumeState();
}

class _PlayerVolumeState extends ConsumerState<_PlayerVolume> with _VolumeDrag {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final volume = ref.watch(groupProvider).volumeOf(widget.player.ip);
    final enabled = volume >= 0 || _hasPendingValue;
    final value = displayValue(volume);

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.isCoordinator ? Icons.hub : Icons.link,
          size: 12,
          color: widget.isCoordinator
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            widget.player.shortName,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight:
                  widget.isCoordinator ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );

    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: _VerticalVolumeBar(
              value: value,
              enabled: enabled,
              naLabel: l10n.volumeNA,
              onChangeStart: onDragStart,
              onChanged: onDragUpdate,
              onChangeEnd: onDragEnd,
              onStep: stepTo,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(width: 72, child: Center(child: label)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: compact ? 80 : 110, child: label),
              Expanded(
                child: _HorizontalVolumeBar(
                  value: value,
                  enabled: enabled,
                  naLabel: l10n.volumeNA,
                  showStepButtons: !compact,
                  showIcons: false,
                  onChangeStart: onDragStart,
                  onChanged: onDragUpdate,
                  onChangeEnd: onDragEnd,
                  onStep: stepTo,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _hasPendingValue => _pendingValue != null;

  @override
  Future<void> sendVolume(int level, {required bool isFinal}) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(groupProvider.notifier).setVolume(widget.player, level);
    } catch (e) {
      if (mounted && isFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.failedToSetVolume} (${widget.player.shortName}): $e',
            ),
          ),
        );
      }
    }
  }
}

/// Presentational horizontal volume bar.
class _HorizontalVolumeBar extends StatelessWidget {
  final double value;
  final bool enabled;
  final String naLabel;
  final bool showStepButtons;
  final bool showIcons;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<int> onStep;

  const _HorizontalVolumeBar({
    required this.value,
    required this.enabled,
    required this.naLabel,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onStep,
    this.showStepButtons = true,
    this.showIcons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showStepButtons)
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            onPressed:
                enabled ? () => onStep((value - 5).round().clamp(0, 100)) : null,
            tooltip: '-5%',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (showIcons)
          Icon(
            value == 0 ? Icons.volume_off : Icons.volume_down,
            size: 24,
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 100),
            min: 0,
            max: 100,
            label: '${value.round()}%',
            onChangeStart: enabled ? onChangeStart : null,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
        if (showIcons)
          Icon(
            Icons.volume_up,
            size: 24,
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
        if (showStepButtons)
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed:
                enabled ? () => onStep((value + 5).round().clamp(0, 100)) : null,
            tooltip: '+5%',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        const SizedBox(width: 4),
        SizedBox(
          width: 48,
          child: Text(
            enabled ? '${value.round()}%' : naLabel,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled ? null : Theme.of(context).disabledColor,
                ),
          ),
        ),
      ],
    );
  }
}

/// Presentational vertical volume bar.
class _VerticalVolumeBar extends StatelessWidget {
  final double value;
  final bool enabled;
  final String naLabel;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<int> onStep;

  const _VerticalVolumeBar({
    required this.value,
    required this.enabled,
    required this.naLabel,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed:
              enabled ? () => onStep((value + 5).round().clamp(0, 100)) : null,
          tooltip: '+5%',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        Icon(
          Icons.volume_up,
          size: 24,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value.clamp(0, 100),
              min: 0,
              max: 100,
              onChangeStart: enabled ? onChangeStart : null,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Icon(
          value == 0 ? Icons.volume_off : Icons.volume_down,
          size: 24,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed:
              enabled ? () => onStep((value - 5).round().clamp(0, 100)) : null,
          tooltip: '-5%',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(height: 4),
        Text(
          enabled ? '${value.round()}%' : naLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: enabled ? null : Theme.of(context).disabledColor,
              ),
        ),
      ],
    );
  }
}
