import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sihama/features/auth/data/repositories/supabase_auth_service.dart';
import 'package:sihama/features/auth/domain/entities/sihama_role.dart';
import 'package:sihama/features/auth/presentation/screens/auth_screen.dart';
import 'package:sihama/features/auth/domain/repositories/auth_repository.dart';
import 'package:sihama/core/constants/app_assets.dart';
import 'package:sihama/features/reports/data/datasources/report_image.dart';
import 'package:sihama/features/sihama/data/repositories/supabase_sihama_repository.dart';
import 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'shared/domain/repositories/sihama_repository.dart';

class SihamaApp extends StatefulWidget {
  const SihamaApp({super.key, this.repository, this.imagePicker});

  final SihamaRepository? repository;
  final ReportImagePicker? imagePicker;

  @override
  State<SihamaApp> createState() => _SihamaAppState();
}

class _SihamaAppState extends State<SihamaApp> {
  SihamaRole? _role;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  InternetConnection? _internetConnection;
  StreamSubscription<InternetStatus>? _internetStatusSubscription;
  InternetStatus? _internetStatus;
  late final bool _onlineMode = widget.repository == null;
  late final AuthRepository? _authService = _onlineMode
      ? SupabaseAuthService(Supabase.instance.client)
      : null;
  late final SihamaRepository _repository =
      widget.repository ?? SupabaseSihamaRepository(Supabase.instance.client);
  bool _checkingSession = true;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    if (_onlineMode) {
      _internetConnection = InternetConnection.createInstance(
        checkInterval: const Duration(seconds: 5),
        useDefaultOptions: false,
        customCheckOptions: [
          InternetCheckOption(
            uri: Uri.parse(SupabaseConfig.url),
            timeout: const Duration(seconds: 4),
            responseStatusFn: (response) =>
                response.statusCode >= 200 && response.statusCode < 500,
          ),
        ],
      );
      _internetStatusSubscription = _internetConnection!.onStatusChange.listen(
        _onInternetStatusChanged,
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Status koneksi tidak dapat diperiksa: $error'),
              backgroundColor: Colors.deepOrange,
            ),
          );
        },
      );
      _restoreSession(showLoading: false);
    } else {
      _checkingSession = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'SIHAMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _checkingSession
          ? const _SihamaLoadingScreen()
          : _startupError != null
          ? _StartupErrorScreen(error: _startupError!, onRetry: _restoreSession)
          : _role == null
          ? AuthScreen(
              authService: _authService,
              onAuthenticated: (role) => setState(() => _role = role),
            )
          : SihamaShell(
              key: ValueKey(_role),
              repository: _repository,
              imagePicker: widget.imagePicker,
              role: _role!,
              userName: _authService?.currentName,
              userEmail: _authService?.currentEmail,
              onDeleteAccount: _deleteAccount,
              onLogout: _logout,
            ),
    );
  }

  void _onInternetStatusChanged(InternetStatus status) {
    if (!mounted || status == _internetStatus) return;
    setState(() => _internetStatus = status);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isConnected = status == InternetStatus.connected;
      _scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done_outlined : Icons.cloud_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected ? 'Terhubung ke layanan SIHAMA.' : 'SIHAMA tidak dapat dijangkau. Periksa koneksi internet.',
                  ),
                ),
              ],
            ),
            backgroundColor: isConnected
                ? const Color(0xFF285E4D)
                : const Color(0xFF9B4038),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });
  }

  Future<void> _restoreSession({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _checkingSession = true;
        _startupError = null;
      });
    }
    try {
      final role = await _authService!.currentRole();
      if (!mounted) return;
      setState(() {
        _role = role;
        _checkingSession = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _checkingSession = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService?.signOut();
    _clearCachedMedia();
    if (mounted) setState(() => _role = null);
  }

  Future<void> _deleteAccount(String password) async {
    final authService = _authService;
    if (authService == null) {
      throw StateError('Penghapusan akun daring tidak tersedia.');
    }
    await authService.deleteCurrentAccount(password);
    _clearCachedMedia();
    if (mounted) setState(() => _role = null);
  }

  void _clearCachedMedia() {
    final repository = _repository;
    if (repository is SupabaseSihamaRepository) {
      repository.clearCachedMedia();
    }
  }

  @override
  void dispose() {
    unawaited(_internetStatusSubscription?.cancel());
    unawaited(_internetConnection?.dispose());
    super.dispose();
  }
}

class _SihamaLoadingScreen extends StatelessWidget {
  const _SihamaLoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F7F4),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.logo,
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text(
              'SIHAMA',
              style: TextStyle(
                color: Color(0xFF173F2D),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF285E4D),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Menyiapkan aplikasi...',
              style: TextStyle(color: Color(0xFF68786F)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Tidak dapat memuat sesi SIHAMA',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    ),
  );
}
