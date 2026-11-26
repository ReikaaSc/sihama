import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sihama/core/security/supabase_secure_session_storage.dart';

void main() {
  const sessionKey = 'sb-project-ref-auth-token';
  const projectUrl = 'https://project-ref.supabase.co';

  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates a persisted session into secure storage', () async {
    SharedPreferences.setMockInitialValues({sessionKey: 'legacy-session'});
    final secureStorage = _MemorySecureStorage();
    final storage = SupabaseSecureSessionStorage(
      supabaseUrl: projectUrl,
      storage: secureStorage,
    );

    await storage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(await storage.accessToken(), 'legacy-session');
    expect(await storage.hasAccessToken(), isTrue);
    expect(preferences.getString(sessionKey), isNull);
  });

  test('keeps secure session when migrating and removes legacy copy', () async {
    SharedPreferences.setMockInitialValues({sessionKey: 'legacy-session'});
    final secureStorage = _MemorySecureStorage()
      ..values[sessionKey] = 'secure-session';
    final storage = SupabaseSecureSessionStorage(
      supabaseUrl: projectUrl,
      storage: secureStorage,
    );

    await storage.initialize();

    final preferences = await SharedPreferences.getInstance();
    expect(await storage.accessToken(), 'secure-session');
    expect(preferences.getString(sessionKey), isNull);
  });

  test('persists and removes sessions from secure storage', () async {
    SharedPreferences.setMockInitialValues({});
    final secureStorage = _MemorySecureStorage();
    final storage = SupabaseSecureSessionStorage(
      supabaseUrl: projectUrl,
      storage: secureStorage,
    );

    await storage.persistSession('new-session');
    expect(await storage.accessToken(), 'new-session');
    expect(await storage.hasAccessToken(), isTrue);

    await storage.removePersistedSession();
    expect(await storage.accessToken(), isNull);
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('migrates PKCE verifiers into secure storage', () async {
    const verifierKey = 'supabase-auth-code-verifier';
    SharedPreferences.setMockInitialValues({verifierKey: 'legacy-verifier'});
    final secureStorage = _MemorySecureStorage();
    final storage = SupabaseSecurePkceStorage(storage: secureStorage);

    expect(await storage.getItem(key: verifierKey), 'legacy-verifier');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(verifierKey), isNull);
    expect(secureStorage.values[verifierKey], 'legacy-verifier');
  });
}

class _MemorySecureStorage implements SecureKeyValueStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
