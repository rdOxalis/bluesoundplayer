import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/models.dart';
import 'audio_client.dart';

/// Client for BluOS devices using REST API.
///
/// BluOS uses simple HTTP GET requests on port 11000.
class BluOSClient implements AudioClient {
  static const int port = 11000;
  static const Duration timeout = Duration(seconds: 10);

  final String _ip;
  final http.Client _httpClient;
  final String _baseUrl;

  BluOSClient(this._ip, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = 'http://$_ip:$port';

  @override
  String get ip => _ip;

  @override
  DeviceType get deviceType => DeviceType.bluos;

  /// Make a GET request to the BluOS API.
  Future<String> _get(String endpoint) async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl$endpoint'))
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw AudioClientException(
          'API returned status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return utf8.decode(response.bodyBytes);
    } on TimeoutException {
      throw const AudioClientException('Request timed out');
    } catch (e) {
      if (e is AudioClientException) rethrow;
      throw AudioClientException('Request failed: $e', originalError: e);
    }
  }

  @override
  Future<Status> getStatus() async {
    final xml = await _get('/Status');
    final document = XmlDocument.parse(xml);
    final status = document.findAllElements('status').first;

    String getText(String name) {
      final elements = status.findElements(name);
      return elements.isEmpty ? '' : elements.first.innerText;
    }

    int getInt(String name, int defaultValue) {
      final text = getText(name);
      return text.isEmpty ? defaultValue : int.tryParse(text) ?? defaultValue;
    }

    // BluOS <song> contains track index (0, 1, ...), not the song name.
    // The actual titles are in <title1>, <title2>, <title3> or <name>.
    final rawSong = getText('song');
    final title1 = getText('title1');
    final title2 = getText('title2');
    final title3 = getText('title3');
    final name = getText('name');

    // Song: prefer title1, fall back to name, then rawSong if not purely numeric
    String song = title1;
    if (song.isEmpty) song = name;
    if (song.isEmpty && rawSong.isNotEmpty && int.tryParse(rawSong) == null) {
      song = rawSong;
    }

    // Artist: prefer title2, fall back to artist field
    String artist = title2;
    if (artist.isEmpty) artist = getText('artist');

    // Album: prefer title3, fall back to album field
    String album = title3;
    if (album.isEmpty) album = getText('album');

    // Volume: if individual volume is -1 (e.g. grouped player), try groupVolume
    int volume = getInt('volume', -1);
    if (volume < 0) {
      volume = getInt('groupVolume', -1);
    }
    // If still -1, try fetching volume directly
    if (volume < 0) {
      try {
        final volXml = await _get('/Volume');
        final volDoc = XmlDocument.parse(volXml);
        final volEl = volDoc.findAllElements('volume').firstOrNull;
        if (volEl != null) {
          volume = int.tryParse(volEl.innerText) ?? -1;
        }
      } catch (_) {}
    }

    return Status(
      state: getText('state').isEmpty ? 'stopped' : getText('state'),
      song: song,
      artist: artist,
      album: album,
      volume: volume,
    );
  }

  @override
  Future<List<Preset>> getPresets() async {
    final xml = await _get('/Presets');
    final document = XmlDocument.parse(xml);
    final presets = <Preset>[];

    for (final preset in document.findAllElements('preset')) {
      final id = int.tryParse(preset.getAttribute('id') ?? '') ?? 0;
      final name = preset.getAttribute('name') ?? '';
      final url = preset.getAttribute('url') ?? '';
      final image = preset.getAttribute('image') ?? '';

      if (id > 0 && name.isNotEmpty) {
        presets.add(Preset(id: id, name: name, url: url, image: image));
      }
    }

    return presets;
  }

  @override
  Future<void> playPreset(int id) async {
    await _get('/Preset?id=$id');
  }

  @override
  Future<void> play() async {
    await _get('/Play');
  }

  @override
  Future<void> pause() async {
    await _get('/Pause');
  }

  @override
  Future<void> stop() async {
    await _get('/Stop');
  }

  @override
  Future<void> next() async {
    await _get('/Skip');
  }

  @override
  Future<void> previous() async {
    await _get('/Back');
  }

  @override
  Future<void> setVolume(int level) async {
    if (level < 0 || level > 100) {
      throw ArgumentError('Volume must be between 0 and 100');
    }
    await _get('/Volume?level=$level');
  }

  @override
  Future<void> addSlave(String slaveIP, {String? slaveUuid, String? masterUuid}) async {
    await _get('/AddSlave?slave=$slaveIP&port=$port');
  }

  @override
  Future<void> removeSlave(String slaveIP) async {
    await _get('/RemoveSlave?slave=$slaveIP&port=$port');
  }

  @override
  Future<void> removeAllSlaves() async {
    // BluOS has no single "remove all" endpoint.
    // Try /Standalone first, then /LeaveGroup as fallback.
    try {
      await _get('/Standalone');
      return;
    } catch (_) {}
    try {
      await _get('/LeaveGroup');
    } catch (_) {}
  }

  @override
  Future<void> leaveGroup() async {
    try {
      await _get('/LeaveGroup');
      return;
    } catch (_) {}
    try {
      await _get('/Standalone');
    } catch (_) {}
  }

  @override
  Future<Map<String, List<String>>> getGroupInfo() async {
    // BluOS: check /SyncStatus for group info
    try {
      final xml = await _get('/SyncStatus');
      final document = XmlDocument.parse(xml);
      final syncStatus = document.findAllElements('SyncStatus').firstOrNull;
      if (syncStatus == null) return {};

      // Check if this player is a slave: <master port="...">IP</master>
      final masterEl = syncStatus.findElements('master').firstOrNull;
      final masterIp = masterEl?.innerText.trim() ?? '';
      if (masterIp.isNotEmpty) {
        return {masterIp: [_ip]};
      }

      // Check for slave elements: <slave id="IP" port="..."/>
      final slaves = <String>[];
      for (final slave in syncStatus.findAllElements('slave')) {
        final slaveIp = slave.getAttribute('id') ?? slave.getAttribute('ip') ?? slave.innerText;
        if (slaveIp.isNotEmpty) slaves.add(slaveIp);
      }

      if (slaves.isNotEmpty) {
        return {_ip: slaves};
      }
    } catch (_) {}
    return {};
  }

  @override
  String debugAPI() {
    return '''BluOS API Debug Info:
Base URL: $_baseUrl
Endpoints:
  GET /Status - Get playback status
  GET /Presets - Get presets list
  GET /Preset?id=N - Play preset N
  GET /Play - Start playback
  GET /Pause - Pause playback
  GET /Stop - Stop playback
  GET /Skip - Next track
  GET /Back - Previous track
  GET /Volume?level=N - Set volume (0-100)
  GET /AddSlave?slave=IP - Add slave to group
  GET /RemoveSlave?slave=IP - Remove slave
  GET /RemoveAllSlaves - Remove all slaves
  GET /LeaveGroup - Leave group as slave
  GET /SyncStatus - Get device info''';
  }

  /// Detect if this IP hosts a BluOS device and get its info.
  static Future<PlayerInfo?> detect(String ip, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('http://$ip:$port/SyncStatus'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
      final syncStatus = document.findAllElements('SyncStatus').firstOrNull;
      if (syncStatus == null) return null;

      final name = syncStatus.getAttribute('name') ?? ip;
      final brand = syncStatus.getAttribute('brand') ?? 'Bluesound';
      final model = syncStatus.getAttribute('model') ?? 'Unknown';

      return PlayerInfo(
        ip: ip,
        name: name,
        brand: brand,
        model: model,
        type: DeviceType.bluos,
      );
    } catch (_) {
      return null;
    }
  }
}
