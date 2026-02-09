/// Enum representing the type of audio device.
enum DeviceType {
  bluos('bluos'),
  sonos('sonos');

  final String value;
  const DeviceType(this.value);

  static DeviceType fromString(String value) {
    return DeviceType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => DeviceType.bluos,
    );
  }

  @override
  String toString() => value;
}
