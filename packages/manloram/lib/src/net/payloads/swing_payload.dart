/// A player swinging the chub at [x], [y] (their feet), aiming at [aim].
/// Whoever stands in reach checks for themselves whether it hit them.
class SwingPayload {
  const SwingPayload({
    required this.id,
    required this.swingId,
    required this.x,
    required this.y,
    required this.aim,
  });

  factory SwingPayload.fromJson(Map<String, dynamic> json) {
    return SwingPayload(
      id: json['id'] as String,
      swingId: json['swingId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      aim: (json['aim'] as num).toDouble(),
    );
  }

  final String id;
  final String swingId;
  final double x;
  final double y;
  final double aim;

  Map<String, dynamic> toJson() {
    return {'id': id, 'swingId': swingId, 'x': x, 'y': y, 'aim': aim};
  }
}
