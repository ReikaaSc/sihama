import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SecureKeyValueStorage {
  Future<String?> read(String key);
  Future<bool> containsKey(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStorage implements SecureKeyValueStorage {
  FlutterSecureKeyValueStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SupabaseSecureSessionStorage extends LocalStorage {
  SupabaseSecureSessionStorage({
    required String supabaseUrl,
    SecureKeyValueStorage? storage,
  }) : _sessionKey = _sessionKeyFor(supabaseUrl),
       _storage = storage ?? FlutterSecureKeyValueStorage();

  final String _sessionKey;
  final SecureKeyValueStorage _storage;

  @override
  Future<void> initialize() async {
    await _readAndMigrateLegacy(_sessionKey, _storage);
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(_sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(_sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(_sessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
    await _storage.delete(_sessionKey);
  }

  static String _sessionKeyFor(String supabaseUrl) {
    final uri = Uri.tryParse(supabaseUrl);
    final projectRef = uri?.host.split('.').first;
    if (projectRef == null || projectRef.isEmpty) {
      throw ArgumentError.value(supabaseUrl, 'supabaseUrl', 'Invalid URL');
    }
    return 'sb-$projectRef-auth-token';
  }
}

class SupabaseSecurePkceStorage extends GotrueAsyncStorage {
  SupabaseSecurePkceStorage({SecureKeyValueStorage? storage})
    : _storage = storage ?? FlutterSecureKeyValueStorage();

  final SecureKeyValueStorage _storage;

  @override
  Future<String?> getItem({required String key}) =>
      _readAndMigrateLegacy(key, _storage);

  @override
  Future<void> removeItem({required String key}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
    await _storage.delete(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _storage.write(key, value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}

Future<String?> _readAndMigrateLegacy(
  String key,
  SecureKeyValueStorage storage,
) async {
  final preferences = await SharedPreferences.getInstance();
  final legacyValue = preferences.getString(key);
  final secureValue = await storage.read(key);
  if (legacyValue != null) {
    if (secureValue == null) {
      await storage.write(key, legacyValue);
    }
    await preferences.remove(key);
  }
  return secureValue ?? legacyValue;
}
