class LaunchPayload {
  const LaunchPayload({
    required this.id,
    required this.projectileId,
    required this.weaponId,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  factory LaunchPayload.fromJson(Map<String, dynamic> json) {
    return LaunchPayload(
      id: json['id'] as String,
      projectileId: json['projectileId'] as String,
      weaponId: json['weaponId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] as num).toDouble(),
      vy: (json['vy'] as num).toDouble(),
    );
  }

  final String id;
  final String projectileId;
  final String weaponId;
  final double x;
  final double y;
  final double vx;
  final double vy;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectileId': projectileId,
      'weaponId': weaponId,
      'x': x,
      'y': y,
      'vx': vx,
      'vy': vy,
    };
  }
}
