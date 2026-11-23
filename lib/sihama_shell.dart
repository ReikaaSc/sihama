import 'package:material_ui/material_ui.dart';

import 'data/sihama_database.dart';
import 'data/sihama_repository.dart';
import 'data/sihama_role.dart';

const _forest = Color(0xFF25813A);
const _green = Color(0xFF1E6A30);
const _ink = Color(0xFF1B2A1F);
const _muted = Color(0xFF55645A);
const _surface = Color(0xFFF5F8F5);

class SihamaShell extends StatefulWidget {
  const SihamaShell({
    super.key,
    this.repository,
    this.role = SihamaRole.pelapor,
    this.onLogout,
  });

  final SihamaRepository? repository;
  final SihamaRole role;
  final VoidCallback? onLogout;

  @override
  State<SihamaShell> createState() => _SihamaShellState();
}

class _SihamaShellState extends State<SihamaShell> {
  int _selectedIndex = 0;
  bool _showReportForm = false;
  late final SihamaRepository _repository =
      widget.repository ?? SihamaDatabase();
  List<CropReport> _reports = [];
  List<MarketProduct> _products = [];
  FarmerProfile? _profile;
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      await _repository.initialize();
      final reports = await _repository.getReports();
      final products = await _repository.getProducts();
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _products = products;
        _profile = profile;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<bool> _runMutation(
    String successMessage,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      await _loadData(showLoading: false);
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan perubahan: $error')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loadError != null) {
      return Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.storage_rounded,
                                size: 40,
                                color: _green,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Data SIHAMA gagal dimuat.',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_loadError',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _muted),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadData,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pages = <Widget>[
      if (widget.role == SihamaRole.pelapor)
        _HomeTab(
          latestReport: _reports.isEmpty ? null : _reports.first,
          onCreateReport: () => setState(() {
            _selectedIndex = 1;
            _showReportForm = true;
          }),
          onOpenHistory: () => setState(() {
            _selectedIndex = 1;
            _showReportForm = false;
          }),
          onOpenReport: (report) => _showReportDetails(context, report),
        ),
      if (widget.role == SihamaRole.pelapor)
        _showReportForm
            ? _ReportTab(
                onCancel: () => setState(() => _showReportForm = false),
                onSubmit: (report) async {
                  final saved = await _runMutation(
                    'Laporan berhasil dikirim ke antrean penyuluh.',
                    () => _repository.createReport(report),
                  );
                  if (saved && mounted) {
                    setState(() {
                      _selectedIndex = 1;
                      _showReportForm = false;
                    });
                  }
                  return saved;
                },
              )
            : _HistoryTab(
                reports: _reports,
                onCreateReport: () => setState(() => _showReportForm = true),
                onOpenReport: (report) => _showReportDetails(context, report),
                onEdit: _editReport,
                onDelete: _deleteReport,
              ),
      if (widget.role == SihamaRole.penyuluh)
        _HistoryTab(
          reports: _reports,
          title: 'Laporan Masuk',
          subtitle: 'Tinjau laporan petani dan perbarui status pemeriksaan.',
          onOpenReport: (report) => _showReportDetails(context, report),
          onEdit: _editReport,
          onDelete: _deleteReport,
        ),
      if (widget.role == SihamaRole.penyuluh) const _DiseaseDatabaseTab(),
      if (widget.role == SihamaRole.mitraToko) const _ShopOrdersTab(),
      if (widget.role != SihamaRole.penyuluh)
        _MarketTab(
          products: _products,
          canManage: widget.role == SihamaRole.mitraToko,
          onCheckout: () => _loadData(showLoading: false),
          onCreate: _createProduct,
          onEdit: _editProduct,
          onDelete: _deleteProduct,
        ),
      _NotificationsTab(role: widget.role),
      _ProfileTab(
        profile: _profile,
        role: widget.role,
        onEdit: _editProfile,
        onDelete: _deleteProfile,
        onLogout: widget.onLogout,
        reportCount: _reports.length,
      ),
    ];

    final navigationItems = switch (widget.role) {
      SihamaRole.pelapor => _BottomNavigation.reporterItems,
      SihamaRole.penyuluh => _BottomNavigation.adviserItems,
      SihamaRole.mitraToko => _BottomNavigation.shopItems,
    };

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: _BottomNavigation(
        items: navigationItems,
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  void _showReportDetails(BuildContext context, CropReport report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${report.id}',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${report.crop} - ${report.location}',
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _StatusBadge(status: report.status),
            const SizedBox(height: 16),
            Text(report.description, style: const TextStyle(color: _muted)),
            const SizedBox(height: 10),
            Text(
              _formatDate(report.date),
              style: const TextStyle(color: _muted),
            ),
            if (report.status == 'Selesai Ditinjau') ...[
              const SizedBox(height: 18),
              const Text(
                'Rekomendasi',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ikuti arahan petugas dan pantau kondisi tanaman secara berkala.',
                style: TextStyle(color: _muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editReport(CropReport report) async {
    final updated = await showDialog<CropReport>(
      context: context,
      builder: (context) => _ReportFormDialog(report: report),
    );
    if (updated != null) {
      await _runMutation(
        'Laporan berhasil diperbarui.',
        () => _repository.updateReport(updated),
      );
    }
  }

  Future<void> _deleteReport(CropReport report) async {
    if (!await _confirmDelete(context, 'laporan ${report.id}')) return;
    await _runMutation(
      'Laporan berhasil dihapus.',
      () => _repository.deleteReport(report.id),
    );
  }

  Future<void> _createProduct() async {
    final product = await showDialog<MarketProduct>(
      context: context,
      builder: (context) => const _ProductFormDialog(),
    );
    if (product != null) {
      await _runMutation('Produk berhasil ditambahkan.', () async {
        await _repository.createProduct(product);
      });
    }
  }

  Future<void> _editProduct(MarketProduct product) async {
    final updated = await showDialog<MarketProduct>(
      context: context,
      builder: (context) => _ProductFormDialog(product: product),
    );
    if (updated != null) {
      await _runMutation(
        'Produk berhasil diperbarui.',
        () => _repository.updateProduct(updated),
      );
    }
  }

  Future<void> _deleteProduct(MarketProduct product) async {
    final id = product.id;
    if (id == null ||
        !await _confirmDelete(context, 'produk ${product.name}')) {
      return;
    }
    await _runMutation(
      'Produk berhasil dihapus.',
      () => _repository.deleteProduct(id),
    );
  }

  Future<void> _saveProfile(FarmerProfile profile) async {
    await _runMutation(
      _profile == null
          ? 'Profil berhasil dibuat.'
          : 'Profil berhasil diperbarui.',
      () => _profile == null
          ? _repository.createProfile(profile)
          : _repository.updateProfile(profile),
    );
  }

  Future<void> _editProfile() async {
    final profile = await showDialog<FarmerProfile>(
      context: context,
      builder: (context) => _ProfileFormDialog(profile: _profile),
    );
    if (profile != null) await _saveProfile(profile);
  }

  Future<void> _deleteProfile() async {
    final profile = _profile;
    if (profile == null ||
        !await _confirmDelete(context, 'profil ${profile.name}')) {
      return;
    }
    await _runMutation(
      'Profil berhasil dihapus.',
      () => _repository.deleteProfile(profile.id),
    );
  }

}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<({String label, IconData icon})> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const reporterItems = [
    (label: 'Beranda', icon: Icons.home_rounded),
    (label: 'Laporan', icon: Icons.assignment_outlined),
    (label: 'AgriMarket', icon: Icons.storefront_rounded),
    (label: 'Notifikasi', icon: Icons.notifications_none_rounded),
    (label: 'Profil', icon: Icons.person_rounded),
  ];

  static const adviserItems = [
    (label: 'Laporan Masuk', icon: Icons.assignment_outlined),
    (label: 'Basis Data', icon: Icons.storage_rounded),
    (label: 'Notifikasi', icon: Icons.notifications_none_rounded),
    (label: 'Profil', icon: Icons.person_rounded),
  ];

  static const shopItems = [
    (label: 'Pesanan', icon: Icons.receipt_long_outlined),
    (label: 'Produk', icon: Icons.inventory_2_outlined),
    (label: 'Notifikasi', icon: Icons.notifications_none_rounded),
    (label: 'Profil', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: GestureDetector(
                    onTap: () => onSelected(index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected
                            ? const Color(0xFFDDF3E1)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 21,
                            color: selected ? _green : const Color(0xFF68776D),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? _green
                                  : const Color(0xFF68776D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.latestReport,
    required this.onCreateReport,
    required this.onOpenHistory,
    required this.onOpenReport,
  });

  final CropReport? latestReport;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenHistory;
  final ValueChanged<CropReport> onOpenReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 76),
              decoration: const BoxDecoration(
                color: _forest,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat pagi,', style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 3),
                        Text('Budi Santoso', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text('Bagaimana kondisi tanaman Anda hari ini?', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Percakapan',
                    onPressed: () => _showLocalConversation(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .2),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: -8,
              child: SizedBox(
                height: 64,
                child: FilledButton.icon(
                  onPressed: onCreateReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    elevation: 2,
                    side: const BorderSide(color: Color(0xFFD7F0DA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Buat Laporan Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Laporan Terakhir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  TextButton(onPressed: onOpenHistory, child: const Text('Lihat semua')),
                ],
              ),
              const SizedBox(height: 8),
              if (latestReport == null)
                const _EmptyState(icon: Icons.assignment_outlined, title: 'Belum ada laporan', message: 'Buat laporan pertama untuk melihat perkembangannya.')
              else
                _ReportCard(report: latestReport!, onTap: () => onOpenReport(latestReport!)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE1E8E2)), borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.eco_outlined, color: _green, size: 26),
                    SizedBox(width: 12),
                    Expanded(child: Text('Pantau kondisi tanaman secara berkala dan konsultasikan gejala baru kepada penyuluh.', style: TextStyle(color: _muted, height: 1.4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showLocalConversation(BuildContext context) async {
  final controller = TextEditingController();
  final database = SihamaDatabase();
  await database.initialize();
  var messages = await database.getLocalMessages();
  if (messages.isEmpty) {
    await database.createLocalMessage(LocalMessage(
      sender: 'Penyuluh',
      body: 'Selamat pagi, Pak Budi. Ada yang bisa saya bantu terkait tanaman Anda?',
      date: DateTime.now(),
    ));
    messages = await database.getLocalMessages();
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Percakapan Penyuluh', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Pesan tersimpan lokal di perangkat ini.', style: TextStyle(color: _muted, fontSize: 12)),
              const Divider(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) => Align(
                    alignment: messages[index].sender == 'Penyuluh' ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(color: messages[index].sender == 'Penyuluh' ? const Color(0xFFEAF5EC) : _forest, borderRadius: BorderRadius.circular(14)),
                      child: Text(messages[index].body, style: TextStyle(color: messages[index].sender == 'Penyuluh' ? _ink : Colors.white)),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller, decoration: _inputDecoration('Tulis pesan'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kirim pesan',
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      await database.createLocalMessage(LocalMessage(
                        sender: 'Budi Santoso',
                        body: text,
                        date: DateTime.now(),
                      ));
                      final updated = await database.getLocalMessages();
                      setSheetState(() => messages = updated);
                      controller.clear();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(controller.dispose);
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFFB2D9B4), Color(0xFF9CC8A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.eco_rounded, color: _forest),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Asisten tanaman',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ada perubahan pada tanaman?',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Foto gejalanya dan dapatkan indikasi awal dengan mudah.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2B4B3D)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Buat Laporan Sekarang'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard();

  static const _steps = [
    'Foto & gejala',
    'Indikasi awal',
    'Tinjau penyuluh',
    'Pesan obat',
    'Pantau pesanan',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alur penanganan',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _steps.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == _steps.length - 1 ? 0 : 9,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFE7F2ED),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _steps[index],
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({
    required this.reports,
    required this.onOpenReport,
    required this.onEdit,
    required this.onDelete,
    this.title = 'Riwayat Laporan',
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
        _PageHeading(
          eyebrow: widget.title == 'Laporan Masuk'
              ? 'Antrean pemeriksaan'
              : 'Aktivitas Anda',
          title: widget.title,
          subtitle: widget.subtitle,
        ),
        if (widget.onCreateReport != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.onCreateReport,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat laporan'),
            ),
          ),
        ],
        const SizedBox(height: 18),
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
                      color: selected ? _forest : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? _forest : const Color(0xFFE1E8E2),
                      ),
                    ),
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        color: selected ? Colors.white : _ink,
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
                onDelete: () => widget.onDelete(report),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const _PrototypeNote(),
      ],
    );
  }
}

class _ReportTab extends StatefulWidget {
  const _ReportTab({required this.onSubmit, required this.onCancel});

  final Future<bool> Function(CropReport report) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _crop;
  bool _samplePhotoSelected = false;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
        children: [
          const _PageHeading(
            eyebrow: 'Asisten tanaman',
            title: 'Buat laporan',
            subtitle: 'Foto dan ceritakan gejala untuk ditinjau penyuluh.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(height: 20),
          const _FormLabel('Tanaman'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _crop,
            decoration: _inputDecoration('Pilih jenis tanaman'),
            items: const [
              DropdownMenuItem(value: 'Padi sawah', child: Text('Padi sawah')),
              DropdownMenuItem(value: 'Cabai', child: Text('Cabai')),
              DropdownMenuItem(value: 'Tomat', child: Text('Tomat')),
            ],
            validator: (value) => value == null ? 'Pilih jenis tanaman.' : null,
            onChanged: (value) => setState(() => _crop = value),
          ),
          const SizedBox(height: 16),
          const _FormLabel('Lokasi atau nama petak'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationController,
            decoration: _inputDecoration('Contoh: Petak Utara'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Masukkan lokasi tanaman.'
                : null,
          ),
          const SizedBox(height: 16),
          const _FormLabel('Ceritakan gejala'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: _inputDecoration(
              'Jelaskan perubahan yang terlihat pada tanaman',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Jelaskan gejala yang terlihat.'
                : null,
          ),
          const SizedBox(height: 16),
          const _FormLabel('Foto tanaman'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _samplePhotoSelected = !_samplePhotoSelected);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              minimumSize: const Size.fromHeight(54),
              side: const BorderSide(color: Color(0xFFD9E2DC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _samplePhotoSelected
                  ? 'Foto contoh terpilih'
                  : 'Gunakan foto contoh',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unggah JPG/PNG maks. 5 MB memerlukan layanan penyimpanan.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _forest,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Kirim laporan'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final id =
        'SIH-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 1000}';
    final saved = await widget.onSubmit(
      CropReport(
        id: id,
        crop: _crop!,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        date: now,
        status: 'Diajukan',
      ),
    );
    if (!saved || !mounted) return;
    _formKey.currentState!.reset();
    _locationController.clear();
    _descriptionController.clear();
    setState(() => _crop = null);
  }
}

class _MarketTab extends StatefulWidget {
  const _MarketTab({
    required this.products,
    required this.canManage,
    required this.onCheckout,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MarketProduct> products;
  final bool canManage;
  final VoidCallback onCheckout;
  final VoidCallback onCreate;
  final ValueChanged<MarketProduct> onEdit;
  final ValueChanged<MarketProduct> onDelete;

  @override
  State<_MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<_MarketTab> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  final Map<int, int> _cart = {};

  static const _categories = [
    'Semua',
    'Fungisida',
    'Bakterisida',
    'Insektisida',
    'Herbisida',
  ];

  @override
  Widget build(BuildContext context) {
    final visibleProducts = widget.products.where((product) {
      final matchesQuery =
          product.name.toLowerCase().contains(_searchQuery) ||
          product.category.toLowerCase().contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
    final recommendedProducts = visibleProducts
        .where((product) => product.category == 'Bakterisida')
        .toList();
    final otherProducts = visibleProducts
        .where((product) => product.category != 'Bakterisida')
        .toList();

    Widget productCard(MarketProduct product) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ProductCard(
        product: product,
        canManage: widget.canManage,
        quantity: _cart[product.id] ?? 0,
        onOrder: () => setState(() {
          if (product.id != null && (_cart[product.id] ?? 0) < product.stock) {
            _cart.update(product.id!, (value) => value + 1, ifAbsent: () => 1);
          }
        }),
        onRemove: () => setState(() {
          final id = product.id;
          if (id != null && (_cart[id] ?? 0) > 0) {
            _cart.update(id, (value) => value - 1);
          }
        }),
        onEdit: () => widget.onEdit(product),
        onDelete: () => widget.onDelete(product),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        _PageHeading(
          eyebrow: widget.canManage
              ? 'Kelola katalog toko'
              : 'Kebutuhan pertanian',
          title: widget.canManage ? 'Produk & Stok' : 'AgriMarket',
          subtitle: widget.canManage
              ? 'Atur produk, harga, dan stok Toko Tani Makmur.'
              : 'Temukan produk pilihan untuk membantu merawat tanaman.',
        ),
        if (widget.canManage) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah produk'),
            ),
          ),
        ],
        if (widget.canManage) ...[
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
            decoration: _inputDecoration('Cari produk').copyWith(
              prefixIcon: const Icon(Icons.search_rounded, color: _muted),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((category) {
                return _CategoryChip(
                  label: category,
                  selected: category == _selectedCategory,
                  onTap: () => setState(() => _selectedCategory = category),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!widget.canManage)
          const Text('Direkomendasikan', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
        if (!widget.canManage) const SizedBox(height: 8),
        if (!widget.canManage)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: _green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direkomendasikan penyuluh. Obat ini direkomendasikan untuk diagnosis Anda. Obat lain tetap tersedia di AgriMarket.',
                    style: TextStyle(color: _green, height: 1.35, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (visibleProducts.isEmpty)
          const _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Produk tidak ditemukan',
            message: 'Coba kata kunci atau kategori yang berbeda.',
          )
        else if (widget.canManage)
          ...visibleProducts.map(productCard)
        else ...[
          ...recommendedProducts.map(productCard),
          if (otherProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Obat Lainnya', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...otherProducts.map(productCard),
          ],
        ],
        if (_cart.values.any((quantity) => quantity > 0)) ...[
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _checkout,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text('Lanjutkan · ${_cart.values.fold<int>(0, (total, quantity) => total + quantity)} item'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ],
    );
  }

  Future<void> _checkout() async {
    final selected = widget.products.where((product) =>
      product.id != null && (_cart[product.id] ?? 0) > 0,
    ).toList();
    final itemCount = selected.fold<int>(0, (count, product) => count + _cart[product.id]!);
    final total = selected.fold<int>(0, (sum, product) => sum + product.price * _cart[product.id]!);
    final details = selected.map((product) => '${product.name} × ${_cart[product.id]}').join(', ');
    try {
      final database = SihamaDatabase();
      await database.initialize();
      await database.checkoutLocalOrder(LocalOrder(
        customer: 'Budi Santoso',
        products: details,
        itemCount: itemCount,
        total: total,
        date: DateTime.now(),
      ), {for (final product in selected) product.id!: _cart[product.id]!});
      if (!mounted) return;
      setState(_cart.clear);
      widget.onCheckout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan disimpan di perangkat ini.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan belum dapat disimpan: $error')),
      );
    }
  }

}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.role});

  final SihamaRole role;

  @override
  Widget build(BuildContext context) {
    final notices = switch (role) {
      SihamaRole.pelapor => const [
        (
          Icons.check_circle_outline_rounded,
          'Laporan selesai ditinjau',
          'Penyuluh telah memberikan diagnosis untuk laporan tanaman Anda.',
          'Hari ini',
        ),
        (
          Icons.local_shipping_outlined,
          'Pesanan sedang diproses',
          'Pesanan P-2201 sedang disiapkan oleh Toko Tani Makmur.',
          'Kemarin',
        ),
        (
          Icons.chat_bubble_outline_rounded,
          'Pesan dari penyuluh',
          'Penyuluh mengirimkan catatan lanjutan untuk laporan Anda.',
          '2 hari lalu',
        ),
      ],
      SihamaRole.penyuluh => const [
        (
          Icons.assignment_outlined,
          'Laporan baru masuk',
          'Ada laporan gejala tanaman baru yang menunggu pemeriksaan.',
          'Hari ini',
        ),
        (
          Icons.chat_bubble_outline_rounded,
          'Pesan dari petani',
          'Petani mengirimkan informasi tambahan pada laporan.',
          'Kemarin',
        ),
      ],
      SihamaRole.mitraToko => const [
        (
          Icons.shopping_bag_outlined,
          'Pesanan baru',
          'Pesanan P-2207 menunggu konfirmasi toko Anda.',
          'Hari ini',
        ),
        (
          Icons.inventory_2_outlined,
          'Stok produk menipis',
          'Periksa kembali jumlah stok produk yang tersedia.',
          'Kemarin',
        ),
      ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Pembaruan akun',
          title: 'Notifikasi',
          subtitle: '',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifikasi ditandai sudah dibaca.')),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 17),
            label: const Text('Tandai dibaca'),
          ),
        ),
        if (role == SihamaRole.pelapor) ...[
          const Text('Status Pesanan', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE1E8E2)), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pesanan P-2201', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)), const Text('13 Mei 2025 · 1 item', style: TextStyle(color: _muted, fontSize: 12)), const SizedBox(height: 6), Text(_formatPrice(144000), style: const TextStyle(color: _green, fontSize: 16, fontWeight: FontWeight.w700))])),
                const _StatusBadge(status: 'Diproses'),
              ],
            ),
          ),
        ],
        const Text('Pemberitahuan', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...notices.map(
          (notice) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(notice.$1, color: _green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.$2,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.$3,
                        style: const TextStyle(color: _muted, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.$4,
                        style: const TextStyle(color: _green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const _PrototypeNote(),
      ],
    );
  }
}

class _DiseaseDatabaseTab extends StatefulWidget {
  const _DiseaseDatabaseTab();

  @override
  State<_DiseaseDatabaseTab> createState() => _DiseaseDatabaseTabState();
}

class _DiseaseDatabaseTabState extends State<_DiseaseDatabaseTab> {
  final _searchController = TextEditingController();
  String _cropFilter = 'Semua';

  static const _entries = [
    (
      'Padi',
      'Hawar Daun Bakteri',
      'Daun menguning dari ujung, lalu mengering.',
      Icons.grass_rounded,
    ),
    (
      'Cabai',
      'Antraknosa',
      'Bercak cekung gelap pada buah dan batang.',
      Icons.spa_outlined,
    ),
    (
      'Tomat',
      'Layu Fusarium',
      'Daun layu bertahap dan menguning dari bawah.',
      Icons.eco_outlined,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final entries = _entries.where((entry) {
      final matchesCrop = _cropFilter == 'Semua' || entry.$1 == _cropFilter;
      final matchesQuery =
          entry.$1.toLowerCase().contains(query) ||
          entry.$2.toLowerCase().contains(query) ||
          entry.$3.toLowerCase().contains(query);
      return matchesCrop && matchesQuery;
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Referensi penyuluh',
          title: 'Basis Data Penyakit & Gejala',
          subtitle: 'Cari referensi gejala dan penyakit berdasarkan tanaman.',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration('Cari gejala atau penyakit').copyWith(
            prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['Semua', 'Padi', 'Cabai', 'Tomat']
              .map(
                (crop) => _CategoryChip(
                  label: crop,
                  selected: crop == _cropFilter,
                  onTap: () => setState(() => _cropFilter = crop),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        ...entries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE7F2ED),
                  child: Icon(entry.$4, color: _green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$1,
                        style: const TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.$2,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.$3,
                        style: const TextStyle(color: _muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const _PrototypeNote(),
      ],
    );
  }
}

class _ShopOrdersTab extends StatefulWidget {
  const _ShopOrdersTab();

  @override
  State<_ShopOrdersTab> createState() => _ShopOrdersTabState();
}

class _ShopOrdersTabState extends State<_ShopOrdersTab> {
  String _statusFilter = 'Semua';
  List<LocalOrder> _localOrders = [];

  static const _orders = [
    ('Hendra', 'P-2198', '10 Mei 2025', 'Selesai', '1 item', 'Rp 68.000'),
    ('Wahyuni', 'P-2205', '15 Mei 2025', 'Dikirim', '1 item', 'Rp 255.000'),
    ('Sutrisno', 'P-2207', '16 Mei 2025', 'Dipesan', '2 item', 'Rp 278.000'),
    (
      'Budi Santoso',
      'P-2201',
      '13 Mei 2025',
      'Diproses',
      '1 item',
      'Rp 144.000',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalOrders();
  }

  Future<void> _loadLocalOrders() async {
    try {
      final database = SihamaDatabase();
      await database.initialize();
      final orders = await database.getLocalOrders();
      if (mounted) setState(() => _localOrders = orders);
    } catch (_) {
      // Keep sample orders available if local storage is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      'Semua',
      'Dipesan',
      'Diproses',
      'Dikirim',
      'Selesai',
      'Dibatalkan',
    ];
    final combinedOrders = [
      ..._orders,
      ..._localOrders.map((order) => (
        order.customer,
        'P-${(order.id ?? 0).toString().padLeft(4, '0')}',
        _formatDate(order.date),
        order.status,
        '${order.itemCount} item',
        _formatPrice(order.total),
      )),
    ];
    final orders = _statusFilter == 'Semua'
        ? combinedOrders
        : combinedOrders.where((order) => order.$4 == _statusFilter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Toko Tani Makmur',
          title: 'Pesanan Masuk',
          subtitle: 'Pantau dan perbarui status pesanan pelanggan.',
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses
                .map(
                  (status) => _CategoryChip(
                    label: status,
                    selected: _statusFilter == status,
                    onTap: () => setState(() => _statusFilter = status),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        ...orders.map((order) {
          final localId = int.tryParse(order.$2.replaceFirst('P-', ''));
          final matchingOrders = _localOrders
              .where((candidate) => candidate.id == localId)
              .toList();
          final localOrder = matchingOrders.isEmpty ? null : matchingOrders.first;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              title: Text(
                order.$1,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text('${order.$2} · ${order.$3} · ${order.$5}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: order.$4),
                  const SizedBox(height: 5),
                  Text(
                    order.$6,
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.$2,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Pelanggan: ${order.$1}'),
                      Text('Status: ${order.$4}'),
                      Text('Jumlah: ${order.$5}'),
                      Text('Total: ${order.$6}'),
                      if (localOrder != null) ...[
                        const SizedBox(height: 10),
                        Text(localOrder.products, style: const TextStyle(color: _muted)),
                        if (localOrder.status != 'Selesai' && localOrder.status != 'Dibatalkan') ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final nextStatus = switch (localOrder!.status) {
                                  'Dipesan' => 'Diproses',
                                  'Diproses' => 'Dikirim',
                                  _ => 'Selesai',
                                };
                                await SihamaDatabase().updateLocalOrderStatus(localOrder!.id!, nextStatus);
                                if (!mounted) return;
                                Navigator.pop(context);
                                await _loadLocalOrders();
                              },
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: Text('Ubah status ke ${switch (localOrder.status) { 'Dipesan' => 'Diproses', 'Diproses' => 'Dikirim', _ => 'Selesai' }}'),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      const _PrototypeNote(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const _PrototypeNote(),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.role,
    required this.onEdit,
    required this.onDelete,
    required this.onLogout,
    required this.reportCount,
  });

  final FarmerProfile? profile;
  final SihamaRole role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLogout;
  final int reportCount;

  @override
  Widget build(BuildContext context) {
    final isReporter = role == SihamaRole.pelapor;
    final details =
        profile ??
        FarmerProfile(
          name: 'Siti Rahmawati',
          role: role.label,
          region: 'Kabupaten Bogor',
          phone: '',
          address: '',
        );
    final displayName = switch (role) {
      SihamaRole.pelapor => details.name,
      SihamaRole.penyuluh => 'Siti Rahmawati',
      SihamaRole.mitraToko => 'Toko Tani Makmur',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Akun Anda',
          title: 'Profil',
          subtitle: 'Informasi akun dan preferensi aplikasi.',
        ),
        const SizedBox(height: 18),
        if (profile == null && isReporter) ...[
          const _EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'Profil belum dibuat',
            message: 'Tambahkan data petani untuk melengkapi akun SIHAMA.',
          ),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Buat profil'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _forest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFBEE2D2),
                  child: Text(
                    _initials(displayName),
                    style: const TextStyle(
                      color: _forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReporter
                            ? 'Pelapor (Petani)'
                            : role == SihamaRole.penyuluh
                            ? 'Penyuluh - ${details.region}'
                            : 'Mitra Toko',
                        style: const TextStyle(color: Color(0xFFD4E5DA)),
                      ),
                    ],
                  ),
                ),
                if (isReporter)
                  IconButton(
                    onPressed: onEdit,
                    tooltip: 'Edit profil',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  label: 'Laporan',
                  value: '$reportCount',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileStat(
                  label: 'Pesanan',
                  value: role == SihamaRole.mitraToko ? '4' : '1',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Informasi akun',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.mail_outline_rounded,
            title: 'Email',
            subtitle: role.demoEmail,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email demo terverifikasi.')),
            ),
          ),
          if (isReporter) ...[
            _ProfileMenuTile(
              icon: Icons.phone_outlined,
              title: 'Nomor telepon',
              subtitle: details.phone.isEmpty ? 'Belum diisi' : details.phone,
              onTap: onEdit,
            ),
            _ProfileMenuTile(
              icon: Icons.location_on_outlined,
              title: 'Alamat',
              subtitle: details.address.isEmpty
                  ? 'Belum diisi'
                  : details.address,
              onTap: onEdit,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9B4038),
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: Color(0xFFE8D6D4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus profil'),
            ),
          ],
        ],
        const SizedBox(height: 22),
        const Text(
          'Pengaturan akun',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (isReporter) ...[
          _ProfileMenuTile(
            icon: Icons.person_outline_rounded,
            title: 'Informasi pribadi',
            subtitle: 'Nama, nomor telepon, dan alamat',
            onTap: onEdit,
          ),
          _ProfileMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Lokasi lahan',
            subtitle: 'Kelola lokasi pertanian Anda',
            onTap: onEdit,
          ),
        ],
        _ProfileMenuTile(
          icon: Icons.notifications_outlined,
          title: 'Notifikasi',
          subtitle: 'Pengingat dan pembaruan laporan',
          onTap: () => _showProfileMessage(context, 'Notifikasi'),
        ),
        _ProfileMenuTile(
          icon: Icons.help_outline_rounded,
          title: 'Bantuan',
          subtitle: 'Panduan menggunakan SIHAMA',
          onTap: () => _showProfileMessage(context, 'Bantuan'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onLogout == null
              ? null
              : () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Keluar dari akun?'),
                      content: const Text(
                        'Anda dapat masuk kembali menggunakan akun demo.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) onLogout!();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9B4038),
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: Color(0xFFE8D6D4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Keluar dari akun'),
        ),
        const SizedBox(height: 18),
        const _PrototypeNote(),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final CropReport report;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB9E7A1), Color(0xFF5D8D46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  size: 30,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${report.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _StatusBadge(status: report.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${report.crop} - ${report.location}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(report.date),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lihat perkembangan  >',
                      style: TextStyle(
                        fontSize: 12,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null && onDelete != null)
                PopupMenuButton<_CrudAction>(
                  tooltip: 'Aksi laporan',
                  onSelected: (action) {
                    if (action == _CrudAction.edit) {
                      onEdit!();
                    } else {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _CrudAction.edit,
                      child: Text('Edit laporan'),
                    ),
                    PopupMenuItem(
                      value: _CrudAction.delete,
                      child: Text('Hapus laporan'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'Diajukan' => (
        'Diajukan',
        const Color(0xFFFFF4D6),
        const Color(0xFF7A4B00),
      ),
      'Ditinjau' => (
        'Ditinjau',
        const Color(0xFFFFF2D8),
        const Color(0xFF93640A),
      ),
      'Selesai Ditinjau' => (
        'Selesai Ditinjau',
        const Color(0xFFDCF5E1),
        const Color(0xFF14612B),
      ),
      _ => (status, const Color(0xFFE8F7EE), const Color(0xFF1E8A5D)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canManage,
    required this.onOrder,
    required this.onRemove,
    required this.quantity,
    required this.onEdit,
    required this.onDelete,
  });

  final MarketProduct product;
  final bool canManage;
  final VoidCallback onOrder;
  final VoidCallback onRemove;
  final int quantity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final recommended = !canManage && product.category == 'Bakterisida';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: recommended ? _forest : const Color(0xFFE1E8E2),
          width: recommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A1E3C23), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFDCF5E1), borderRadius: BorderRadius.circular(99)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, size: 13, color: _green), SizedBox(width: 4), Text('Direkomendasikan', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600))]),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: _productColor(), borderRadius: BorderRadius.circular(12)),
                child: Icon(_productIcon(), size: 28, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${product.category} · Toko Tani Makmur', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(_formatPrice(product.price), style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Stok ${product.stock}', style: const TextStyle(color: _muted, fontSize: 12)),
              const Spacer(),
              if (canManage)
                PopupMenuButton<_CrudAction>(
                  tooltip: 'Aksi produk',
                  onSelected: (action) => action == _CrudAction.edit ? onEdit() : onDelete(),
                  itemBuilder: (context) => const [PopupMenuItem(value: _CrudAction.edit, child: Text('Edit produk')), PopupMenuItem(value: _CrudAction.delete, child: Text('Hapus produk'))],
                )
              else ...[
                _QuantityButton(icon: Icons.remove_rounded, onTap: quantity == 0 ? null : onRemove),
                SizedBox(width: 36, child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700))),
                _QuantityButton(icon: Icons.add_rounded, filled: true, onTap: product.stock > 0 ? onOrder : null),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      onPressed: onTap,
      tooltip: icon == Icons.add_rounded ? 'Tambah jumlah' : 'Kurangi jumlah',
      style: IconButton.styleFrom(
        backgroundColor: filled ? _forest : Colors.white,
        foregroundColor: filled ? Colors.white : _muted,
        side: filled ? BorderSide.none : const BorderSide(color: Color(0xFFE1E8E2)),
      ),
      icon: Icon(icon, size: 18),
    ),
  );
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2ED),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _green),
      ),
      title: Text(
        title,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      onTap: onTap,
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: eyebrow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _ink, fontSize: 20, height: 1.25, fontWeight: FontWeight.w800)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _ink,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF8DA79A)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _forest : Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeNote extends StatelessWidget {
  const _PrototypeNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: _muted),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Data pada prototipe ini adalah contoh fiktif.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _FieldPainter extends CustomPainter {
  const _FieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF6FA76D).withValues(alpha: 0.38);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.58, size.width, size.height * 0.42),
      paint,
    );
    paint.color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < 8; i++) {
      final y = size.height * 0.1 + i * 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y, size.width, 8),
          const Radius.circular(6),
        ),
        paint,
      );
    }
    paint.color = const Color(0xFF2C6E43).withValues(alpha: 0.22);
    final path = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width * 0.5,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _HistoryFilter {
  all('Semua'),
  inProgress('Diajukan'),
  reviewed('Selesai Ditinjau');

  const _HistoryFilter(this.label);

  final String label;
}

enum _CrudAction { edit, delete }

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF98A49D)),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE1E7E2)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE1E7E2)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: _green, width: 1.5),
  ),
);

String _formatDate(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} - $hour.$minute';
}

void _showProfileMessage(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature akan tersedia pada versi berikutnya.')),
  );
}

Future<bool> _confirmDelete(BuildContext context, String subject) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus data?'),
          content: Text('Data $subject akan dihapus permanen dari perangkat.'),
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
              child: const Text('Hapus'),
            ),
          ],
        ),
      ) ??
      false;
}

class _ReportFormDialog extends StatefulWidget {
  const _ReportFormDialog({required this.report});

  final CropReport report;

  @override
  State<_ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends State<_ReportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _locationController = TextEditingController(
    text: widget.report.location,
  );
  late final _descriptionController = TextEditingController(
    text: widget.report.description,
  );
  late String _crop = widget.report.crop;
  late String _status = widget.report.status;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit laporan'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _crop,
                  decoration: _inputDecoration('Tanaman'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Padi sawah',
                      child: Text('Padi sawah'),
                    ),
                    DropdownMenuItem(value: 'Cabai', child: Text('Cabai')),
                    DropdownMenuItem(value: 'Tomat', child: Text('Tomat')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _crop = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration('Lokasi atau nama petak'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('Gejala tanaman'),
                  validator: _requiredValue,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: _inputDecoration('Status laporan'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Diajukan',
                      child: Text('Diajukan'),
                    ),
                    DropdownMenuItem(
                      value: 'Ditinjau',
                      child: Text('Ditinjau'),
                    ),
                    DropdownMenuItem(
                      value: 'Selesai Ditinjau',
                      child: Text('Selesai Ditinjau'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              CropReport(
                id: widget.report.id,
                crop: _crop,
                location: _locationController.text.trim(),
                description: _descriptionController.text.trim(),
                date: widget.report.date,
                status: _status,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

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

class _ProfileFormDialog extends StatefulWidget {
  const _ProfileFormDialog({this.profile});

  final FarmerProfile? profile;

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final _roleController = TextEditingController(
    text: widget.profile?.role ?? 'Petani',
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

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _regionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
                  controller: _roleController,
                  decoration: _inputDecoration('Pekerjaan'),
                  validator: _requiredValue,
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
                role: _roleController.text.trim(),
                region: _regionController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
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

String _formatPrice(int price) {
  final digits = price.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write('.');
    grouped.write(digits[index]);
  }
  return 'Rp$grouped';
}

IconData _productIcon() {
  return Icons.eco_outlined;
}

Color _productColor() {
  return const Color(0xFFD7F0DA);
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
