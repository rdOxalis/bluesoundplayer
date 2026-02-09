import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/providers.dart';
import 'screens/screens.dart';
import 'l10n/app_localizations.dart';

/// SharedPreferences instance loaded at startup.
late SharedPreferences sharedPreferences;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load SharedPreferences before app starts
  sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    const ProviderScope(
      child: BluesoundControllerApp(),
    ),
  );
}

class BluesoundControllerApp extends ConsumerWidget {
  const BluesoundControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'BlueSound Controller',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: settings.themeMode,

      // Localization - use the selected language, not system locale
      locale: settings.language.locale,
      supportedLocales: AppLanguage.values.map((l) => l.locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Force the app to use our locale, not system locale
      localeResolutionCallback: (locale, supportedLocales) {
        return settings.language.locale;
      },

      home: const HomeScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
