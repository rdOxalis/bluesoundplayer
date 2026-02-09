import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../api/bluos_client.dart';
import '../api/sonos_client.dart';

/// Service for discovering audio players on the network.
class NetworkScanner {
  static const Duration scanTimeout = Duration(seconds: 3);

  // Network prefixes to scan
  static const _allowedPrefixes = ['192.168.', '10.0.0.', '10.0.1.', '172.16.'];
  static const _blockedPrefixes = ['10.0.2.', '172.17.']; // VirtualBox, Docker

  final http.Client _httpClient;

  NetworkScanner({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Scan the network for all audio players.
  ///
  /// Returns a list of discovered players sorted by IP address.
  /// The [onProgress] callback is called with progress updates.
  Future<List<PlayerInfo>> scan({
    void Function(String message)? onProgress,
    void Function(PlayerInfo player)? onPlayerFound,
  }) async {
    final interfaces = await _getNetworkInterfaces();
    onProgress?.call('Found ${interfaces.length} network interfaces');

    final subnets = <String>{};
    for (final iface in interfaces) {
      if (_isUsefulNetwork(iface.subnet)) {
        subnets.add(iface.subnet);
      }
    }

    onProgress?.call('Scanning ${subnets.length} subnets...');

    final allPlayers = <PlayerInfo>[];

    for (final subnet in subnets) {
      onProgress?.call('Scanning $subnet.x ...');
      final players = await _scanSubnet(subnet, onPlayerFound: onPlayerFound);
      allPlayers.addAll(players);
    }

    // Deduplicate by IP
    final uniquePlayers = <String, PlayerInfo>{};
    for (final player in allPlayers) {
      uniquePlayers[player.ip] = player;
    }

    // Sort by IP address
    final result = uniquePlayers.values.toList()
      ..sort((a, b) => _ipToInt(a.ip).compareTo(_ipToInt(b.ip)));

    onProgress?.call('Found ${result.length} players');
    return result;
  }

  /// Get all useful network interfaces.
  Future<List<_NetworkInterface>> _getNetworkInterfaces() async {
    final interfaces = <_NetworkInterface>[];

    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          // Only IPv4, non-loopback
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('127.')) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              interfaces.add(_NetworkInterface(
                name: iface.name,
                ip: addr.address,
                subnet: subnet,
              ));
            }
          }
        }
      }
    } catch (e) {
      // Fallback: try common subnets
      interfaces.add(_NetworkInterface(
        name: 'fallback',
        ip: '0.0.0.0',
        subnet: '192.168.1',
      ));
    }

    return interfaces;
  }

  /// Check if this subnet should be scanned.
  bool _isUsefulNetwork(String subnet) {
    // Check blocked prefixes first
    for (final prefix in _blockedPrefixes) {
      if (subnet.startsWith(prefix.substring(0, prefix.length - 1))) {
        return false;
      }
    }

    // Check allowed prefixes
    for (final prefix in _allowedPrefixes) {
      if (subnet.startsWith(prefix.substring(0, prefix.length - 1))) {
        return true;
      }
    }

    return false;
  }

  /// Scan a single subnet for players.
  Future<List<PlayerInfo>> _scanSubnet(
    String subnet, {
    void Function(PlayerInfo player)? onPlayerFound,
  }) async {
    final futures = <Future<PlayerInfo?>>[];

    for (var i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futures.add(_checkHost(ip, onPlayerFound: onPlayerFound));
    }

    final results = await Future.wait(futures);
    return results.whereType<PlayerInfo>().toList();
  }

  /// Check if a host has a BluOS or Sonos device.
  Future<PlayerInfo?> _checkHost(
    String ip, {
    void Function(PlayerInfo player)? onPlayerFound,
  }) async {
    // Try BluOS first (faster response typically)
    final bluos = await BluOSClient.detect(ip, client: _httpClient);
    if (bluos != null) {
      onPlayerFound?.call(bluos);
      return bluos;
    }

    // Try Sonos
    final sonos = await SonosClient.detect(ip, client: _httpClient);
    if (sonos != null) {
      onPlayerFound?.call(sonos);
      return sonos;
    }

    return null;
  }

  /// Convert IP address to integer for sorting.
  int _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;

    return (int.tryParse(parts[0]) ?? 0) << 24 |
        (int.tryParse(parts[1]) ?? 0) << 16 |
        (int.tryParse(parts[2]) ?? 0) << 8 |
        (int.tryParse(parts[3]) ?? 0);
  }

  void dispose() {
    _httpClient.close();
  }
}

class _NetworkInterface {
  final String name;
  final String ip;
  final String subnet;

  _NetworkInterface({
    required this.name,
    required this.ip,
    required this.subnet,
  });
}
