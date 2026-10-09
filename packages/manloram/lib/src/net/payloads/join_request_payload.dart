/// A player in the lobby asking to drop into the running match that started
/// at [startedAt].
class JoinRequestPayload {
  const JoinRequestPayload({required this.id, required this.startedAt});

  factory JoinRequestPayload.fromJson(Map<String, dynamic> json) {
    return JoinRequestPayload(
      id: json['id'] as String,
      startedAt: json['startedAt'] as int,
    );
  }

  final String id;
  final int startedAt;

  Map<String, dynamic> toJson() => {'id': id, 'startedAt': startedAt};
}
