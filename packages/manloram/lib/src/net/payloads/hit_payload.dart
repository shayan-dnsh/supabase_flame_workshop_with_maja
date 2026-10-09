import '../../db/supabase_schema.g.dart';

/// Sent by the player who was hit; [id] is the victim.
class HitPayload {
  const HitPayload({
    required this.id,
    required this.attackerId,
    required this.projectileId,
    required this.weaponId,
    required this.part,
    required this.points,
    required this.hp,
    required this.knockout,
  });

  factory HitPayload.fromJson(Map<String, dynamic> json) {
    return HitPayload(
      id: json['id'] as String,
      attackerId: json['attackerId'] as String,
      projectileId: json['projectileId'] as String,
      weaponId: json['weaponId'] as String,
      part: BodyPart.fromWire(json['part'] as String),
      points: json['points'] as int,
      hp: (json['hp'] as num).toDouble(),
      knockout: json['ko'] as bool,
    );
  }

  final String id;
  final String attackerId;
  final String projectileId;
  final String weaponId;
  final BodyPart part;
  final int points;
  final double hp;
  final bool knockout;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attackerId': attackerId,
      'projectileId': projectileId,
      'weaponId': weaponId,
      'part': part.wireName,
      'points': points,
      'hp': hp,
      'ko': knockout,
    };
  }
}
