import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs this tab in as an anonymous player unless it already is one.
Future<void> signInIfNeeded() async {
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    return;
  }
  try {
    // An unreachable server must not keep the game from opening.
    await auth.signInAnonymously().timeout(const Duration(seconds: 6));
  } on Exception catch (error) {
    debugPrint('Anonymous sign-in failed, playing offline: $error');
  }
}

/// Leaves the current player behind, with their leaderboard entry, and signs
/// this tab in as a brand new one.
Future<void> switchToNewPlayer() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } on Exception catch (error) {
    debugPrint('Sign-out failed, starting a new player anyway: $error');
  }
  await signInIfNeeded();
}
