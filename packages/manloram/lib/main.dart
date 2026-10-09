import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/manloram_app.dart';
import 'src/app/session.dart';
import 'src/env.dart';
import 'src/tab_auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Right-click swings the chub instead of opening the browser menu.
    await BrowserContextMenu.disableContextMenu();
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
    authOptions: FlutterAuthClientOptions(
      asyncStorage: const TabAuthStorage(),
      storageKey: TabAuthStorage.storageKey(),
    ),
  );
  await signInIfNeeded();
  runApp(const ManLoramApp());
}
