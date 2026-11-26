part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _DiseaseDatabaseTab extends StatefulWidget {
  const _DiseaseDatabaseTab({required this.repository});

  final SihamaRepository repository;

  @override
  State<_DiseaseDatabaseTab> createState() => _DiseaseDatabaseTabState();
}

class _DiseaseDatabaseTabState extends State<_DiseaseDatabaseTab> {
  final _searchController = TextEditingController();
  List<DiagnosisReference> _entries = [];
  String _categoryFilter = 'Semua';
  bool _loading = true;
  Object? _loadError;
  Timer? _refreshTimer;
  bool _refreshFailed = false;
  bool _isFetchingEntries = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollEntries()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (_isFetchingEntries) return;
    _isFetchingEntries = true;
    try {
      final entries = await widget.repository.getDiagnosisReferences();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    } finally {
      _isFetchingEntries = false;
    }
  }

  Future<void> _refreshEntries() async {
    if (_isFetchingEntries) return;
    _isFetchingEntries = true;
    try {
      final entries = await widget.repository.getDiagnosisReferences();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loadError = null;
        _refreshFailed = false;
      });
    } finally {
      _isFetchingEntries = false;
    }
  }

  Future<void> _pollEntries() async {
    try {
      await _refreshEntries();
    } catch (error) {
      if (!mounted || _refreshFailed) return;
      _refreshFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembaruan basis diagnosis gagal: $error')),
      );
    }
  }

  Future<void> _editEntry([DiagnosisReference? entry]) async {
    final updated = await showDialog<DiagnosisReference>(
      context: context,
      builder: (_) => _DiagnosisReferenceDialog(entry: entry),
    );
    if (updated == null) return;
    try {
      if (entry == null) {
        await widget.repository.createDiagnosisReference(updated);
      } else {
        await widget.repository.updateDiagnosisReference(updated);
      }
      await _refreshEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry == null
                ? 'Referensi diagnosis berhasil ditambahkan.'
                : 'Referensi diagnosis berhasil diperbarui.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan referensi: $error')),
      );
    }
  }

  Future<void> _deleteEntry(DiagnosisReference entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus referensi diagnosis?'),
        content: Text('Data "${entry.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteDiagnosisReference(entry.slug);
      await _refreshEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referensi diagnosis berhasil dihapus.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus referensi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Basis data diagnosis gagal dimuat.'),
              const SizedBox(height: 8),
              Text('$_loadError', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadEntries,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final categories = _entries.map((entry) => entry.category).toSet().toList()
      ..sort();
    final entries = _entries.where((entry) {
      final matchesCategory =
          _categoryFilter == 'Semua' || entry.category == _categoryFilter;
      final searchableText = [
        entry.name,
        entry.category,
        entry.shortDescription,
        entry.firstSymptoms,
        entry.typicalCauses,
      ].join(' ').toLowerCase();
      return matchesCategory && searchableText.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Referensi penyuluh',
          title: 'Basis Data Gejala-Penyakit',
          subtitle:
              'Referensi awal cannabis dari dataset. Data dapat ditambah dan '
              'dikelola melalui basis data.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _editEntry(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah referensi'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration('Cari nama, kategori, atau gejala')
              .copyWith(
                prefixIcon: const Icon(Icons.search_rounded, color: _muted),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_entries.length} referensi tersedia',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Semua', ...categories].map((category) {
              final selected = _categoryFilter == category;
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(_diagnosisCategoryLabel(category)),
                  selected: selected,
                  onSelected: (_) => setState(() => _categoryFilter = category),
                  selectedColor: _green,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Referensi tidak ditemukan',
            message: 'Coba kata kunci atau kategori lain.',
          ),
        ...entries.map(
          (entry) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE7F2ED),
                child: Icon(
                  _diagnosisCategoryIcon(entry.category),
                  color: _green,
                ),
              ),
              title: Text(
                entry.name,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _diagnosisCategoryLabel(entry.category),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                _DiagnosisDetail(
                  label: 'Deskripsi',
                  value: entry.shortDescription,
                ),
                _DiagnosisDetail(
                  label: 'Gejala awal',
                  value: entry.firstSymptoms,
                  splitSemicolon: true,
                ),
                _DiagnosisDetail(
                  label: 'Bagian tanaman terdampak',
                  value: entry.affectedPlantParts,
                  splitSemicolon: true,
                ),
                _DiagnosisDetail(
                  label: 'Fase pertumbuhan',
                  value: entry.growthPhase,
                  splitSemicolon: true,
                ),
                _DiagnosisDetail(
                  label: 'Kemungkinan penyebab',
                  value: entry.typicalCauses,
                  splitSemicolon: true,
                ),
                _DiagnosisDetail(
                  label: 'Referensi sumber',
                  value: entry.moreInfo,
                  splitSemicolon: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _editEntry(entry),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Ubah'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteEntry(entry),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Hapus'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosisDetail extends StatelessWidget {
  const _DiagnosisDetail({
    required this.label,
    required this.value,
    this.splitSemicolon = false,
  });

  final String label;
  final String value;
  final bool splitSemicolon;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
            ..._displayItems.map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  left: splitSemicolon && _displayItems.length > 1 ? 2 : 0,
                  bottom: splitSemicolon && _displayItems.length > 1 ? 4 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (splitSemicolon && _displayItems.length > 1) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 7, right: 7),
                        child: Icon(Icons.circle, size: 5, color: _green),
                      ),
                    ],
                    Expanded(
                      child: SelectionArea(
                        child: Text(
                          item,
                          softWrap: true,
                          textAlign: TextAlign.left,
                          style: const TextStyle(color: _ink, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _displayItems =>
      splitSemicolon ? _splitSemicolonItems(value) : [value.trim()];
}

class _DiagnosisReferenceDialog extends StatefulWidget {
  const _DiagnosisReferenceDialog({this.entry});

  final DiagnosisReference? entry;

  @override
  State<_DiagnosisReferenceDialog> createState() =>
      _DiagnosisReferenceDialogState();
}

class _DiagnosisReferenceDialogState extends State<_DiagnosisReferenceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _slugController = TextEditingController(
    text: widget.entry?.slug ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.entry?.name ?? '',
  );
  late final _categoryController = TextEditingController(
    text: widget.entry?.category ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.entry?.shortDescription ?? '',
  );
  late final _affectedPartsController = TextEditingController(
    text: widget.entry?.affectedPlantParts ?? '',
  );
  late final _growthPhaseController = TextEditingController(
    text: widget.entry?.growthPhase ?? '',
  );
  late final _symptomsController = TextEditingController(
    text: widget.entry?.firstSymptoms ?? '',
  );
  late final _causesController = TextEditingController(
    text: widget.entry?.typicalCauses ?? '',
  );
  late final _moreInfoController = TextEditingController(
    text: widget.entry?.moreInfo ?? '',
  );

  @override
  void dispose() {
    _slugController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _affectedPartsController.dispose();
    _growthPhaseController.dispose();
    _symptomsController.dispose();
    _causesController.dispose();
    _moreInfoController.dispose();
    super.dispose();
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    readOnly: readOnly,
    minLines: maxLines == 1 ? null : 2,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Wajib diisi.' : null
            : null),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      DiagnosisReference(
        id: widget.entry?.id,
        slug: _slugController.text.trim(),
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        shortDescription: _descriptionController.text.trim(),
        affectedPlantParts: _affectedPartsController.text.trim(),
        growthPhase: _growthPhaseController.text.trim(),
        firstSymptoms: _symptomsController.text.trim(),
        typicalCauses: _causesController.text.trim(),
        moreInfo: _moreInfoController.text.trim(),
        symptomIds: widget.entry?.symptomIds ?? const [],
        medicineIds: widget.entry?.medicineIds ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entry == null
          ? 'Tambah referensi diagnosis'
          : 'Ubah referensi diagnosis',
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                _slugController,
                'Slug (ID unik, contoh: powdery-mildew)',
                required: true,
                readOnly: widget.entry != null,
                validator: (value) {
                  final slug = value?.trim() ?? '';
                  if (slug.isEmpty) return 'Wajib diisi.';
                  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
                    return 'Gunakan huruf kecil, angka, dan tanda hubung.';
                  }
                  return null;
                },
              ),
              _field(_nameController, 'Nama', required: true),
              _field(_categoryController, 'Kategori', required: true),
              _field(_descriptionController, 'Deskripsi', maxLines: 4),
              _field(_symptomsController, 'Gejala awal', maxLines: 4),
              _field(
                _affectedPartsController,
                'Bagian tanaman terdampak',
                maxLines: 2,
              ),
              _field(_growthPhaseController, 'Fase pertumbuhan'),
              _field(_causesController, 'Kemungkinan penyebab', maxLines: 4),
              _field(
                _moreInfoController,
                'Referensi URL (pisahkan dengan titik koma)',
                maxLines: 3,
              ),
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
      FilledButton(onPressed: _save, child: const Text('Simpan')),
    ],
  );
}

List<String> _splitSemicolonItems(String value) => value
    .split(';')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

String _formatSemicolonList(String value) {
  final items = _splitSemicolonItems(value);
  if (items.length <= 1) return items.isEmpty ? '' : items.first;
  return items.map((item) => '• $item').join('\n');
}

String _diagnosisCategoryLabel(String category) => category;

IconData _diagnosisCategoryIcon(String category) => switch (category) {
  'Hama' => Icons.pest_control_outlined,
  'Kekurangan nutrisi' || 'Kelebihan nutrisi' => Icons.eco_outlined,
  'Masalah pengairan' => Icons.water_drop_outlined,
  'Stres cahaya' => Icons.light_mode_outlined,
  _ => Icons.grass_rounded,
};
