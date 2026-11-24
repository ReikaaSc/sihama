import 'package:material_ui/material_ui.dart';

import 'data/sihama_role.dart';

const _forest = Color(0xFF173F2D);
const _green = Color(0xFF285E4D);
const _muted = Color(0xFF68786F);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final ValueChanged<SihamaRole> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(text: SihamaRole.pelapor.demoEmail);
  final _passwordController = TextEditingController(text: 'sihama123');
  final _shopController = TextEditingController();
  SihamaRole _role = SihamaRole.pelapor;
  bool _isRegistering = false;
  bool _sampleDocumentSelected = false;

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
                      _isRegistering
                          ? 'Daftar untuk melanjutkan ke layanan SIHAMA.'
                          : 'Pilih peran dan masuk ke akun demo Anda.',
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
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
                    if (_isRegistering && _role == SihamaRole.mitraToko) ...[
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
                        onPressed: () => setState(
                          () => _sampleDocumentSelected = true,
                        ),
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
                        if (email.isEmpty || !email.contains('@')) {
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
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_isRegistering ? 'Daftar' : 'Masuk'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(
                        () => _isRegistering = !_isRegistering,
                      ),
                      child: Text(
                        _isRegistering
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                        style: const TextStyle(color: _green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mode demo: akun dan unggahan dokumen tidak dikirim ke server.',
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAuthenticated(_role);
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _forest,
      fontWeight: FontWeight.w700,
    ),
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
