part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _AdviserReportScreen extends StatefulWidget {
  const _AdviserReportScreen({
    required this.report,
    required this.products,
    required this.repository,
    required this.onSave,
    required this.onOpenChat,
  });

  final CropReport report;
  final List<MarketProduct> products;
  final SihamaRepository repository;
  final Future<bool> Function(CropReport report) onSave;
  final VoidCallback onOpenChat;

  @override
  State<_AdviserReportScreen> createState() => _AdviserReportScreenState();
}

class _AdviserReportScreenState extends State<_AdviserReportScreen> {
  late String? _diagnosis = widget.report.diagnosis;
  late final TextEditingController _recommendationController =
      TextEditingController(text: widget.report.recommendation ?? '');
  late CropReport _report = widget.report;
  late List<MarketProduct> _products = widget.products;
  List<DiagnosisReference> _diagnosisReferences = [];
  bool _loadingDiagnosisReferences = true;
  Object? _diagnosisLoadError;
  final Set<int> _selectedProductIds = {};
  bool _saving = false;
  bool _isRefreshingData = false;
  bool _refreshFailed = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDiagnosisReferences();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshReviewData()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _recommendationController.dispose();
    super.dispose();
  }

  DiagnosisReference? get _selectedDiagnosisReference {
    for (final reference in _diagnosisReferences) {
      if (reference.name == _diagnosis) return reference;
    }
    return null;
  }

  Future<void> _openDiagnosisPicker() async {
    final selected = await showModalBottomSheet<DiagnosisReference>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DiagnosisPickerSheet(
        references: _diagnosisReferences,
        selectedSlug: _selectedDiagnosisReference?.slug,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _diagnosis = selected.name;
      _selectedProductIds
        ..clear()
        ..addAll(selected.medicineIds);
    });
  }

  Future<void> _loadDiagnosisReferences() async {
    setState(() {
      _loadingDiagnosisReferences = true;
      _diagnosisLoadError = null;
    });
    try {
      final references = await widget.repository.getDiagnosisReferences();
      if (!mounted) return;
      setState(() {
        _diagnosisReferences = references;
        _loadingDiagnosisReferences = false;
        final selected = _selectedDiagnosisReference;
        if (selected != null) {
          _selectedProductIds
            ..clear()
            ..addAll(selected.medicineIds);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _diagnosisLoadError = error;
        _loadingDiagnosisReferences = false;
      });
    }
  }

  Future<void> _refreshReviewData() async {
    if (_isRefreshingData || _loadingDiagnosisReferences) return;
    _isRefreshingData = true;
    try {
      final references = await widget.repository.getDiagnosisReferences();
      final products = await widget.repository.getProducts();
      final reports = await widget.repository.getReports();
      if (!mounted) return;
      CropReport? latestReport;
      for (final report in reports) {
        if (report.id == _report.id) {
          latestReport = report;
          break;
        }
      }
      setState(() {
        _diagnosisReferences = references;
        _products = products;
        if (latestReport != null) _report = latestReport;
      });
      _refreshFailed = false;
    } catch (error) {
      if (!mounted || _refreshFailed) return;
      _refreshFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembaruan data laporan gagal: $error')),
      );
    } finally {
      _isRefreshingData = false;
    }
  }

  Future<void> _save() async {
    final diagnosis = _selectedDiagnosisReference;
    if (diagnosis == null || _recommendationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih diagnosis dari basis data dan isi rekomendasi.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final selectedProducts = _products
        .where(
          (product) =>
              product.id != null && _selectedProductIds.contains(product.id),
        )
        .map((product) => product.name)
        .toList();
    final recommendation = _recommendationController.text.trim();
    final completeRecommendation = selectedProducts.isEmpty
        ? recommendation
        : '$recommendation\n\nObat yang disarankan: ${selectedProducts.join(', ')}';
    try {
      final selectedMedicineIds = _selectedProductIds.toList();
      final currentMedicineIds = diagnosis.medicineIds.toSet();
      if (currentMedicineIds.length != selectedMedicineIds.length ||
          !currentMedicineIds.containsAll(selectedMedicineIds)) {
        await widget.repository.updateDiagnosisReference(
          diagnosis.copyWith(medicineIds: selectedMedicineIds),
        );
      }
      final saved = await widget.onSave(
        _report.copyWith(
          status: 'Selesai Ditinjau',
          diagnosis: diagnosis.name,
          diagnosisReferenceId: diagnosis.id,
          recommendation: completeRecommendation,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (saved) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnosis gagal disimpan: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tinjau & Diagnosis',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            '${_report.crop} · ${_formatDate(_report.date)}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_report.photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.memory(
              _report.photoBytes!,
              height: 180,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xFFD7F0D3), Color(0xFFB8DF9B)],
              ),
            ),
            child: const Icon(Icons.eco_outlined, size: 38, color: _green),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Laporan ${_report.id} · ${_report.location}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusBadge(status: _report.status),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Gejala dilaporkan',
          child: Text(
            _report.description,
            style: const TextStyle(color: _ink, height: 1.45),
          ),
        ),
        const SizedBox(height: 8),
        _SymptomChips(description: _report.description),
        const SizedBox(height: 10),
        _InsightBanner(
          text: 'Referensi ini berasal dari dataset cannabis. Cocokkan kembali dengan jenis tanaman dan hasil pemeriksaan sebelum menetapkan diagnosis.',
        ),
        const SizedBox(height: 14),
        const Text(
          'Jenis hama/penyakit',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (_loadingDiagnosisReferences)
          const LinearProgressIndicator()
        else if (_diagnosisLoadError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Referensi diagnosis gagal dimuat: $_diagnosisLoadError',
                style: const TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: _loadDiagnosisReferences,
                child: const Text('Coba muat ulang'),
              ),
            ],
          )
        else if (_diagnosisReferences.isEmpty)
          const Text('Belum ada referensi diagnosis di basis data.')
        else
          InkWell(
            key: const ValueKey('diagnosis-picker'),
            onTap: _openDiagnosisPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedDiagnosisReference == null
                      ? const Color(0xFFDCE5DE)
                      : const Color(0xFF80B98C),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFE7F2ED),
                    child: Icon(
                      _selectedDiagnosisReference == null
                          ? Icons.search_rounded
                          : _diagnosisCategoryIcon(
                              _selectedDiagnosisReference!.category,
                            ),
                      color: _green,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDiagnosisReference?.name ??
                              'Cari hama atau penyakit',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _selectedDiagnosisReference?.category ??
                              'Cari berdasarkan nama, kategori, atau gejala',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: _muted),
                ],
              ),
            ),
          ),
        if (_selectedDiagnosisReference case final reference?) ...[
          const SizedBox(height: 10),
          _DetailCard(
            title: 'Gejala awal (referensi dataset cannabis)',
            child: Text(
              _formatSemicolonList(reference.firstSymptoms),
              style: const TextStyle(color: _ink, height: 1.45),
            ),
          ),
        ] else if (_diagnosis != null &&
            !_loadingDiagnosisReferences &&
            _diagnosisLoadError == null) ...[
          const SizedBox(height: 6),
          const Text(
            'Diagnosis tersimpan sebelumnya tidak ada di dataset. Pilih diagnosis yang sesuai dari daftar.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'Rekomendasi penanganan',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _recommendationController,
          maxLines: 4,
          decoration: _inputDecoration(
            'Tulis rekomendasi yang akan diterima petani',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Rekomendasi obat',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ..._products
            .where((product) => product.stock > 0)
            .take(5)
            .map(
              (product) => CheckboxListTile(
                value:
                    product.id != null &&
                    _selectedProductIds.contains(product.id),
                onChanged: product.id == null
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selectedProductIds.add(product.id!);
                        } else {
                          _selectedProductIds.remove(product.id);
                        }
                      }),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
                activeColor: _green,
                title: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${product.category} · ${product.stock} tersedia',
                  style: const TextStyle(fontSize: 10),
                ),
                secondary: Icon(_productIcon(product.category), color: _green),
              ),
            ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.onOpenChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Chat dengan Pelapor'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Diagnosis'),
          ),
        ),
      ],
    ),
  );
}
