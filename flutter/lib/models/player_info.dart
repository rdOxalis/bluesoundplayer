import 'device_type.dart';

/// Information about a discovered audio player.
class PlayerInfo {
  final String ip;
  final String name;
  final String brand;
  final String model;
  final DeviceType type;
  final String? uuid; // Sonos RINCON ID, e.g. "RINCON_000E5872AA6801400"

  const PlayerInfo({
    required this.ip,
    required this.name,
    required this.brand,
    required this.model,
    required this.type,
    this.uuid,
  });

  /// Display name with brand and model info.
  String get displayName => '$name ($brand $model)';

  /// Short display for lists.
  String get shortName => name.isNotEmpty ? name : ip;

  /// Check if this is a BluOS device.
  bool get isBluOS => type == DeviceType.bluos;

  /// Check if this is a Sonos device.
  bool get isSonos => type == DeviceType.sonos;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerInfo &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          type == other.type;

  @override
  int get hashCode => ip.hashCode ^ type.hashCode;

  @override
  String toString() => 'PlayerInfo($name @ $ip [$type])';

  PlayerInfo copyWith({
    String? ip,
    String? name,
    String? brand,
    String? model,
    DeviceType? type,
    String? uuid,
  }) {
    return PlayerInfo(
      ip: ip ?? this.ip,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      type: type ?? this.type,
      uuid: uuid ?? this.uuid,
    );
  }
}
