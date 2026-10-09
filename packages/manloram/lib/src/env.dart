class Env {
  static const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');

  /// The Supabase API. Without `--dart-define=SUPABASE_URL`, the local stack
  /// on the machine that served the page: opened as
  /// `http://192.168.1.20:8799`, the game talks to `http://192.168.1.20:54621`,
  /// so a friend on the same network plays against the host's database.
  static String get supabaseUrl {
    if (_supabaseUrlDefine.isNotEmpty) {
      return _supabaseUrlDefine;
    }
    final host = Uri.base.host;
    if (!Uri.base.scheme.startsWith('http') || host.isEmpty) {
      return 'http://127.0.0.1:54621';
    }
    // An IPv6 address needs brackets in a URL: http://[2a01:...]:54621.
    return 'http://${host.contains(':') ? '[$host]' : host}:54621';
  }

  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  static const room = String.fromEnvironment('ROOM', defaultValue: 'main');
}
