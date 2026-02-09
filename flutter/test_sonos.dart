// Test script for Sonos preset playback
// Run with: dart run test_sonos.dart <sonos_ip>

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    // Try to find Sonos devices on common subnets
    print('Scanning for Sonos devices...');
    final sonosIp = await findSonosDevice();
    if (sonosIp == null) {
      print('No Sonos device found. Please provide IP as argument.');
      print('Usage: dart run test_sonos.dart <sonos_ip>');
      exit(1);
    }
    print('Found Sonos at: $sonosIp');
    await testSonos(sonosIp);
  } else {
    await testSonos(args[0]);
  }
}

Future<String?> findSonosDevice() async {
  final client = http.Client();

  // Get local IP to determine subnet
  final interfaces = await NetworkInterface.list();
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        final parts = addr.address.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          print('Scanning subnet: $subnet.x');

          // Scan common IPs
          final futures = <Future<String?>>[];
          for (var i = 1; i <= 254; i++) {
            final ip = '$subnet.$i';
            futures.add(_checkSonos(client, ip));
          }

          final results = await Future.wait(futures);
          for (final result in results) {
            if (result != null) {
              client.close();
              return result;
            }
          }
        }
      }
    }
  }
  client.close();
  return null;
}

Future<String?> _checkSonos(http.Client client, String ip) async {
  try {
    final response = await client
        .get(Uri.parse('http://$ip:1400/xml/device_description.xml'))
        .timeout(const Duration(seconds: 2));

    if (response.statusCode == 200 &&
        (response.body.contains('Sonos') || response.body.contains('RINCON'))) {
      return ip;
    }
  } catch (_) {}
  return null;
}

Future<void> testSonos(String ip) async {
  print('\n=== Testing Sonos at $ip ===\n');

  // Test 1: Get device info
  print('1. Getting device info...');
  try {
    final response = await http.get(
      Uri.parse('http://$ip:1400/xml/device_description.xml'),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final nameMatch = RegExp(r'<friendlyName>([^<]+)</friendlyName>')
          .firstMatch(response.body);
      final modelMatch = RegExp(r'<modelName>([^<]+)</modelName>')
          .firstMatch(response.body);
      print('   Device: ${nameMatch?.group(1) ?? "Unknown"}');
      print('   Model: ${modelMatch?.group(1) ?? "Unknown"}');
    }
  } catch (e) {
    print('   Error: $e');
  }

  // Test 2: Get transport state
  print('\n2. Getting transport state...');
  try {
    final result = await soapRequest(
      ip,
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'GetTransportInfo',
      '<InstanceID>0</InstanceID>',
    );
    final stateMatch = RegExp(r'<CurrentTransportState>([^<]+)</CurrentTransportState>')
        .firstMatch(result);
    print('   State: ${stateMatch?.group(1) ?? "Unknown"}');
  } catch (e) {
    print('   Error: $e');
  }

  // Test 3: Get favorites/presets
  print('\n3. Getting favorites...');
  final favorites = <Map<String, String>>[];

  for (final objectId in ['FV:2', 'R:0/0']) {
    try {
      final result = await soapRequest(
        ip,
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

      // Parse favorites from result
      final decoded = result
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final titleMatches = RegExp(r'<dc:title>([^<]+)</dc:title>').allMatches(decoded);
      final resMatches = RegExp(r'<res[^>]*>([^<]+)</res>').allMatches(decoded);

      final titles = titleMatches.map((m) => m.group(1) ?? '').toList();
      final uris = resMatches.map((m) => m.group(1) ?? '').toList();

      for (var i = 0; i < titles.length && i < uris.length; i++) {
        if (titles[i].isNotEmpty) {
          favorites.add({'title': titles[i], 'uri': uris[i]});
        }
      }
    } catch (e) {
      print('   Browse $objectId error: $e');
    }
  }

  if (favorites.isEmpty) {
    print('   No favorites found.');
    return;
  }

  print('   Found ${favorites.length} favorites:');
  for (var i = 0; i < favorites.length && i < 5; i++) {
    print('   ${i + 1}. ${favorites[i]['title']}');
  }

  // Test 4: Play first favorite using SetAVTransportURI
  print('\n4. Testing SetAVTransportURI with first favorite...');
  final firstFavorite = favorites.first;
  final uri = escapeXml(firstFavorite['uri'] ?? '');

  print('   URI: ${firstFavorite['uri']?.substring(0, 50)}...');

  try {
    final result = await soapRequest(
      ip,
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'SetAVTransportURI',
      '''<InstanceID>0</InstanceID>
<CurrentURI>$uri</CurrentURI>
<CurrentURIMetaData></CurrentURIMetaData>''',
    );
    print('   SetAVTransportURI: SUCCESS');

    // Now play
    print('\n5. Starting playback...');
    await soapRequest(
      ip,
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'Play',
      '<InstanceID>0</InstanceID><Speed>1</Speed>',
    );
    print('   Play: SUCCESS');

    // Check state after play
    await Future.delayed(const Duration(seconds: 2));
    final stateResult = await soapRequest(
      ip,
      '/MediaRenderer/AVTransport/Control',
      'AVTransport',
      'GetTransportInfo',
      '<InstanceID>0</InstanceID>',
    );
    final stateMatch = RegExp(r'<CurrentTransportState>([^<]+)</CurrentTransportState>')
        .firstMatch(stateResult);
    print('   New state: ${stateMatch?.group(1) ?? "Unknown"}');

  } catch (e) {
    print('   Error: $e');
  }

  print('\n=== Test complete ===');
}

Future<String> soapRequest(
  String ip,
  String path,
  String service,
  String action,
  String body,
) async {
  final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $body
    </u:$action>
  </s:Body>
</s:Envelope>''';

  final response = await http.post(
    Uri.parse('http://$ip:1400$path'),
    headers: {
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': '"urn:schemas-upnp-org:service:$service:1#$action"',
    },
    body: envelope,
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('SOAP error ${response.statusCode}: ${response.body}');
  }

  return response.body;
}

String escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
