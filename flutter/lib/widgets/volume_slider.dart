import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

/// Widget for volume control.
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
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusState = ref.watch(statusProvider);
    final status = statusState.status;
    final volume = status?.volume ?? -1;
    final hasVolume = volume >= 0;

    final displayValue = _draggingValue ?? (hasVolume ? volume.toDouble() : 0);

    if (widget.vertical) {
      return _buildVerticalSlider(displayValue, hasVolume, l10n);
    }

    return _buildHorizontalSlider(displayValue, hasVolume, l10n);
  }

  Widget _buildHorizontalSlider(double value, bool enabled, AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: enabled
              ? () => _setVolume((value - 5).round().clamp(0, 100), l10n)
              : null,
          tooltip: '-5%',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
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
            divisions: 100,
            label: '${value.round()}%',
            onChanged: enabled
                ? (newValue) {
                    setState(() {
                      _draggingValue = newValue;
                    });
                  }
                : null,
            onChangeEnd: enabled
                ? (newValue) {
                    setState(() {
                      _draggingValue = null;
                    });
                    _setVolume(newValue.round(), l10n);
                  }
                : null,
          ),
        ),
        Icon(
          Icons.volume_up,
          size: 24,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: enabled
              ? () => _setVolume((value + 5).round().clamp(0, 100), l10n)
              : null,
          tooltip: '+5%',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 48,
          child: Text(
            enabled ? '${value.round()}%' : l10n.volumeNA,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled ? null : Theme.of(context).disabledColor,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalSlider(double value, bool enabled, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: enabled
              ? () => _setVolume((value + 5).round().clamp(0, 100), l10n)
              : null,
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
              divisions: 100,
              onChanged: enabled
                  ? (newValue) {
                      setState(() {
                        _draggingValue = newValue;
                      });
                    }
                  : null,
              onChangeEnd: enabled
                  ? (newValue) {
                      setState(() {
                        _draggingValue = null;
                      });
                      _setVolume(newValue.round(), l10n);
                    }
                  : null,
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
          onPressed: enabled
              ? () => _setVolume((value - 5).round().clamp(0, 100), l10n)
              : null,
          tooltip: '-5%',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(height: 4),
        Text(
          enabled ? '${value.round()}%' : l10n.volumeNA,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: enabled ? null : Theme.of(context).disabledColor,
              ),
        ),
      ],
    );
  }

  Future<void> _setVolume(int level, AppLocalizations l10n) async {
    final client = ref.read(playersProvider.notifier).currentClient;
    if (client == null) return;

    try {
      await client.setVolume(level);
      await ref.read(statusProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToSetVolume}: $e')),
        );
      }
    }
  }
}
