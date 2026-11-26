part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsRemaining = 5;

  bool get _canSubmit =>
      _secondsRemaining == 0 && _passwordController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) timer.cancel();
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Langkah 2 dari 2'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penghapusan akun beserta data terkait tidak dapat dibatalkan. '
              'Masukkan kata sandi dan ketik HAPUS AKUN untuk melanjutkan.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: _inputDecoration('Kata sandi akun'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Kata sandi wajib diisi.'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmationController,
              decoration: _inputDecoration('Ketik HAPUS AKUN'),
              validator: (value) => value?.trim().toUpperCase() == 'HAPUS AKUN'
                  ? null
                  : 'Ketik HAPUS AKUN dengan tepat.',
            ),
            const SizedBox(height: 10),
            Text(
              _secondsRemaining > 0
                  ? 'Tombol penghapusan aktif dalam $_secondsRemaining detik.'
                  : 'Anda dapat mengonfirmasi penghapusan sekarang.',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _canSubmit ? _submit : null,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9B4038)),
        child: Text(
          _secondsRemaining > 0 ? 'Tunggu ${_secondsRemaining}s' : 'Hapus akun',
        ),
      ),
    ],
  );
}

Future<bool> _confirmDelete(
  BuildContext context,
  String subject, {
  String title = 'Hapus data?',
  String confirmLabel = 'Hapus',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(
            'Data $subject akan dihapus permanen dan tidak dapat dipulihkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B4038),
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
