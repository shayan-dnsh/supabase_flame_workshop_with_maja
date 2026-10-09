// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/weapon.dart';
import 'supabase_schema.g.dart';

class WeaponService {
  WeaponService(this._client);

  final SupabaseClient _client;

  /// The tuning from the `weapons` table, so balance changes need no release.
  Future<List<Weapon>> load() async {
    final rows = await _client.table(Weapons.table).select();
    return [for (final row in rows) Weapon.fromRow(row)];
  }
}
