import 'package:sihama/features/auth/domain/entities/auth_submission_result.dart';
import 'package:sihama/features/auth/domain/entities/sihama_role.dart';

abstract interface class AuthRepository {
  String? get currentEmail;
  String? get currentName;

  Future<AuthSubmissionResult> submit({
    required bool registering,
    required String name,
    required String email,
    required String password,
  });

  Future<SihamaRole?> currentRole();
  Future<void> signOut();
  Future<void> deleteCurrentAccount(String password);
}
