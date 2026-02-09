import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'players_screen.dart';
import 'presets_screen.dart';
import 'settings_screen.dart';

/// Main home screen with responsive layout.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  double _leftPanelWidth = 400;
  double _rightPanelWidth = 400;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start scanning on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playersProvider.notifier).scan();
      _setupAutoRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause auto-refresh when app is in background
    if (state == AppLifecycleState.paused) {
      ref.read(statusProvider.notifier).stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      _setupAutoRefresh();
      // Refresh status immediately when resuming
      ref.read(statusProvider.notifier).refresh();
    }
  }

  void _setupAutoRefresh() {
    final settings = ref.read(settingsProvider);
    final hasPlayer = ref.read(playersProvider).selectedPlayer != null;

    if (settings.autoRefresh && hasPlayer) {
      ref.read(statusProvider.notifier).startAutoRefresh(
            interval: Duration(seconds: settings.autoRefreshInterval),
          );
    } else {
      ref.read(statusProvider.notifier).stopAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes for auto-refresh
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.autoRefresh != next.autoRefresh ||
          previous?.autoRefreshInterval != next.autoRefreshInterval) {
        _setupAutoRefresh();
      }
    });

    // Listen to player selection changes
    ref.listen<PlayersState>(playersProvider, (previous, next) {
      if (previous?.selectedPlayer != next.selectedPlayer) {
        _setupAutoRefresh();
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;

    // Desktop layout (> 840px)
    if (screenWidth > 840) {
      return _buildDesktopLayout();
    }

    // Mobile/Tablet layout
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final hasPlayer = ref.watch(playersProvider).selectedPlayer != null;
    final isAutoRefreshActive = settings.autoRefresh && hasPlayer;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(l10n.appTitle),
            if (isAutoRefreshActive) ...[
              const SizedBox(width: 12),
              Tooltip(
                message: '${l10n.autoRefreshActive}: ${settings.autoRefreshInterval}s',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${settings.autoRefreshInterval}s',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(playersProvider.notifier).scan();
              ref.read(statusProvider.notifier).refresh();
            },
            tooltip: l10n.refreshNow,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: Row(
        children: [
          // Left sidebar - Players
          SizedBox(
            width: _leftPanelWidth,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.speaker_group),
                      const SizedBox(width: 8),
                      Text(
                        l10n.players,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Expanded(child: PlayersListView()),
              ],
            ),
          ),

          // Draggable divider - left
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _leftPanelWidth = (_leftPanelWidth + details.delta.dx)
                      .clamp(200, 500);
                });
              },
              child: Container(
                width: 8,
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                child: Center(
                  child: Container(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
            ),
          ),

          // Center - Now Playing
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: NowPlaying(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const PlaybackControls(large: true),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: VolumeSlider(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Draggable divider - right
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _rightPanelWidth = (_rightPanelWidth - details.delta.dx)
                      .clamp(200, 500);
                });
              },
              child: Container(
                width: 8,
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                child: Center(
                  child: Container(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
            ),
          ),

          // Right sidebar - Presets
          SizedBox(
            width: _rightPanelWidth,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_play),
                      const SizedBox(width: 8),
                      Text(
                        l10n.presets,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Expanded(child: PresetsListView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final hasPlayer = ref.watch(playersProvider).selectedPlayer != null;
    final isAutoRefreshActive = settings.autoRefresh && hasPlayer;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(l10n.appTitle),
            if (isAutoRefreshActive) ...[
              const SizedBox(width: 8),
              Icon(Icons.sync, size: 16, color: Colors.green.shade400),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(playersProvider.notifier).scan();
              ref.read(statusProvider.notifier).refresh();
            },
            tooltip: l10n.refreshNow,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _MobileNowPlayingView(),
          PlayersScreen(),
          PresetsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.speaker_outlined),
            selectedIcon: const Icon(Icons.speaker),
            label: l10n.players,
          ),
          NavigationDestination(
            icon: const Icon(Icons.playlist_play_outlined),
            selectedIcon: const Icon(Icons.playlist_play),
            label: l10n.presets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: const SettingsScreen(isDialog: true),
        ),
      ),
    );
  }
}

/// Mobile Now Playing view with controls.
class _MobileNowPlayingView extends StatelessWidget {
  const _MobileNowPlayingView();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: NowPlaying(),
              ),
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                PlaybackControls(large: true),
                SizedBox(height: 16),
                VolumeSlider(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
