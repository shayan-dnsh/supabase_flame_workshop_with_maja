import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'tab_auth_storage_stub.dart'
    if (dart.library.js_interop) 'tab_auth_storage_web.dart'
    as storage;

/// Keeps the session in the browser tab's `sessionStorage`, so every tab is
/// its own player: open a second tab to play against yourself. A reload keeps
/// the player; closing the tab ends it.
class TabAuthStorage extends AuthAsyncStorage {
  const TabAuthStorage();

  static const _tabIdKey = 'manloram-tab-id';

  /// A storage key of this tab's own. Supabase syncs sign-ins between tabs
  /// over a channel named after the key, so a shared key would let one tab's
  /// new player take over every other tab.
  static String storageKey() {
    var tabId = storage.getItem(_tabIdKey);
    if (tabId == null) {
      final random = Random.secure();
      tabId = [
        for (var i = 0; i < 12; i++) random.nextInt(36).toRadixString(36),
      ].join();
      storage.setItem(_tabIdKey, tabId);
    }
    return 'manloram-auth-$tabId';
  }

  @override
  Future<String?> getItem(String key) async => storage.getItem(key);

  @override
  Future<void> setItem(String key, String value) async =>
      storage.setItem(key, value);

  @override
  Future<void> removeItem(String key) async => storage.removeItem(key);
}
