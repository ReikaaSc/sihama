import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sihama/features/auth/domain/entities/auth_submission_result.dart';
import 'package:sihama/features/auth/domain/entities/sihama_role.dart';
import 'package:sihama/features/auth/domain/repositories/auth_repository.dart';

class SupabaseAuthService implements AuthRepository {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  String? get currentEmail => _client.auth.currentUser?.email;

  @override
  String? get currentName {
    final value = _client.auth.currentUser?.userMetadata?['full_name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  @override
  Future<void> deleteCurrentAccount(String password) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('Tidak ada akun email yang sedang masuk.');
    }
    if (password.trim().isEmpty) {
      throw ArgumentError.value(password, 'password', 'Wajib diisi.');
    }

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user?.id != user.id) {
      throw StateError('Verifikasi kata sandi gagal untuk akun ini.');
    }

    await _client.rpc('delete_current_account');
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  @override
  Future<AuthSubmissionResult> submit({
    required bool registering,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      if (registering) {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name.trim()},
        );
        if (response.session == null) {
          return const AuthSubmissionResult(
            message: 'Akun berhasil dibuat. Periksa email untuk mengonfirmasi akun, lalu masuk.',
          );
        }
      } else {
        await _client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      throw AuthFailure(
        message: error.message,
        code: error.code,
        statusCode: error.statusCode,
      );
    }

    return AuthSubmissionResult(role: await currentRole());
  }

  @override
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

  @override
  Future<void> signOut() => _client.auth.signOut();
}
