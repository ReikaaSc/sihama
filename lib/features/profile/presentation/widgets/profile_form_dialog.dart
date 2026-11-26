part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _ProfileFormDialog extends StatefulWidget {
  const _ProfileFormDialog({this.profile, required this.role});

  final FarmerProfile? profile;
  final SihamaRole role;

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final _regionController = TextEditingController(
    text: widget.profile?.region ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.profile?.phone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.profile?.address ?? '',
  );
  late final _certificationController = TextEditingController(
    text: widget.profile?.certification ?? '',
  );
  late final _institutionController = TextEditingController(
    text: widget.profile?.institution ?? '',
  );
  late final _shopNameController = TextEditingController(
    text: widget.profile?.shopName ?? '',
  );
  late final _legalityController = TextEditingController(
    text: widget.profile?.legality ?? '',
  );

  String get _roleLabel =>
      widget.role == SihamaRole.pelapor ? 'Petani' : widget.role.label;

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _certificationController.dispose();
    _institutionController.dispose();
    _shopNameController.dispose();
    _legalityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.profile == null ? 'Buat profil' : 'Edit profil'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nama lengkap'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _roleLabel,
                  readOnly: true,
                  decoration: _inputDecoration('Peran akun'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _regionController,
                  decoration: _inputDecoration('Kabupaten atau wilayah'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Nomor telepon'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _inputDecoration('Alamat'),
                ),
                if (widget.role == SihamaRole.penyuluh) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('profile-certification'),
                    controller: _certificationController,
                    decoration: _inputDecoration('Nomor sertifikasi'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('profile-institution'),
                    controller: _institutionController,
                    decoration: _inputDecoration('Instansi'),
                  ),
                ],
                if (widget.role == SihamaRole.mitraToko) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('profile-shop-name'),
                    controller: _shopNameController,
                    decoration: _inputDecoration('Nama toko'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('profile-legality'),
                    controller: _legalityController,
                    decoration: _inputDecoration('Legalitas usaha'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              FarmerProfile(
                id: widget.profile?.id ?? 1,
                name: _nameController.text.trim(),
                role: _roleLabel,
                region: _regionController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                certification: _certificationController.text.trim(),
                institution: _institutionController.text.trim(),
                shopName: _shopNameController.text.trim(),
                legality: _legalityController.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

String? _requiredValue(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Bagian ini wajib diisi.'
      : null;
}
