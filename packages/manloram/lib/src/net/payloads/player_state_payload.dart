class PlayerStatePayload {
  const PlayerStatePayload({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.aim,
    this.facing,
    required this.hp,
    required this.knockedOut,
    required this.charging,
    required this.weaponId,
    this.dazed = false,
  });

  factory PlayerStatePayload.fromJson(Map<String, dynamic> json) {
    return PlayerStatePayload(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] as num).toDouble(),
      vy: (json['vy'] as num).toDouble(),
      aim: (json['aim'] as num).toDouble(),
      facing: json['f'] as int?,
      hp: (json['hp'] as num).toDouble(),
      knockedOut: json['ko'] as bool,
      charging: json['ch'] as bool,
      weaponId: json['w'] as String,
      dazed: json['dz'] as bool? ?? false,
    );
  }

  final String id;
  final double x;
  final double y;
  final double vx;
  final double vy;

  /// Aim angle in radians; 0 points right, positive turns clockwise.
  final double aim;

  /// Which way the body faces, 1 right or -1 left. Null from a player on
  /// an older version, who faces the aim instead.
  final int? facing;
  final double hp;
  final bool knockedOut;
  final bool charging;
  final String weaponId;
  final bool dazed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'vx': vx,
      'vy': vy,
      'aim': aim,
      'f': ?facing,
      'hp': hp,
      'ko': knockedOut,
      'ch': charging,
      'w': weaponId,
      'dz': dazed,
    };
  }
}
