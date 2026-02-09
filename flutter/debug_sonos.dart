// Debug script to check Sonos favorites URIs
// Run with: dart run debug_sonos.dart <sonos_ip>

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  String ip;

  if (args.isEmpty) {
    print('Scanning for Sonos devices...');
    ip = await findSonosDevice() ?? '';
    if (ip.isEmpty) {
      print('No Sonos found. Usage: dart run debug_sonos.dart <sonos_ip>');
      exit(1);
    }
  } else {
    ip = args[0];
  }

  print('Sonos IP: $ip\n');

  // Get favorites and show their URIs
  print('=== Fetching Favorites ===\n');

  for (final objectId in ['FV:2', 'R:0/0', 'R:0/1', 'SQ:']) {
    print('--- ObjectID: $objectId ---');
    try {
      final result = await browse(ip, objectId);
      final decoded = result
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      // Extract items
      final itemRegex = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true);
      final items = itemRegex.allMatches(decoded);

      for (final item in items) {
        final content = item.group(1) ?? '';

        final titleMatch = RegExp(r'<dc:title>([^<]+)</dc:title>').firstMatch(content);
        final resMatch = RegExp(r'<res[^>]*>([^<]+)</res>').firstMatch(content);
        final classMatch = RegExp(r'<upnp:class>([^<]+)</upnp:class>').firstMatch(content);

        final title = titleMatch?.group(1) ?? 'Unknown';
        final uri = resMatch?.group(1) ?? 'No URI';
        final itemClass = classMatch?.group(1) ?? 'Unknown class';

        print('  Title: $title');
        print('  Class: $itemClass');
        print('  URI: $uri');
        print('');
      }
    } catch (e) {
      print('  Error: $e\n');
    }
  }
}

Future<String?> findSonosDevice() async {
  final interfaces = await NetworkInterface.list();
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        final parts = addr.address.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (var i = 1; i <= 254; i++) {
            final ip = '$subnet.$i';
            try {
              final response = await http.get(
                Uri.parse('http://$ip:1400/xml/device_description.xml'),
              ).timeout(const Duration(milliseconds: 500));
              if (response.statusCode == 200 &&
                  (response.body.contains('Sonos') || response.body.contains('RINCON'))) {
                return ip;
              }
            } catch (_) {}
          }
        }
      }
    }
  }
  return null;
}

Future<String> browse(String ip, String objectId) async {
  final body = '''<u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
    <ObjectID>$objectId</ObjectID>
    <BrowseFlag>BrowseDirectChildren</BrowseFlag>
    <Filter>*</Filter>
    <StartingIndex>0</StartingIndex>
    <RequestedCount>100</RequestedCount>
    <SortCriteria></SortCriteria>
  </u:Browse>''';

  final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>$body</s:Body>
</s:Envelope>''';

  final response = await http.post(
    Uri.parse('http://$ip:1400/MediaServer/ContentDirectory/Control'),
    headers: {
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': '"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"',
    },
    body: envelope,
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('Browse failed: ${response.statusCode}');
  }

  return response.body;
}
