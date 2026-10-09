import '../../game/outfit.dart';

class LobbyPresence {
  const LobbyPresence({
    required this.id,
    required this.name,
    required this.city,
    required this.colorIndex,
    required this.phase,
    this.outfit = Outfit.kolah,
    this.startedAt,
    this.practising = false,
    this.joinedAt = 0,
    this.kicked = const [],
  });

  factory LobbyPresence.fromJson(Map<String, dynamic> json) {
    return LobbyPresence(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      colorIndex: json['color'] as int,
      phase: json['phase'] as String,
      outfit: Outfit.fromId(json['outfit'] as String?),
      startedAt: json['startedAt'] as int?,
      practising: json['practice'] as bool? ?? false,
      joinedAt: json['joinedAt'] as int? ?? 0,
      kicked: (json['kicked'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  static bool isValid(Map<String, dynamic> json) =>
      json['id'] is String &&
      json['name'] is String &&
      json['color'] is int &&
      json['phase'] is String;

  final String id;
  final String name;
  final String city;
  final int colorIndex;
  final String phase;
  final Outfit outfit;
  final int? startedAt;

  /// Practising alone: free to be pulled into a real match at any time.
  final bool practising;

  /// When this player entered the room; the earliest is the room host.
  final int joinedAt;

  /// Players the room host removed, so everyone keeps ignoring them.
  final List<String> kicked;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'color': colorIndex,
      'phase': phase,
      'outfit': outfit.id,
      'startedAt': startedAt,
      'practice': practising,
      'joinedAt': joinedAt,
      'kicked': kicked,
    };
  }
}
