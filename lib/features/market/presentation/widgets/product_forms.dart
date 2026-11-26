part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _ProductFormScreen extends StatefulWidget {
  const _ProductFormScreen({this.product, required this.imagePicker});

  final MarketProduct? product;
  final ReportImagePicker imagePicker;

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.product?.price.toString() ?? '',
  );
  late final _stockController = TextEditingController(
    text: widget.product?.stock.toString() ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late String _category = widget.product?.category ?? 'Fungisida';
  ReportImage? _image;

  static const _categories = [
    'Fungisida',
    'Bakterisida',
    'Insektisida',
    'Herbisida',
  ];

  @override
  void initState() {
    super.initState();
    final bytes = widget.product?.photoBytes;
    if (bytes != null) _image = ReportImage(name: 'Foto produk', bytes: bytes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await widget.imagePicker();
      if (image == null || !mounted) return;
      final error = validateReportImage(image);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(() => _image = image);
    } on ReportImagePickerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto produk gagal dibuka: $error')),
        );
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unggah foto produk terlebih dahulu.')),
      );
      return;
    }
    Navigator.of(context).pop(
      MarketProduct(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        category: _category,
        price: int.parse(_priceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
        description: _descriptionController.text.trim(),
        photoBytes: _image!.bytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 0,
      title: Text(
        widget.product == null ? 'Tambah Produk' : 'Ubah Produk',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          const _FormLabel('Nama produk'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration('Contoh: Kocide 54 WDG'),
            validator: _requiredValue,
          ),
          const SizedBox(height: 14),
          const _FormLabel('Jenis'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: _categories
                .map(
                  (category) => ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        fontSize: 10,
                        color: category == _category ? Colors.white : _ink,
                      ),
                    ),
                    selected: category == _category,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF25833E),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel('Harga (Rp)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Harga'),
                      validator: (value) {
                        final price = int.tryParse(value ?? '');
                        return price == null || price < 0
                            ? 'Masukkan harga yang valid.'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel('Stok'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Jumlah'),
                      validator: (value) {
                        final stock = int.tryParse(value ?? '');
                        return stock == null || stock < 0
                            ? 'Masukkan stok yang valid.'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _FormLabel('Deskripsi'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration(
              'Tulis kegunaan dan cara penggunaan produk',
            ),
            validator: _requiredValue,
          ),
          const SizedBox(height: 14),
          const _FormLabel('Foto produk'),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 126,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF71C883), width: 1.2),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: _green),
                        SizedBox(height: 5),
                        Text(
                          'Unggah foto produk',
                          style: TextStyle(
                            color: _green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'PNG/JPG, maks. 5 MB',
                          style: TextStyle(color: _muted, fontSize: 9),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_image!.bytes, fit: BoxFit.cover),
                    ),
            ),
          ),
          if (_image != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _pickImage,
                child: const Text('Ganti foto'),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: 46,
          child: FilledButton(
            onPressed: _save,
            child: Text(
              widget.product == null ? 'Simpan Produk' : 'Simpan Perubahan',
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.product});

  final MarketProduct? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final _priceController = TextEditingController(
    text: widget.product?.price.toString() ?? '',
  );
  late final _stockController = TextEditingController(
    text: widget.product?.stock.toString() ?? '0',
  );
  late String _category = widget.product?.category ?? 'Fungisida';

  static const _categories = [
    'Fungisida',
    'Bakterisida',
    'Insektisida',
    'Herbisida',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Tambah produk' : 'Edit produk'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Nama produk'),
                validator: _requiredValue,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _inputDecoration('Kategori'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Harga (Rupiah)'),
                validator: (value) {
                  final price = int.tryParse(value ?? '');
                  if (price == null || price < 0) {
                    return 'Masukkan harga berupa angka yang valid.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Stok'),
                validator: (value) {
                  final stock = int.tryParse(value ?? '');
                  if (stock == null || stock < 0) {
                    return 'Masukkan stok berupa bilangan nol atau lebih.';
                  }
                  return null;
                },
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              MarketProduct(
                id: widget.product?.id,
                name: _nameController.text.trim(),
                category: _category,
                price: int.parse(_priceController.text.trim()),
                stock: int.parse(_stockController.text.trim()),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
