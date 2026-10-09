// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/outfit.dart';
import '../game_config.dart';
import 'supabase_schema.g.dart';

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.homeCity,
    required this.colorIndex,
    this.outfit = Outfit.kolah,
  });

  factory Profile.fromRow(ProfilesRow row) {
    final (outfit, colorIndex) = parseSkin(row.skin);
    return Profile(
      id: row.id,
      username: row.username,
      homeCity: row.homeCity ?? GameConfig.homeCities.first,
      colorIndex: colorIndex,
      outfit: outfit,
    );
  }

  final String id;
  final String username;
  final String homeCity;
  final int colorIndex;
  final Outfit outfit;

  /// The `skin` column holds `outfit:colour`, such as `chogha:3`. A bare
  /// colour index is a profile saved before outfits existed.
  String get skin => '${outfit.id}:$colorIndex';

  static (Outfit, int) parseSkin(String? skin) {
    final parts = (skin ?? '').split(':');
    if (parts.length == 2) {
      return (Outfit.fromId(parts[0]), int.tryParse(parts[1]) ?? 0);
    }
    return (Outfit.kolah, int.tryParse(parts.first) ?? 0);
  }

  Profile copyWith({
    String? username,
    String? homeCity,
    int? colorIndex,
    Outfit? outfit,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      homeCity: homeCity ?? this.homeCity,
      colorIndex: colorIndex ?? this.colorIndex,
      outfit: outfit ?? this.outfit,
    );
  }
}

class ProfileService {
  ProfileService(this._client);

  static const _uniqueViolation = '23505';

  final SupabaseClient _client;
  final _random = Random();

  String? get userId => _client.auth.currentUser?.id;

  /// Loads the signed-in player's profile, creating one with a free
  /// `Lor-1234` style name on first launch. Null when offline.
  Future<Profile?> loadOrCreate() async {
    final id = userId;
    if (id == null) {
      return null;
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      final existing = await _client
          .table(Profiles.table)
          .select()
          .where(Profiles.id.eq(id))
          .maybeSingle();
      if (existing != null) {
        return Profile.fromRow(existing);
      }
      final profile = Profile(
        id: id,
        username: 'Lor-${1000 + _random.nextInt(9000)}',
        homeCity: GameConfig
            .homeCities[_random.nextInt(GameConfig.homeCities.length)],
        colorIndex: _random.nextInt(GameConfig.playerColors.length),
        outfit: Outfit.values[_random.nextInt(Outfit.values.length)],
      );
      try {
        await _client
            .table(Profiles.table)
            .insert(
              ProfilesInsert(
                id: id,
                username: profile.username,
                homeCity: profile.homeCity,
                skin: profile.skin,
              ),
            );
        return profile;
      } on PostgrestApiException catch (error) {
        // Either the name is taken, or the profile was just created
        // elsewhere; the next round reads it or tries another name.
        if (error.errorCode != _uniqueViolation) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Saves [profile] and returns an error message for the player, or null.
  Future<String?> save(Profile profile) async {
    try {
      await _client
          .table(Profiles.table)
          .update(
            ProfilesUpdate(
              username: profile.username,
              homeCity: profile.homeCity,
              skin: profile.skin,
            ),
          )
          .where(Profiles.id.eq(profile.id));
      return null;
    } on PostgrestApiException catch (error) {
      if (error.errorCode == _uniqueViolation) {
        return 'That name is taken';
      }
      return 'Names need 3 to 24 characters';
    }
  }
}
