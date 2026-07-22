enum ArchiveType {
  person('person'),
  other('other');

  const ArchiveType(this.databaseValue);

  final String databaseValue;

  static ArchiveType fromDatabase(String value) {
    return ArchiveType.values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => ArchiveType.other,
    );
  }
}

class Archive {
  const Archive({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.alias,
    this.description,
    this.mainImage,
    this.images = const [],
  });

  final String id;
  final String name;
  final String? alias;
  final String? description;
  final ArchiveType type;
  final String? mainImage;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get aliases {
    return (alias ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
