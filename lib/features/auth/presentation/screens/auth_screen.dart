import 'package:material_ui/material_ui.dart';

import 'package:sihama/core/constants/app_assets.dart';
import 'package:sihama/features/auth/domain/entities/auth_submission_result.dart';
import 'package:sihama/features/auth/domain/entities/sihama_role.dart';
import 'package:sihama/features/auth/domain/repositories/auth_repository.dart';

const _forest = Color(0xFF173F2D);
const _green = Color(0xFF285E4D);
const _muted = Color(0xFF68786F);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.authService,
  });

  final ValueChanged<SihamaRole> onAuthenticated;
  final AuthRepository? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopController = TextEditingController();
  SihamaRole _role = SihamaRole.pelapor;
  bool _isRegistering = false;
  bool _sampleDocumentSelected = false;
  bool _isSubmitting = false;

  bool get _onlineMode => widget.authService != null;

  @override
  void initState() {
    super.initState();
    if (!_onlineMode) {
      _emailController.text = SihamaRole.pelapor.demoEmail;
      _passwordController.text = 'sihama123';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Buat akun SIHAMA' : 'Selamat datang';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        AppAssets.logo,
                        width: 124,
                        height: 124,
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo SIHAMA',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: _forest,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _onlineMode
                          ? _isRegistering
                                ? 'Buat akun Pelapor untuk menggunakan layanan SIHAMA.'
                                : 'Masuk menggunakan akun SIHAMA Anda.'
                          : _isRegistering
                          ? 'Daftar untuk melanjutkan ke layanan SIHAMA.'
                          : 'Pilih peran dan masuk ke akun demo Anda.',
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (!_onlineMode) ...[
                      const Text(
                        'Masuk sebagai',
                        style: TextStyle(
                          color: _forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SihamaRole.values.map((role) {
                          final selected = _role == role;
                          return ChoiceChip(
                            label: Text(role.label),
                            selected: selected,
                            onSelected: (_) => _selectRole(role),
                            selectedColor: const Color(0xFFDCEDE4),
                            labelStyle: TextStyle(
                              color: selected ? _forest : _muted,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFB8D5C4)
                                  : const Color(0xFFE2E8E3),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (_isRegistering) ...[
                      const SizedBox(height: 18),
                      _fieldLabel('Nama lengkap'),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _nameController,
                        decoration: _decoration('Nama Anda'),
                        validator: _required,
                      ),
                    ],
                    if (_isRegistering &&
                        !_onlineMode &&
                        _role == SihamaRole.mitraToko) ...[
                      const SizedBox(height: 15),
                      _fieldLabel('Nama toko'),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _shopController,
                        decoration: _decoration('Contoh: Toko Tani Makmur'),
                        validator: _required,
                      ),
                      const SizedBox(height: 15),
                      _fieldLabel('Dokumen usaha (NIB/SIUP)'),
                      const SizedBox(height: 7),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _sampleDocumentSelected = true),
                        icon: Icon(
                          _sampleDocumentSelected
                              ? Icons.check_circle_outline
                              : Icons.upload_file_outlined,
                        ),
                        label: Text(
                          _sampleDocumentSelected
                              ? 'Dokumen contoh dipilih'
                              : 'Pilih dokumen contoh',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _fieldLabel('Email'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('nama@email.com').copyWith(
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Masukkan alamat email yang valid.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _fieldLabel('Kata sandi'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _decoration('Kata sandi').copyWith(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) => (value ?? '').length < 6
                          ? 'Kata sandi minimal 6 karakter.'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isRegistering ? 'Daftar' : 'Masuk'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isRegistering = !_isRegistering),
                      child: Text(
                        _isRegistering
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                        style: const TextStyle(color: _green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _onlineMode
                          ? 'Pendaftaran mandiri hanya untuk Pelapor. Akun Penyuluh dan Mitra Toko dibuat oleh admin.'
                          : 'Mode demo: akun dan unggahan dokumen tidak dikirim ke server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectRole(SihamaRole role) {
    setState(() {
      _role = role;
      _emailController.text = role.demoEmail;
      _sampleDocumentSelected = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final service = widget.authService;
    if (service == null) {
      widget.onAuthenticated(_role);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await service.submit(
        registering: _isRegistering,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final role = result.role;
      if (role != null) {
        widget.onAuthenticated(role);
      } else if (result.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message!)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_authenticationErrorMessage(error)),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(color: _forest, fontWeight: FontWeight.w700),
  );
}

InputDecoration _decoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  prefixIconColor: _muted,
  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE0E7E1)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE0E7E1)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: _green, width: 1.5),
  ),
);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

String _authenticationErrorMessage(Object error) {
  if (error is AuthFailure) {
    final code = error.code?.toLowerCase();
    final detail = error.message.toLowerCase();
    if (error.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return 'Batas permintaan pendaftaran atau email tercapai. Tunggu sebelum mencoba lagi; jika berlanjut, atur SMTP khusus di Supabase.';
    }
    if (code == 'email_address_invalid' ||
        detail.contains('invalid email') ||
        detail.contains('email address is invalid')) {
      return 'Alamat email tidak valid. Periksa format dan gunakan email yang dapat menerima pesan konfirmasi.';
    }
    if (code == 'email_exists' || code == 'user_already_exists') {
      return 'Email ini sudah terdaftar. Silakan masuk atau gunakan fitur pemulihan kata sandi.';
    }
    return 'Autentikasi gagal: ${error.message}';
  }
  return 'Autentikasi gagal: $error';
}
