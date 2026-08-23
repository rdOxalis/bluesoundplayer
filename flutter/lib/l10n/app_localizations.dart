import 'package:flutter/material.dart';

/// Localization support for the app.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // App
      'appTitle': 'BlueSound Controller',

      // Navigation
      'home': 'Home',
      'players': 'Players',
      'presets': 'Presets',
      'settings': 'Settings',

      // Player
      'availablePlayers': 'Available Players',
      'noPlayersFound': 'No players found',
      'scanNetwork': 'Scan Network',
      'selectPlayerFirst': 'Select a player first',
      'noPlayerSelected': 'No player selected',

      // Playback
      'noSongPlaying': 'No song playing',
      'playing': 'Playing',
      'paused': 'Paused',
      'stopped': 'Stopped',
      'play': 'Play',
      'pause': 'Pause',
      'stop': 'Stop',
      'next': 'Next',
      'previous': 'Previous',

      // Presets
      'availablePresets': 'Available Presets',
      'noPresetsFound': 'No presets found',
      'reload': 'Reload',
      'playingPreset': 'Playing',
      'failedToPlayPreset': 'Failed to play preset',
      'categoryStations': 'Stations',
      'categoryPlaylists': 'Playlists',
      'categoryAlbums': 'Albums',
      'categorySongs': 'Songs',

      // Volume
      'volume': 'Volume',
      'volumeNA': 'N/A',
      'failedToSetVolume': 'Failed to set volume',
      'groupVolume': 'Group volume',

      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'followSystemSettings': 'Follow system settings',
      'statusUpdates': 'Status Updates',
      'autoRefresh': 'Auto-refresh',
      'autoRefreshDescription': 'Automatically update playback status',
      'refreshInterval': 'Refresh interval',
      'seconds': 'seconds',
      'about': 'About',
      'version': 'Version',
      'licenses': 'Open Source Licenses',
      'buyMeACoffee': 'Buy the developer a coffee',
      'donationMessage': 'If you enjoy this app, you can support its development with a small donation. Thank you!',
      'donate': 'Donate',

      // Actions
      'refresh': 'Refresh',
      'refreshNow': 'Refresh now',

      // Auto-refresh
      'autoRefreshActive': 'Auto-refresh',

      // Grouping
      'groupPlayers': 'Group Players',
      'ungroupAll': 'Ungroup All',
      'groupWith': 'Group with',
      'grouped': 'Grouped',
      'ungrouped': 'Ungrouped',
      'groupingFailed': 'Grouping failed',
      'ungroupingFailed': 'Ungrouping failed',
      'selectPlayersToGroup': 'Select players to group with',

      // Transfer
      'transfer': 'Transfer',
      'transferTo': 'Transfer to',
      'transferSuccess': 'Transferred',
      'transferFailed': 'Transfer failed',
      'nothingPlaying': 'Cannot transfer (streaming service or nothing playing)',

      // Errors
      'error': 'Error',
      'scanningNetwork': 'Scanning network...',
      'foundInterfaces': 'Found network interfaces',
      'scanningSubnet': 'Scanning subnet',
    },
    'de': {
      // App
      'appTitle': 'BlueSound Controller',

      // Navigation
      'home': 'Start',
      'players': 'Player',
      'presets': 'Presets',
      'settings': 'Einstellungen',

      // Player
      'availablePlayers': 'Verfügbare Player',
      'noPlayersFound': 'Keine Player gefunden',
      'scanNetwork': 'Netzwerk scannen',
      'selectPlayerFirst': 'Wähle zuerst einen Player',
      'noPlayerSelected': 'Kein Player ausgewählt',

      // Playback
      'noSongPlaying': 'Kein Song wird abgespielt',
      'playing': 'Spielt',
      'paused': 'Pausiert',
      'stopped': 'Gestoppt',
      'play': 'Abspielen',
      'pause': 'Pause',
      'stop': 'Stopp',
      'next': 'Weiter',
      'previous': 'Zurück',

      // Presets
      'availablePresets': 'Verfügbare Presets',
      'noPresetsFound': 'Keine Presets gefunden',
      'reload': 'Neu laden',
      'playingPreset': 'Spielt',
      'failedToPlayPreset': 'Preset konnte nicht abgespielt werden',
      'categoryStations': 'Sender',
      'categoryPlaylists': 'Playlists',
      'categoryAlbums': 'Alben',
      'categorySongs': 'Songs',

      // Volume
      'volume': 'Lautstärke',
      'volumeNA': 'N/V',
      'failedToSetVolume': 'Lautstärke konnte nicht eingestellt werden',
      'groupVolume': 'Gruppenlautstärke',

      // Settings
      'language': 'Sprache',
      'theme': 'Design',
      'themeSystem': 'System',
      'themeLight': 'Hell',
      'themeDark': 'Dunkel',
      'followSystemSettings': 'Systemeinstellungen folgen',
      'statusUpdates': 'Status-Aktualisierung',
      'autoRefresh': 'Automatisch aktualisieren',
      'autoRefreshDescription': 'Wiedergabestatus automatisch aktualisieren',
      'refreshInterval': 'Aktualisierungsintervall',
      'seconds': 'Sekunden',
      'about': 'Über',
      'version': 'Version',
      'licenses': 'Open-Source-Lizenzen',
      'buyMeACoffee': 'Dem Entwickler einen Kaffee kaufen',
      'donationMessage': 'Wenn dir die App gefällt, kannst du die Entwicklung mit einer kleinen Spende unterstützen. Vielen Dank!',
      'donate': 'Spenden',

      // Actions
      'refresh': 'Aktualisieren',
      'refreshNow': 'Jetzt aktualisieren',

      // Auto-refresh
      'autoRefreshActive': 'Auto-Refresh',

      // Grouping
      'groupPlayers': 'Player gruppieren',
      'ungroupAll': 'Alle trennen',
      'groupWith': 'Gruppieren mit',
      'grouped': 'Gruppiert',
      'ungrouped': 'Getrennt',
      'groupingFailed': 'Gruppierung fehlgeschlagen',
      'ungroupingFailed': 'Trennung fehlgeschlagen',
      'selectPlayersToGroup': 'Player zum Gruppieren auswählen',

      // Transfer
      'transfer': 'Übergeben',
      'transferTo': 'Übergeben an',
      'transferSuccess': 'Übergeben',
      'transferFailed': 'Übergabe fehlgeschlagen',
      'nothingPlaying': 'Übergabe nicht möglich (Streaming-Dienst oder nichts aktiv)',

      // Errors
      'error': 'Fehler',
      'scanningNetwork': 'Scanne Netzwerk...',
      'foundInterfaces': 'Netzwerk-Interfaces gefunden',
      'scanningSubnet': 'Scanne Subnetz',
    },
    'sw': {
      // App
      'appTitle': 'BlueSound Controller',

      // Navigation
      'home': 'Nyumbani',
      'players': 'Vichezaji',
      'presets': 'Presets',
      'settings': 'Mipangilio',

      // Player
      'availablePlayers': 'Vichezaji Vinavyopatikana',
      'noPlayersFound': 'Hakuna vichezaji vilivyopatikana',
      'scanNetwork': 'Tafuta Mtandao',
      'selectPlayerFirst': 'Chagua kichezaji kwanza',
      'noPlayerSelected': 'Hakuna kichezaji kilichochaguliwa',

      // Playback
      'noSongPlaying': 'Hakuna wimbo unaocheza',
      'playing': 'Inacheza',
      'paused': 'Imesimamishwa',
      'stopped': 'Imesimama',
      'play': 'Cheza',
      'pause': 'Simamisha',
      'stop': 'Simama',
      'next': 'Ifuatayo',
      'previous': 'Iliyopita',

      // Presets
      'availablePresets': 'Presets Zinazopatikana',
      'noPresetsFound': 'Hakuna presets zilizopatikana',
      'reload': 'Pakia upya',
      'playingPreset': 'Inacheza',
      'failedToPlayPreset': 'Imeshindwa kucheza preset',
      'categoryStations': 'Vituo',
      'categoryPlaylists': 'Orodha za Nyimbo',
      'categoryAlbums': 'Albamu',
      'categorySongs': 'Nyimbo',

      // Volume
      'volume': 'Sauti',
      'volumeNA': 'Haipo',
      'failedToSetVolume': 'Imeshindwa kuweka sauti',
      'groupVolume': 'Sauti ya kikundi',

      // Settings
      'language': 'Lugha',
      'theme': 'Mandhari',
      'themeSystem': 'Mfumo',
      'themeLight': 'Mwanga',
      'themeDark': 'Giza',
      'followSystemSettings': 'Fuata mipangilio ya mfumo',
      'statusUpdates': 'Masasisho ya Hali',
      'autoRefresh': 'Sasisha kiotomatiki',
      'autoRefreshDescription': 'Sasisha hali ya kucheza kiotomatiki',
      'refreshInterval': 'Muda wa kusasisha',
      'seconds': 'sekunde',
      'about': 'Kuhusu',
      'version': 'Toleo',
      'licenses': 'Leseni za Open Source',
      'buyMeACoffee': 'Mnunulie msanidi kahawa',
      'donationMessage': 'Ikiwa unapenda programu hii, unaweza kusaidia maendeleo yake kwa mchango mdogo. Asante!',
      'donate': 'Changia',

      // Actions
      'refresh': 'Sasisha',
      'refreshNow': 'Sasisha sasa',

      // Auto-refresh
      'autoRefreshActive': 'Sasisha-auto',

      // Grouping
      'groupPlayers': 'Unganisha Vichezaji',
      'ungroupAll': 'Tenganisha Vyote',
      'groupWith': 'Unganisha na',
      'grouped': 'Imeunganishwa',
      'ungrouped': 'Imetenganishwa',
      'groupingFailed': 'Kuunganisha kumeshindwa',
      'ungroupingFailed': 'Kutenganisha kumeshindwa',
      'selectPlayersToGroup': 'Chagua vichezaji vya kuunganisha',

      // Transfer
      'transfer': 'Hamisha',
      'transferTo': 'Hamisha kwa',
      'transferSuccess': 'Imehamishwa',
      'transferFailed': 'Kuhamisha kumeshindwa',
      'nothingPlaying': 'Haiwezekani kuhamisha (huduma ya utiririshaji au hakuna kinachocheza)',

      // Errors
      'error': 'Hitilafu',
      'scanningNetwork': 'Inatafuta mtandao...',
      'foundInterfaces': 'Interfaces za mtandao zimepatikana',
      'scanningSubnet': 'Inatafuta subnet',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // App
  String get appTitle => get('appTitle');

  // Navigation
  String get home => get('home');
  String get players => get('players');
  String get presets => get('presets');
  String get settings => get('settings');

  // Player
  String get availablePlayers => get('availablePlayers');
  String get noPlayersFound => get('noPlayersFound');
  String get scanNetwork => get('scanNetwork');
  String get selectPlayerFirst => get('selectPlayerFirst');
  String get noPlayerSelected => get('noPlayerSelected');

  // Playback
  String get noSongPlaying => get('noSongPlaying');
  String get playing => get('playing');
  String get paused => get('paused');
  String get stopped => get('stopped');
  String get play => get('play');
  String get pause => get('pause');
  String get stop => get('stop');
  String get next => get('next');
  String get previous => get('previous');

  // Presets
  String get availablePresets => get('availablePresets');
  String get noPresetsFound => get('noPresetsFound');
  String get reload => get('reload');
  String get playingPreset => get('playingPreset');
  String get failedToPlayPreset => get('failedToPlayPreset');
  String get categoryStations => get('categoryStations');
  String get categoryPlaylists => get('categoryPlaylists');
  String get categoryAlbums => get('categoryAlbums');
  String get categorySongs => get('categorySongs');

  // Volume
  String get volume => get('volume');
  String get volumeNA => get('volumeNA');
  String get failedToSetVolume => get('failedToSetVolume');
  String get groupVolume => get('groupVolume');

  // Settings
  String get language => get('language');
  String get theme => get('theme');
  String get themeSystem => get('themeSystem');
  String get themeLight => get('themeLight');
  String get themeDark => get('themeDark');
  String get followSystemSettings => get('followSystemSettings');
  String get statusUpdates => get('statusUpdates');
  String get autoRefresh => get('autoRefresh');
  String get autoRefreshDescription => get('autoRefreshDescription');
  String get refreshInterval => get('refreshInterval');
  String get seconds => get('seconds');
  String get about => get('about');
  String get version => get('version');
  String get licenses => get('licenses');
  String get buyMeACoffee => get('buyMeACoffee');
  String get donationMessage => get('donationMessage');
  String get donate => get('donate');

  // Actions
  String get refresh => get('refresh');
  String get refreshNow => get('refreshNow');

  // Auto-refresh
  String get autoRefreshActive => get('autoRefreshActive');

  // Grouping
  String get groupPlayers => get('groupPlayers');
  String get ungroupAll => get('ungroupAll');
  String get groupWith => get('groupWith');
  String get grouped => get('grouped');
  String get ungrouped => get('ungrouped');
  String get groupingFailed => get('groupingFailed');
  String get ungroupingFailed => get('ungroupingFailed');
  String get selectPlayersToGroup => get('selectPlayersToGroup');

  // Transfer
  String get transfer => get('transfer');
  String get transferTo => get('transferTo');
  String get transferSuccess => get('transferSuccess');
  String get transferFailed => get('transferFailed');
  String get nothingPlaying => get('nothingPlaying');

  // Errors
  String get error => get('error');
  String get scanningNetwork => get('scanningNetwork');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'de', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
