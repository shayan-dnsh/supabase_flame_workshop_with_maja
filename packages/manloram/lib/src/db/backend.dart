import 'package:supabase_flutter/supabase_flutter.dart';

import 'match_service.dart';
import 'profile_service.dart';
import 'stats_service.dart';
import 'weapon_service.dart';

/// Everything that talks to Postgres. The game runs without it when the
/// anonymous sign-in failed; nothing is saved then.
class Backend {
  Backend(SupabaseClient client)
    : profiles = ProfileService(client),
      matches = MatchService(client),
      stats = StatsService(client),
      weapons = WeaponService(client);

  final ProfileService profiles;
  final MatchService matches;
  final StatsService stats;
  final WeaponService weapons;
}
