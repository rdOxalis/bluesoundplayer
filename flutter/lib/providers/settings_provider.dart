import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show sharedPreferences;

/// Supported languages.
enum AppLanguage {
  english('en', 'English'),
  german('de', 'Deutsch'),
  swahili('sw', 'Kiswahili');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  Locale get locale => Locale(code);
}

/// Settings state.
class SettingsState {
  final AppLanguage language;
  final ThemeMode themeMode;
  final bool autoRefresh;
  final int autoRefreshInterval; // in seconds

  const SettingsState({
    this.language = AppLanguage.english,
    this.themeMode = ThemeMode.system,
    this.autoRefresh = true,
    this.autoRefreshInterval = 5,
  });

  SettingsState copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    bool? autoRefresh,
    int? autoRefreshInterval,
  }) {
    return SettingsState(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      autoRefreshInterval: autoRefreshInterval ?? this.autoRefreshInterval,
    );
  }
}

/// Provider for app settings.
class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _languageKey = 'language';
  static const _themeModeKey = 'themeMode';
  static const _autoRefreshKey = 'autoRefresh';
  static const _autoRefreshIntervalKey = 'autoRefreshInterval';

  SettingsNotifier() : super(_loadInitialState());

  /// Load settings synchronously from pre-loaded SharedPreferences.
  static SettingsState _loadInitialState() {
    final prefs = sharedPreferences;

    final languageCode = prefs.getString(_languageKey);
    final themeModeIndex = prefs.getInt(_themeModeKey);
    final autoRefresh = prefs.getBool(_autoRefreshKey);
    final autoRefreshInterval = prefs.getInt(_autoRefreshIntervalKey);

    return SettingsState(
      language: languageCode != null
          ? AppLanguage.fromCode(languageCode)
          : AppLanguage.english,
      themeMode: themeModeIndex != null
          ? ThemeMode.values[themeModeIndex]
          : ThemeMode.system,
      autoRefresh: autoRefresh ?? true,
      autoRefreshInterval: autoRefreshInterval ?? 5,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    await sharedPreferences.setString(_languageKey, language.code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await sharedPreferences.setInt(_themeModeKey, mode.index);
  }

  Future<void> setAutoRefresh(bool enabled) async {
    state = state.copyWith(autoRefresh: enabled);
    await sharedPreferences.setBool(_autoRefreshKey, enabled);
  }

  Future<void> setAutoRefreshInterval(int seconds) async {
    state = state.copyWith(autoRefreshInterval: seconds);
    await sharedPreferences.setInt(_autoRefreshIntervalKey, seconds);
  }
}

/// The settings provider.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
