part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({
    required this.reports,
    required this.onOpenReport,
    required this.onEdit,
    required this.onDelete,
    this.title = 'Riwayat laporan',
    this.subtitle = 'Pantau perkembangan laporan tanaman Anda.',
    this.onCreateReport,
  });

  final List<CropReport> reports;
  final ValueChanged<CropReport> onOpenReport;
  final ValueChanged<CropReport> onEdit;
  final ValueChanged<CropReport> onDelete;
  final String title;
  final String subtitle;
  final VoidCallback? onCreateReport;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports.where((report) {
      return switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.inProgress => report.status != 'Selesai Ditinjau',
        _HistoryFilter.reviewed => report.status == 'Selesai Ditinjau',
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (widget.onCreateReport != null)
              IconButton.filled(
                onPressed: widget.onCreateReport,
                style: IconButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Buat laporan',
              ),
          ],
        ),
        if (widget.subtitle.isNotEmpty && widget.title == 'Laporan Masuk')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.subtitle,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _HistoryFilter.values.map((filter) {
              final selected = filter == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _filter = filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _green : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFDCEDE4)
                            : const Color(0xFFE5E8E4),
                      ),
                    ),
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: selected ? Colors.white : _muted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          const _EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Belum ada laporan',
            message: 'Laporan dengan status ini akan muncul di sini.',
          )
        else
          ...reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                report: report,
                onTap: () => widget.onOpenReport(report),
                onEdit: () => widget.onEdit(report),
                onDelete: widget.title == 'Laporan Masuk'
                    ? null
                    : () => widget.onDelete(report),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiagnosisPickerSheet extends StatefulWidget {
  const _DiagnosisPickerSheet({
    required this.references,
    required this.selectedSlug,
  });

  final List<DiagnosisReference> references;
  final String? selectedSlug;

  @override
  State<_DiagnosisPickerSheet> createState() => _DiagnosisPickerSheetState();
}

class _DiagnosisPickerSheetState extends State<_DiagnosisPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.references
            .map((reference) => reference.category)
            .toSet()
            .toList()
          ..sort();
    final references = widget.references.where((reference) {
      final matchesCategory =
          _category == 'Semua' || reference.category == _category;
      final searchableText = [
        reference.name,
        reference.category,
        reference.firstSymptoms,
        reference.shortDescription,
      ].join(' ').toLowerCase();
      return matchesCategory && searchableText.contains(_query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih hama atau penyakit',
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cari berdasarkan nama, kategori, atau gejala awal.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('diagnosis-search'),
                controller: _searchController,
                autofocus: true,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: _inputDecoration('Ketik untuk mencari').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, color: _green),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['Semua', ...categories]
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: _category == category
                                    ? Colors.white
                                    : _ink,
                                fontSize: 11,
                              ),
                            ),
                            selected: _category == category,
                            showCheckmark: false,
                            selectedColor: _green,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _category == category
                                  ? _green
                                  : const Color(0xFFE0E8E2),
                            ),
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${references.length} hasil',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: references.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada hasil. Coba kata kunci lain.',
                          style: TextStyle(color: _muted),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: references.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (context, index) {
                          final reference = references[index];
                          final selected =
                              reference.slug == widget.selectedSlug;
                          return Material(
                            color: selected
                                ? const Color(0xFFEDF6EF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: () => Navigator.pop(context, reference),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFE7F2ED),
                                      child: Icon(
                                        _diagnosisCategoryIcon(
                                          reference.category,
                                        ),
                                        color: _green,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reference.name,
                                            style: const TextStyle(
                                              color: _ink,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            reference.category,
                                            style: const TextStyle(
                                              color: _green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatSemicolonList(
                                              reference.firstSymptoms,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _muted,
                                              height: 1.3,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: _green,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTab extends StatefulWidget {
  const _ReportTab({
    required this.imagePicker,
    required this.repository,
    required this.onSubmit,
    required this.onCancel,
  });

  final ReportImagePicker imagePicker;
  final SihamaRepository repository;
  final Future<bool> Function(CropReport report) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedSymptoms = {};
  ReportImage? _selectedImage;
  List<Symptom> _symptoms = [];
  bool _loadingSymptoms = false;
  Object? _symptomLoadError;
  bool _isSubmitting = false;
  bool _isFetchingSymptoms = false;
  late final String _reportId = 'L-${DateTime.now().microsecondsSinceEpoch}';
  Timer? _symptomRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
    _symptomRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_loadSymptoms(showLoading: false)),
    );
  }

  @override
  void dispose() {
    _symptomRefreshTimer?.cancel();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 18, 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: _isSubmitting ? null : widget.onCancel,
                  tooltip: 'Kembali',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buat Laporan',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Langkah singkat, hasil cepat',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _FormLabel('Foto tanaman'),
                    const SizedBox(width: 4),
                    Text(
                      '*wajib',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 108,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedImage != null
                            ? const Color(0xFF25833E)
                            : const Color(0xFF80C58B),
                        width: 1.2,
                      ),
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: Color(0xFF25833E),
                                size: 23,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ambil atau pilih foto',
                                style: TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'PNG/JPG/JPEG, maks. 5 MB',
                                style: TextStyle(color: _muted, fontSize: 10),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  _selectedImage!.bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const ColoredBox(
                                        color: Color(0xFFE8F1EA),
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: _green,
                                        ),
                                      ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    color: Colors.black54,
                                    child: Text(
                                      _selectedImage!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _pickImage,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF25833E),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Pilih foto dari perangkat',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (_selectedImage != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedImage = null),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9B4038),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Hapus foto',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _FormLabel('Gejala yang terlihat (opsional)'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('report-symptom-picker'),
                  readOnly: true,
                  onTap: _showSymptomPicker,
                  decoration:
                      _inputDecoration(
                        _selectedSymptoms.isEmpty
                            ? _loadingSymptoms
                                  ? 'Memuat gejala awal dari dataset...'
                                  : _symptomLoadError != null
                                  ? 'Gejala gagal dimuat'
                                  : 'Pilih gejala awal yang terlihat'
                            : '${_selectedSymptoms.length} gejala dipilih',
                      ).copyWith(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _muted,
                        ),
                        suffixIcon: _loadingSymptoms
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: _muted,
                              ),
                      ),
                ),
                if (_selectedSymptoms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedSymptoms
                        .map(
                          (symptom) => InputChip(
                            label: Text(symptom),
                            onDeleted: () => setState(
                              () => _selectedSymptoms.remove(symptom),
                            ),
                            selectedColor: const Color(0xFFE5F4E8),
                            side: const BorderSide(color: Color(0xFFDDE7DF)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                const _FormLabel('Catatan tambahan (opsional)'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('report-notes'),
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Jelaskan kondisi tanaman lainnya',
                  ),
                ),
                const SizedBox(height: 14),
                const _FormLabel('Lokasi lahan (opsional)'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('report-location'),
                  controller: _locationController,
                  decoration: _inputDecoration('Contoh: Petak Utara'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('submit-report-button'),
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25833E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      _isSubmitting ? 'Mengirim laporan...' : 'Kirim laporan',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSymptomPicker() async {
    if (_loadingSymptoms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sedang memuat referensi gejala.')),
      );
      return;
    }
    if (_symptomLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Referensi gejala gagal dimuat: $_symptomLoadError'),
          action: SnackBarAction(label: 'Coba lagi', onPressed: _loadSymptoms),
        ),
      );
      return;
    }
    final selectedSymptoms = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SymptomPickerSheet(
        symptoms: _symptoms,
        selectedSymptoms: _selectedSymptoms,
      ),
    );
    if (selectedSymptoms == null || !mounted) return;
    setState(() {
      _selectedSymptoms
        ..clear()
        ..addAll(selectedSymptoms);
    });
  }

  Future<void> _loadSymptoms({bool showLoading = true}) async {
    if (_isFetchingSymptoms) return;
    _isFetchingSymptoms = true;
    if (showLoading && mounted) {
      setState(() {
        _loadingSymptoms = true;
        _symptomLoadError = null;
      });
    }
    try {
      final symptoms = await widget.repository.getSymptoms();
      if (!mounted) return;
      setState(() {
        _symptoms = symptoms;
        _loadingSymptoms = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _symptomLoadError = error;
        _loadingSymptoms = false;
      });
    } finally {
      _isFetchingSymptoms = false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await widget.imagePicker();
      if (image == null || !mounted) return;
      final validationError = validateReportImage(image);
      if (validationError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }
      setState(() => _selectedImage = image);
    } on ReportImagePickerException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka pemilih gambar: ${error.message}'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tanaman wajib dipilih.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final notes = _descriptionController.text.trim();
    final symptomText = _selectedSymptoms.join(', ');
    final description = [
      if (symptomText.isNotEmpty) symptomText,
      if (notes.isNotEmpty) 'Catatan: $notes',
    ].join('\n');
    try {
      final saved = await widget.onSubmit(
        CropReport(
          id: _reportId,
          crop: _unspecifiedCrop,
          location: _locationController.text.trim().isEmpty
              ? 'Belum ditentukan'
              : _locationController.text.trim(),
          description: description.isEmpty
              ? 'Gejala belum dipilih.'
              : description,
          date: now,
          status: 'Diajukan',
          photoBytes: _selectedImage!.bytes,
          symptomIds: _symptoms
              .where((symptom) => _selectedSymptoms.contains(symptom.name))
              .map((symptom) => symptom.id)
              .toList(),
        ),
      );
      if (!saved || !mounted) return;
      _formKey.currentState!.reset();
      _locationController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedSymptoms.clear();
        _selectedImage = null;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _SymptomPickerSheet extends StatefulWidget {
  const _SymptomPickerSheet({
    required this.symptoms,
    required this.selectedSymptoms,
  });

  final List<Symptom> symptoms;
  final Set<String> selectedSymptoms;

  @override
  State<_SymptomPickerSheet> createState() => _SymptomPickerSheetState();
}

class _SymptomPickerSheetState extends State<_SymptomPickerSheet> {
  late final Set<String> _selectedSymptoms = Set.of(widget.selectedSymptoms);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visibleSymptoms = widget.symptoms
        .where((symptom) => symptom.name.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih gejala tanaman',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('symptom-search'),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: _inputDecoration('Cari gejala').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: visibleSymptoms.isEmpty
                    ? const Center(
                        child: Text(
                          'Gejala tidak ditemukan.',
                          style: TextStyle(color: _muted),
                        ),
                      )
                    : ListView(
                        children: visibleSymptoms.map((item) {
                          final symptom = item.name;
                          return CheckboxListTile(
                            value: _selectedSymptoms.contains(symptom),
                            title: Text(
                              symptom,
                              style: const TextStyle(color: _ink, fontSize: 13),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _green,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedSymptoms.add(symptom);
                                } else {
                                  _selectedSymptoms.remove(symptom);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, Set<String>.of(_selectedSymptoms)),
                  child: Text('Terapkan gejala (${_selectedSymptoms.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
