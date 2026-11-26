import 'package:sihama/features/auth/domain/entities/sihama_role.dart';

class AuthSubmissionResult {
  const AuthSubmissionResult({this.role, this.message});

  final SihamaRole? role;
  final String? message;
}

class AuthFailure implements Exception {
  const AuthFailure({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final String? statusCode;

  @override
  String toString() => message;
}
