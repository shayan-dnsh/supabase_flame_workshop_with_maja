import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';
import 'net_events.dart';
import 'payloads/hit_payload.dart';
import 'payloads/join_request_payload.dart';
import 'payloads/kick_payload.dart';
import 'payloads/launch_payload.dart';
import 'payloads/lobby_presence.dart';
import 'payloads/match_snapshot_payload.dart';
import 'payloads/match_start_payload.dart';
import 'payloads/player_state_payload.dart';
import 'payloads/swing_payload.dart';

class NetService {
  NetService({required this.myId});

  final String myId;

  /// Whether the Realtime channel is up, so the lobby can say when the game
  /// server cannot be reached.
  final connected = ValueNotifier<bool>(false);

  void Function(PlayerStatePayload payload)? onPlayerState;
  void Function(LaunchPayload payload)? onLaunch;
  void Function(HitPayload payload)? onHit;
  void Function(MatchStartPayload payload)? onMatchStart;
  void Function(JoinRequestPayload payload)? onJoinRequest;
  void Function(MatchSnapshotPayload payload)? onMatchSnapshot;
  void Function(KickPayload payload)? onKick;
  void Function(SwingPayload payload)? onSwing;
  void Function(List<LobbyPresence> roster)? onRosterChanged;
  void Function(String id)? onPeerLeft;

  RealtimeChannel? _channel;
  LobbyPresence? _me;
  bool _disposed = false;
  final _subscriptions = <StreamSubscription<void>>[];

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> connect(LobbyPresence me) async {
    _me = me;
    final channel = _client.channel(
      'manloram-${Env.room}',
      options: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;
    _listen(
      channel.onBroadcast(event: NetEvent.state.name),
      (json) => onPlayerState?.call(PlayerStatePayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.launch.name),
      (json) => onLaunch?.call(LaunchPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.hit.name),
      (json) => onHit?.call(HitPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.matchStart.name),
      (json) => onMatchStart?.call(MatchStartPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.joinRequest.name),
      (json) => onJoinRequest?.call(JoinRequestPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.matchSnapshot.name),
      (json) => onMatchSnapshot?.call(MatchSnapshotPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.kick.name),
      (json) => onKick?.call(KickPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.swing.name),
      (json) => onSwing?.call(SwingPayload.fromJson(json)),
    );
    _subscriptions.add(channel.onPresenceSync.listen((_) => _emitRoster()));
    _subscriptions.add(channel.onPresenceJoin.listen((_) => _emitRoster()));
    _subscriptions.add(
      channel.onPresenceLeave.listen((leave) {
        final remainingIds = <String>{
          for (final state in channel.presenceState())
            for (final presence in state.presences)
              if (presence.payload['id'] is String)
                presence.payload['id'] as String,
        };
        for (final presence in leave.leftPresences) {
          final id = presence.payload['id'] as String?;
          if (id != null && id != myId && !remainingIds.contains(id)) {
            onPeerLeft?.call(id);
          }
        }
        _emitRoster();
      }),
    );
    _subscriptions.add(
      channel.onStatusChange.listen((change) async {
        if (change.status == RealtimeSubscribeStatus.subscribed) {
          connected.value = true;
          final me = _me;
          if (me != null) {
            await channel.track(me.toJson());
          }
        } else if (change.status == RealtimeSubscribeStatus.channelError ||
            change.status == RealtimeSubscribeStatus.closed) {
          connected.value = false;
          _scheduleReconnect();
        }
      }),
    );
    channel.subscribe();
  }

  void _listen(
    Stream<Map<String, dynamic>> stream,
    void Function(Map<String, dynamic> json) handler,
  ) {
    _subscriptions.add(
      stream.listen((json) {
        if (json['id'] == myId) {
          return;
        }
        handler(json);
      }),
    );
  }

  void _scheduleReconnect() {
    if (_disposed) {
      return;
    }
    final me = _me;
    if (me == null) {
      return;
    }
    Timer(const Duration(seconds: 2), () async {
      if (_disposed) {
        return;
      }
      await _teardownChannel();
      await connect(me);
    });
  }

  void send(NetEvent event, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    unawaited(
      channel.sendBroadcastMessage(event: event.name, payload: payload),
    );
  }

  Future<void> updatePresence(LobbyPresence me) async {
    _me = me;
    await _channel?.track(me.toJson());
  }

  void _emitRoster() {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final byId = <String, LobbyPresence>{};
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final json = presence.payload;
        if (LobbyPresence.isValid(json)) {
          final member = LobbyPresence.fromJson(json);
          byId[member.id] = member;
        }
      }
    }
    onRosterChanged?.call(byId.values.toList());
  }

  Future<void> _teardownChannel() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _teardownChannel();
  }
}
