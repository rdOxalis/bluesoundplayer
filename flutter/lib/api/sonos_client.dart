import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/models.dart';
import 'audio_client.dart';

/// Client for Sonos devices using SOAP/UPnP API.
///
/// Sonos uses SOAP over HTTP on port 1400.
class SonosClient implements AudioClient {
  static const int port = 1400;
  static const Duration timeout = Duration(seconds: 10);

  final String _ip;
  final http.Client _httpClient;
  final String _baseUrl;
  List<_SonosFavorite>? _cachedFavorites;

  SonosClient(this._ip, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = 'http://$_ip:$port';

  @override
  String get ip => _ip;

  @override
  DeviceType get deviceType => DeviceType.sonos;

  /// Send a SOAP request to the Sonos device.
  Future<String> _soap(String path, String service, String action,
      String body) async {
    final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $body
    </u:$action>
  </s:Body>
</s:Envelope>''';

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Content-Type': 'text/xml; charset=utf-8',
              'SOAPAction': '"urn:schemas-upnp-org:service:$service:1#$action"',
            },
            body: envelope,
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw AudioClientException(
          'SOAP request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return utf8.decode(response.bodyBytes);
    } on TimeoutException {
      throw const AudioClientException('Request timed out');
    } catch (e) {
      if (e is AudioClientException) rethrow;
      throw AudioClientException('SOAP request failed: $e', originalError: e);
    }
  }

  /// Extract text from SOAP response by tag name.
  String _extractFromSoap(String xml, String tagName) {
    final document = XmlDocument.parse(xml);
    final elements = document.findAllElements(tagName);
    return elements.isEmpty ? '' : elements.first.innerText;
  }

  @override
  Future<Status> getStatus() async {
    String state = 'stopped';
    String song = '';
    String artist = '';
    String album = '';
    int volume = -1;

    // Get transport state
    try {
      final transportXml = await _soap(
        '/MediaRenderer/AVTransport/Control',
        'AVTransport',
        'GetTransportInfo',
        '<InstanceID>0</InstanceID>',
      );
      final transportState = _extractFromSoap(transportXml, 'CurrentTransportState');
      state = transportState.toLowerCase().replaceAll('_playback', '');
    } catch (_) {}

    // Get track info
    try {
      final positionXml = await _soap(
        '/MediaRenderer/AVTransport/Control',
        'AVTransport',
        'GetPositionInfo',
        '<InstanceID>0</InstanceID>',
      );
      final trackMetaData = _extractFromSoap(positionXml, 'TrackMetaData');
      final trackUri = _extractFromSoap(positionXml, 'TrackURI');
      if (trackMetaData.isNotEmpty) {
        final meta = _parseDidlMetadata(trackMetaData);
        song = meta['title'] ?? '';
        artist = meta['creator'] ?? '';
        album = meta['album'] ?? '';

        // For radio streams: <r:streamContent> has current program info
        // (e.g. '"West Coast" von Lana Del Rey'), use it as artist
        final streamContent = meta['streamContent'] ?? '';
        if (streamContent.isNotEmpty && artist.isEmpty) {
          artist = streamContent;
        }

        // If title looks like a URL/filename, replace with favorite name
        if (_looksLikeUrl(song)) {
          final favName = _findFavoriteNameByUri(trackUri);
          if (favName != null) {
            song = favName;
          } else {
            // Use streamContent as song if available, otherwise clear
            song = streamContent.isNotEmpty ? streamContent : '';
            artist = ''; // avoid showing streamContent twice
          }
        }
      }
    } catch (_) {}

    // Get volume
    try {
      final volumeXml = await _soap(
        '/MediaRenderer/RenderingControl/Control',
        'RenderingControl',
        'GetVolume',
        '<InstanceID>0</InstanceID><Channel>Master</Channel>',
      );
      final volumeStr = _extractFromSoap(volumeXml, 'CurrentVolume');
      volume = int.tryParse(volumeStr) ?? -1;
    } catch (_) {}

    // If no track info and player might be a grouped member, fetch coordinator's status
    if (song.isEmpty && artist.isEmpty) {
      try {
        final groupInfo = await getGroupInfo();
        // Find coordinator IP for this player
        for (final entry in groupInfo.entries) {
          if (entry.value.contains(_ip)) {
            final coordinatorClient = SonosClient(entry.key);
            final coordStatus = await coordinatorClient.getStatus();
            song = coordStatus.song;
            artist = coordStatus.artist;
            album = coordStatus.album;
            break;
          }
        }
      } catch (_) {}
    }

    return Status(
      state: state,
      song: song,
      artist: artist,
      album: album,
      volume: volume,
    );
  }

  /// Parse DIDL-Lite metadata XML.
  Map<String, String> _parseDidlMetadata(String didl) {
    final result = <String, String>{};
    try {
      // Decode HTML entities if needed
      var decoded = didl
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final document = XmlDocument.parse(decoded);

      for (final item in document.findAllElements('item')) {
        for (final child in item.children.whereType<XmlElement>()) {
          final localName = child.name.local;
          if (localName == 'title') {
            result['title'] = child.innerText;
          } else if (localName == 'creator') {
            result['creator'] = child.innerText;
          } else if (localName == 'album') {
            result['album'] = child.innerText;
          } else if (localName == 'streamContent') {
            // <r:streamContent> has the current song/program info for radio streams
            result['streamContent'] = child.innerText;
          }
        }
      }
    } catch (_) {}
    return result;
  }

  @override
  Future<List<Preset>> getPresets() async {
    if (_cachedFavorites != null) {
      return _cachedFavorites!
          .map((f) => Preset(id: f.id, name: f.name, category: f.category))
          .toList();
    }

    final favorites = <_SonosFavorite>[];
    final objectIds = ['FV:2', 'R:0/0', 'R:0/1', 'A:RADIO'];

    final seenNames = <String>{};

    for (final objectId in objectIds) {
      try {
        final xml = await _soap(
          '/MediaServer/ContentDirectory/Control',
          'ContentDirectory',
          'Browse',
          '''<ObjectID>$objectId</ObjectID>
<BrowseFlag>BrowseDirectChildren</BrowseFlag>
<Filter>*</Filter>
<StartingIndex>0</StartingIndex>
<RequestedCount>100</RequestedCount>
<SortCriteria></SortCriteria>''',
        );

        final result = _extractFromSoap(xml, 'Result');
        if (result.isNotEmpty) {
          final items = _parseBrowseResult(result);
          for (final item in items) {
            // Deduplicate by name
            if (!seenNames.contains(item.name)) {
              seenNames.add(item.name);
              favorites.add(item);
            }
          }
        }
      } catch (_) {}
    }

    // Assign sequential IDs
    for (var i = 0; i < favorites.length; i++) {
      favorites[i] = _SonosFavorite(
        id: i + 1,
        name: favorites[i].name,
        uri: favorites[i].uri,
        meta: favorites[i].meta,
        category: favorites[i].category,
        isContainer: favorites[i].isContainer,
      );
    }

    _cachedFavorites = favorites;
    return favorites
        .map((f) => Preset(id: f.id, name: f.name, category: f.category))
        .toList();
  }

  /// Parse Browse response DIDL content (handles both <item> and <container>).
  List<_SonosFavorite> _parseBrowseResult(String didl) {
    final results = <_SonosFavorite>[];
    try {
      var decoded = didl
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final document = XmlDocument.parse(decoded);

      // Process both <item> and <container> elements
      final elements = [
        ...document.findAllElements('item'),
        ...document.findAllElements('container'),
      ];

      for (final element in elements) {
        String title = '';
        String uri = '';
        String upnpClass = '';
        final itemId = element.getAttribute('id') ?? '';

        for (final child in element.children.whereType<XmlElement>()) {
          final localName = child.name.local;
          if (localName == 'title') {
            title = child.innerText;
          } else if (localName == 'res') {
            uri = child.innerText;
          } else if (localName == 'class') {
            upnpClass = child.innerText;
          }
        }

        if (title.isNotEmpty) {
          final category = _categorize(upnpClass, uri);
          if (category == null) continue;

          // Detect container-type by upnp:class (even if XML element is <item>)
          var isContainerType = upnpClass.toLowerCase().contains('container') ||
              upnpClass.toLowerCase().contains('album');

          // For items without a <res> URI, construct from item ID
          if (uri.isEmpty && itemId.isNotEmpty) {
            uri = 'x-rincon-cpcontainer:$itemId';
            // Items without <res> always need queue-based playback
            isContainerType = true;
          }

          final meta = element.toXmlString(pretty: false);
          results.add(_SonosFavorite(
            id: 0,
            name: title,
            uri: uri,
            meta: meta,
            category: category,
            isContainer: isContainerType,
          ));
        }
      }
    } catch (_) {}
    return results;
  }

  /// Categorize a Sonos favorite by its UPnP class, URI, and metadata.
  /// Returns null for unrecognized types.
  PresetCategory? _categorize(String upnpClass, String uri) {
    final cls = upnpClass.toLowerCase();
    final lowerUri = uri.toLowerCase();

    // Album lists (meta-containers, not directly playable)
    if (cls.contains('albumlist')) {
      return null;
    }

    // Radio / audio broadcast
    if (cls.contains('audiobroadcast') || cls.contains('radio')) {
      return PresetCategory.station;
    }
    // Music track
    if (cls.contains('musictrack') || cls.contains('audioitem') && !cls.contains('broadcast')) {
      // audioItem without broadcast → song (unless URI says otherwise)
      if (lowerUri.contains('x-sonosapi-stream:') ||
          lowerUri.contains('x-sonosapi-radio:') ||
          lowerUri.contains('x-rincon-mp3radio:')) {
        return PresetCategory.station;
      }
      if (cls.contains('musictrack')) return PresetCategory.song;
    }
    // Album
    if (cls.contains('musicalbum') || cls.contains('album')) {
      return PresetCategory.album;
    }
    // Playlist container
    if (cls.contains('playlistcontainer') || cls.contains('playlist')) {
      return PresetCategory.playlist;
    }
    // StorageFolder or generic container → playlist
    if (cls.contains('container') || cls.contains('storagefolder')) {
      return PresetCategory.playlist;
    }

    // URI-based fallback for items without clear class
    if (lowerUri.contains('x-sonosapi-stream:') ||
        lowerUri.contains('x-sonosapi-radio:') ||
        lowerUri.contains('x-rincon-mp3radio:') ||
        lowerUri.contains('mms://') ||
        lowerUri.contains('rtsp://')) {
      return PresetCategory.station;
    }
    if (lowerUri.contains('x-sonosapi-hls:') ||
        lowerUri.contains('x-sonos-spotify:') ||
        lowerUri.contains('x-sonos-http:')) {
      return PresetCategory.playlist;
    }
    if (lowerUri.startsWith('http://') || lowerUri.startsWith('https://')) {
      return PresetCategory.station;
    }

    return null;
  }

  @override
  Future<void> playPreset(int id) async {
    if (_cachedFavorites == null) {
      await getPresets();
    }

    final favorite = _cachedFavorites?.firstWhere(
      (f) => f.id == id,
      orElse: () => throw AudioClientException('Preset $id not found'),
    );

    if (favorite == null) {
      throw AudioClientException('Preset $id not found');
    }

    // Container types (playlists, albums) need queue-based playback.
    // Direct URIs (streams, single tracks) use SetAVTransportURI.
    if (favorite.isContainer) {
      await _playContainer(favorite);
    } else {
      await _playItem(favorite);
    }
  }

  /// Play an item-type favorite via SetAVTransportURI (stations, songs).
  Future<void> _playItem(_SonosFavorite favorite) async {
    final escapedUri = _escapeXml(favorite.uri);

    // Use the original item metadata from browse response, wrapped in DIDL-Lite
    String metadata;
    if (favorite.meta.isNotEmpty) {
      metadata = _escapeXml(
        '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
        'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
        '${favorite.meta}'
        '</DIDL-Lite>',
      );
    } else {
      metadata = _escapeXml(
        '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
        'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
        '<item id="R:0/0/0" parentID="R:0/0" restricted="true">'
        '<dc:title>${favorite.name}</dc:title>'
        '<upnp:class>object.item.audioItem.audioBroadcast</upnp:class>'
        '<desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON65031_</desc>'
        '</item></DIDL-Lite>',
      );
    }

    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'SetAVTransportURI',
      '''<InstanceID>0</InstanceID>
<CurrentURI>$escapedUri</CurrentURI>
<CurrentURIMetaData>$metadata</CurrentURIMetaData>''',
    );

    await play();
  }

  /// Play a container-type favorite via queue (playlists, albums).
  Future<void> _playContainer(_SonosFavorite favorite) async {

    final escapedUri = _escapeXml(favorite.uri);

    // Build metadata: wrap the item XML in DIDL-Lite envelope and escape
    String metadata = '';
    if (favorite.meta.isNotEmpty) {
      metadata = _escapeXml(
        '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
        'xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
        '${favorite.meta}'
        '</DIDL-Lite>',
      );
    }

    // 1. Clear queue
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'RemoveAllTracksFromQueue',
      '<InstanceID>0</InstanceID>',
    );

    // 2. Add container to queue
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'AddURIToQueue',
      '''<InstanceID>0</InstanceID>
<EnqueuedURI>$escapedUri</EnqueuedURI>
<EnqueuedURIMetaData>$metadata</EnqueuedURIMetaData>
<DesiredFirstTrackNumberEnqueued>0</DesiredFirstTrackNumberEnqueued>
<EnqueueAsNext>1</EnqueueAsNext>''',
    );

    // 3. Switch transport to the queue
    final uuid = await _getDeviceUuid();
    if (uuid != null) {
      await _soap(
        '/MediaRenderer/AVTransport/Control',
        'AVTransport',
        'SetAVTransportURI',
        '<InstanceID>0</InstanceID>'
        '<CurrentURI>x-rincon-queue:$uuid#0</CurrentURI>'
        '<CurrentURIMetaData></CurrentURIMetaData>',
      );
    }

    // 4. Play
    await play();
  }

  String? _cachedUuid;

  /// Get the RINCON UUID of this device.
  Future<String?> _getDeviceUuid() async {
    if (_cachedUuid != null) return _cachedUuid;
    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl/xml/device_description.xml'))
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final body = utf8.decode(response.bodyBytes);
      final match =
          RegExp(r'<UDN>uuid:(RINCON_[A-Z0-9]+)</UDN>').firstMatch(body);
      _cachedUuid = match?.group(1);
      return _cachedUuid;
    } catch (_) {
      return null;
    }
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  @override
  Future<void> play() async {
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Play',
      '<InstanceID>0</InstanceID><Speed>1</Speed>',
    );
  }

  @override
  Future<void> pause() async {
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Pause',
      '<InstanceID>0</InstanceID>',
    );
  }

  @override
  Future<void> stop() async {
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Stop',
      '<InstanceID>0</InstanceID>',
    );
  }

  @override
  Future<void> next() async {
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Next',
      '<InstanceID>0</InstanceID>',
    );
  }

  @override
  Future<void> previous() async {
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Previous',
      '<InstanceID>0</InstanceID>',
    );
  }

  @override
  Future<void> setVolume(int level) async {
    if (level < 0 || level > 100) {
      throw ArgumentError('Volume must be between 0 and 100');
    }
    await _soap(
      '/MediaRenderer/RenderingControl/Control',
      'RenderingControl',
      'SetVolume',
      '<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>$level</DesiredVolume>',
    );
  }

  @override
  Future<void> addSlave(String slaveIP, {String? slaveUuid, String? masterUuid}) async {
    if (masterUuid == null || masterUuid.isEmpty) {
      throw const AudioClientException(
        'Sonos grouping requires the master RINCON UUID',
      );
    }
    // Sonos grouping: call SetAVTransportURI on the SLAVE with x-rincon:<master-UUID>
    final slaveClient = SonosClient(slaveIP);
    await slaveClient._soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'SetAVTransportURI',
      '<InstanceID>0</InstanceID>'
      '<CurrentURI>x-rincon:$masterUuid</CurrentURI>'
      '<CurrentURIMetaData></CurrentURIMetaData>',
    );
  }

  @override
  Future<void> removeSlave(String slaveIP) async {
    // Sonos ungrouping: call BecomeCoordinatorOfStandaloneGroup on the slave
    final slaveClient = SonosClient(slaveIP);
    await slaveClient._soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'BecomeCoordinatorOfStandaloneGroup',
      '<InstanceID>0</InstanceID>',
    );
  }

  @override
  Future<void> removeAllSlaves() async {
    // Get zone group topology to find all members in this player's group
    final members = await _getGroupMembers();
    for (final memberIP in members) {
      if (memberIP != _ip) {
        try {
          await removeSlave(memberIP);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> leaveGroup() async {
    // This player leaves its current group
    await _soap(
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'BecomeCoordinatorOfStandaloneGroup',
      '<InstanceID>0</InstanceID>',
    );
  }

  /// Get the IPs of all members in this player's zone group.
  Future<List<String>> _getGroupMembers() async {
    try {
      final xml = await _soap(
        '/ZoneGroupTopology/Control',
        'ZoneGroupTopology',
        'GetZoneGroupState',
        '',
      );
      final stateXml = _extractFromSoap(xml, 'ZoneGroupState');
      if (stateXml.isEmpty) return [];

      final decoded = stateXml
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final doc = XmlDocument.parse(decoded);

      // Find the group that contains this player's IP
      for (final group in doc.findAllElements('ZoneGroup')) {
        final members = group.findAllElements('ZoneGroupMember').toList();
        final ips = <String>[];
        bool containsThisPlayer = false;

        for (final member in members) {
          final location = member.getAttribute('Location') ?? '';
          // Location is like "http://192.168.1.100:1400/xml/device_description.xml"
          final ipMatch = RegExp(r'http://([^:]+):').firstMatch(location);
          if (ipMatch != null) {
            final memberIP = ipMatch.group(1)!;
            ips.add(memberIP);
            if (memberIP == _ip) containsThisPlayer = true;
          }
        }

        if (containsThisPlayer) return ips;
      }
    } catch (_) {}
    return [];
  }

  /// Check if a string looks like a URL or stream filename.
  bool _looksLikeUrl(String s) {
    if (s.isEmpty) return false;
    return s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('x-') ||
        s.startsWith('aac://') ||
        s.startsWith('mms://') ||
        s.contains('stream.') ||
        s.contains('?aggregator=');
  }

  /// Find a favorite's name by matching its URI.
  String? _findFavoriteNameByUri(String uri) {
    if (uri.isEmpty || _cachedFavorites == null) return null;
    for (final fav in _cachedFavorites!) {
      if (fav.uri == uri) return fav.name;
    }
    return null;
  }

  /// Clear the cached favorites list.
  void clearCache() {
    _cachedFavorites = null;
  }

  @override
  Future<Map<String, List<String>>> getGroupInfo() async {
    // Use GetZoneGroupState to find all groups
    final result = <String, List<String>>{};
    try {
      final xml = await _soap(
        '/ZoneGroupTopology/Control',
        'ZoneGroupTopology',
        'GetZoneGroupState',
        '',
      );
      final stateXml = _extractFromSoap(xml, 'ZoneGroupState');
      if (stateXml.isEmpty) return result;

      final decoded = stateXml
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final doc = XmlDocument.parse(decoded);

      for (final group in doc.findAllElements('ZoneGroup')) {
        final coordinatorUuid = group.getAttribute('Coordinator') ?? '';
        final members = group.findAllElements('ZoneGroupMember').toList();
        if (members.length <= 1) continue; // Skip standalone players

        String? coordinatorIp;
        final memberIps = <String>[];

        for (final member in members) {
          final location = member.getAttribute('Location') ?? '';
          final uuid = member.getAttribute('UUID') ?? '';
          final ipMatch = RegExp(r'http://([^:]+):').firstMatch(location);
          if (ipMatch != null) {
            final ip = ipMatch.group(1)!;
            memberIps.add(ip);
            if (uuid == coordinatorUuid) coordinatorIp = ip;
          }
        }

        if (coordinatorIp != null && memberIps.length > 1) {
          result[coordinatorIp] =
              memberIps.where((ip) => ip != coordinatorIp).toList();
        }
      }
    } catch (_) {}
    return result;
  }

  @override
  String debugAPI() {
    return '''Sonos SOAP API Debug Info:
Base URL: $_baseUrl
Services:
  /MediaRenderer/AVTransport/Control
    - GetTransportInfo
    - GetPositionInfo
    - Play, Pause, Stop
    - Next, Previous
    - SetAVTransportURI
    - AddURIToQueue
    - RemoveAllTracksFromQueue
  /MediaRenderer/RenderingControl/Control
    - GetVolume
    - SetVolume
  /MediaServer/ContentDirectory/Control
    - Browse (for favorites)
Note: Grouping is not supported for Sonos devices.''';
  }

  /// Detect if this IP hosts a Sonos device and get its info.
  static Future<PlayerInfo?> detect(String ip, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('http://$ip:$port/xml/device_description.xml'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final body = utf8.decode(response.bodyBytes);
      if (!body.contains('Sonos') && !body.contains('RINCON')) return null;

      // Extract model
      String model = 'Sonos';
      final modelMatch = RegExp(r'<modelName>([^<]+)</modelName>')
          .firstMatch(body);
      if (modelMatch != null) {
        model = modelMatch.group(1) ?? 'Sonos';
      }

      // Extract room name (preferred) or friendly name as fallback
      String name = '';
      final roomMatch = RegExp(r'<roomName>([^<]+)</roomName>')
          .firstMatch(body);
      if (roomMatch != null) {
        name = roomMatch.group(1) ?? '';
      }
      if (name.isEmpty) {
        final nameMatch = RegExp(r'<friendlyName>([^<]+)</friendlyName>')
            .firstMatch(body);
        if (nameMatch != null) {
          name = nameMatch.group(1) ?? '';
          // Clean up name (remove IP, RINCON_, etc.)
          name = name
              .replaceAll(RegExp(r'\d+\.\d+\.\d+\.\d+\s*-?\s*'), '')
              .replaceAll(RegExp(r'\s*-\s*\d+\.\d+\.\d+\.\d+'), '')
              .replaceAll(RegExp(r'\s*-?\s*RINCON_?[A-Z0-9]+.*'), '')
              .trim();
        }
      }
      // Fallback to model name, never show just the IP
      if (name.isEmpty) {
        name = model;
      }

      // Extract RINCON UUID from <UDN>uuid:RINCON_XXXX</UDN>
      String? uuid;
      final udnMatch = RegExp(r'<UDN>uuid:(RINCON_[A-Z0-9]+)</UDN>')
          .firstMatch(body);
      if (udnMatch != null) {
        uuid = udnMatch.group(1);
      }

      return PlayerInfo(
        ip: ip,
        name: name.isEmpty ? ip : name,
        brand: 'Sonos',
        model: model,
        type: DeviceType.sonos,
        uuid: uuid,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Internal class to store Sonos favorite data.
class _SonosFavorite {
  final int id;
  final String name;
  final String uri;
  final String meta;
  final PresetCategory category;
  final bool isContainer;

  _SonosFavorite({
    required this.id,
    required this.name,
    required this.uri,
    required this.meta,
    required this.category,
    required this.isContainer,
  });
}
