import 'package:supabase_flutter/supabase_flutter.dart';

import 'sihama_role.dart';

class SupabaseAuthResult {
  const SupabaseAuthResult({this.role, this.message});

  final SihamaRole? role;
  final String? message;
}

class SupabaseAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  String? get currentEmail => _client.auth.currentUser?.email;

  String? get currentName {
    final value = _client.auth.currentUser?.userMetadata?['full_name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  Future<SupabaseAuthResult> submit({
    required bool registering,
    required String name,
    required String email,
    required String password,
  }) async {
    if (registering) {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name.trim()},
      );
      if (response.session == null) {
        return const SupabaseAuthResult(
          message:
              'Akun berhasil dibuat. Periksa email untuk mengonfirmasi akun, lalu masuk.',
        );
      }
    } else {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    }

    return SupabaseAuthResult(role: await currentRole());
  }

  Future<SihamaRole?> currentRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profile = await _client
        .from('farmer_profiles')
        .select('access_role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (profile == null) {
      throw StateError(
        'Profil akun belum tersedia. Jalankan SQL setup SIHAMA di Supabase.',
      );
    }
    return SihamaRole.fromAccessRole(profile['access_role'] as String);
  }

  Future<void> signOut() => _client.auth.signOut();
}
