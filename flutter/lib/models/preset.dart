/// A preset/favorite for quick playback.
class Preset {
  final int id;
  final String name;
  final String url;
  final String image;

  const Preset({
    required this.id,
    required this.name,
    this.url = '',
    this.image = '',
  });

  /// Whether this preset has an image URL.
  bool get hasImage => image.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preset && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Preset($id: $name)';

  Preset copyWith({
    int? id,
    String? name,
    String? url,
    String? image,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      image: image ?? this.image,
    );
  }
}
