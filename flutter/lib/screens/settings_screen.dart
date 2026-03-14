import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';

/// Settings screen for app configuration.
class SettingsScreen extends ConsumerWidget {
  final bool isDialog;

  const SettingsScreen({
    super.key,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language section
        Text(
          l10n.language,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        ...AppLanguage.values.map((lang) => RadioListTile<AppLanguage>(
              title: Text(lang.displayName),
              value: lang,
              groupValue: settings.language,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setLanguage(value);
                }
              },
            )),

        const Divider(height: 32),

        // Theme section
        Text(
          l10n.theme,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        RadioListTile<ThemeMode>(
          title: Text(l10n.themeSystem),
          subtitle: Text(l10n.followSystemSettings),
          value: ThemeMode.system,
          groupValue: settings.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setThemeMode(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: Text(l10n.themeLight),
          value: ThemeMode.light,
          groupValue: settings.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setThemeMode(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: Text(l10n.themeDark),
          value: ThemeMode.dark,
          groupValue: settings.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(settingsProvider.notifier).setThemeMode(value);
            }
          },
        ),

        const Divider(height: 32),

        // Auto-refresh section
        Text(
          l10n.statusUpdates,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l10n.autoRefresh),
          subtitle: Text(l10n.autoRefreshDescription),
          value: settings.autoRefresh,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setAutoRefresh(value);
          },
        ),
        if (settings.autoRefresh)
          ListTile(
            title: Text(l10n.refreshInterval),
            subtitle: Text('${settings.autoRefreshInterval} ${l10n.seconds}'),
            trailing: DropdownButton<int>(
              value: settings.autoRefreshInterval,
              items: [3, 5, 10, 15, 30]
                  .map((seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds s'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .setAutoRefreshInterval(value);
                }
              },
            ),
          ),

        const Divider(height: 32),

        // About section
        Text(
          l10n.about,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '...';
            final buildNumber = snapshot.data?.buildNumber ?? '';
            return ListTile(
              title: Text(l10n.appTitle),
              subtitle: Text('${l10n.version} $version${buildNumber.isNotEmpty ? '+$buildNumber' : ''}'),
              leading: const Icon(Icons.info_outline),
            );
          },
        ),
        ListTile(
          title: Text(l10n.licenses),
          leading: const Icon(Icons.description_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            );
          },
        ),
        ListTile(
          title: Text(l10n.buyMeACoffee),
          leading: const Icon(Icons.coffee_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.buyMeACoffee),
                content: Text(l10n.donationMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.coffee),
                    label: Text(l10n.donate),
                    onPressed: () {
                      Navigator.of(context).pop();
                      launchUrl(
                        Uri.parse('https://paypal.me/CarlDarkman'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

    if (isDialog) {
      return Column(
        children: [
          AppBar(
            title: Text(l10n.settings),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      body: content,
    );
  }
}
