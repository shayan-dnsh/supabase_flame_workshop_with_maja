/// The room host, [id], removing [targetId] from the room.
class KickPayload {
  const KickPayload({required this.id, required this.targetId});

  factory KickPayload.fromJson(Map<String, dynamic> json) {
    return KickPayload(
      id: json['id'] as String,
      targetId: json['targetId'] as String,
    );
  }

  final String id;
  final String targetId;

  Map<String, dynamic> toJson() => {'id': id, 'targetId': targetId};
}
