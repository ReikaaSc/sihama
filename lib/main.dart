import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/security/supabase_secure_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SupabaseSecureSessionStorage(
        supabaseUrl: SupabaseConfig.url,
      ),
      pkceAsyncStorage: SupabaseSecurePkceStorage(),
    ),
  );
  runApp(const SihamaApp());
}
