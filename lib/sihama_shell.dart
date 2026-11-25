import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'data/report_image.dart';
import 'data/sihama_database.dart';
import 'data/sihama_repository.dart';
import 'data/sihama_role.dart';

const _forest = Color(0xFF173F2D);
const _green = Color(0xFF285E4D);
const _ink = Color(0xFF183B2E);
const _muted = Color(0xFF5E6F68);
const _surface = Color(0xFFF3F7F4);
const _unspecifiedCrop = 'Tanaman';

class SihamaShell extends StatefulWidget {
  const SihamaShell({
    super.key,
    this.repository,
    this.imagePicker,
    this.role = SihamaRole.pelapor,
    this.userName,
    this.userEmail,
    this.onLogout,
  });

  final SihamaRepository? repository;
  final ReportImagePicker? imagePicker;
  final SihamaRole role;
  final String? userName;
  final String? userEmail;
  final Future<void> Function()? onLogout;

  @override
  State<SihamaShell> createState() => _SihamaShellState();
}

class _SihamaShellState extends State<SihamaShell> {
  int _selectedIndex = 0;
  bool _showReportForm = false;
  bool _showConversations = false;
  late final SihamaRepository _repository =
      widget.repository ?? SihamaDatabase();
  late final SihamaChatRepository _chatRepository =
      _repository is SihamaChatRepository
      ? _repository as SihamaChatRepository
      : _FallbackChatRepository();
  List<CropReport> _reports = [];
  List<MarketProduct> _products = [];
  List<MarketOrder> _orders = [];
  FarmerProfile? _profile;
  bool _loading = true;
  Object? _loadError;

  bool get _hasReviewedReport =>
      _reports.any((report) => report.status == 'Selesai Ditinjau');

  String get _currentUserName {
    final profileName = _profile?.name.trim();
    if (profileName != null &&
        profileName.isNotEmpty &&
        profileName != 'Pengguna SIHAMA') {
      return profileName;
    }
    final authName = widget.userName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    return widget.role.label;
  }

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
      final orders = await _repository.getOrders();
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _products = products;
        _orders = orders;
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
          child: Center(
            child: _loading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCEDE4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 38,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Menyiapkan akun Anda',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Memuat data dan percakapan?',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  )
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
                          'Data gagal dimuat.',
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
      );
    }

    final reviewedReports = _reports
        .where((report) => report.status == 'Selesai Ditinjau')
        .toList();
    final recommendedProducts = reviewedReports.isEmpty
        ? const <MarketProduct>[]
        : _recommendedProducts(reviewedReports.first, _products);
    final pages = <Widget>[
      if (widget.role == SihamaRole.pelapor)
        _HomeTab(
          displayName: _currentUserName,
          latestReport: _reports.isEmpty ? null : _reports.first,
          reviewedReport: reviewedReports.isEmpty
              ? null
              : reviewedReports.first,
          onCreateReport: () => setState(() {
            _selectedIndex = 1;
            _showReportForm = true;
            _showConversations = false;
          }),
          onOpenHistory: () => setState(() {
            _selectedIndex = 1;
            _showReportForm = false;
            _showConversations = false;
          }),
          onOpenReport: (report) => _showReportDetails(context, report),
          onOpenConversations: () {
            if (_reports.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Buat laporan terlebih dahulu untuk memulai chat.',
                  ),
                ),
              );
              return;
            }
            setState(() => _showConversations = true);
          },
        ),
      if (widget.role == SihamaRole.pelapor)
        _showReportForm
            ? _ReportTab(
                imagePicker: widget.imagePicker ?? pickReportImage,
                repository: _repository,
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
      if (widget.role == SihamaRole.penyuluh)
        _DiseaseDatabaseTab(repository: _repository),
      if (widget.role == SihamaRole.mitraToko)
        _ShopOrdersTab(
          orders: _orders,
          shopName: _currentUserName,
          onUpdateOrder: _updateOrder,
        ),
      if (widget.role != SihamaRole.penyuluh)
        _MarketTab(
          products: _products,
          recommendedProducts: recommendedProducts,
          profile: _profile,
          canOrder: _hasReviewedReport,
          canManage: widget.role == SihamaRole.mitraToko,
          imagePicker: widget.imagePicker ?? pickReportImage,
          onCheckout: _checkoutOrder,
          onChangeStock: _changeProductStock,
          onCreate: _createProduct,
          onEdit: _editProduct,
          onDelete: _deleteProduct,
        ),
      _NotificationsTab(
        role: widget.role,
        reports: _reports,
        orders: _orders,
        onOpenReport: (report) => _showReportDetails(context, report),
        onOpenOrder: (order) => _showOrderDetails(context, order),
      ),
      _ProfileTab(
        profile: _profile,
        role: widget.role,
        userName: _currentUserName,
        userEmail: widget.userEmail,
        onEdit: _editProfile,
        onDelete: _deleteProfile,
        onLogout: widget.onLogout,
        reportCount: _reports.length,
        orderCount: _orders.length,
      ),
    ];
    if (widget.role == SihamaRole.pelapor &&
        _selectedIndex == 0 &&
        _showConversations) {
      pages[0] = _ConversationTab(
        onBack: () => setState(() => _showConversations = false),
        report: _reports.isEmpty ? null : _reports.first,
        onOpenChat: () =>
            _openConversation(_reports.isEmpty ? null : _reports.first),
        repository: _chatRepository,
      );
    }

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
      bottomNavigationBar: _showConversations
          ? null
          : _BottomNavigation(
              items: navigationItems,
              selectedIndex: _selectedIndex,
              onSelected: (index) => setState(() => _selectedIndex = index),
            ),
    );
  }

  void _showReportDetails(BuildContext context, CropReport report) {
    final recommendedProducts = _recommendedProducts(report, _products);
    if (widget.role == SihamaRole.penyuluh) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _AdviserReportScreen(
            report: report,
            products: _products,
            repository: _repository,
            onOpenChat: () => _openConversation(report),
            onSave: (updated) => _runMutation(
              'Diagnosis laporan ${report.id} berhasil disimpan.',
              () => _repository.updateReport(updated),
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan ${report.id}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_reportTitle(report)} · ${_formatDate(report.date)}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (report.photoBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    report.photoBytes!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD7F0D3), Color(0xFFB8DF9B)],
                    ),
                  ),
                  child: const Icon(
                    Icons.eco_outlined,
                    size: 38,
                    color: _green,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatusBadge(status: report.status)),
                  Text(
                    'Pelapor: $_currentUserName',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailCard(
                title: 'Gejala dilaporkan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SymptomChips(description: report.description),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: const TextStyle(
                        color: _muted,
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _InsightBanner(
                      text: report.diagnosis == null
                          ? 'Indikasi awal: menunggu peninjauan penyuluh.'
                          : 'Diagnosis penyuluh: ${report.diagnosis}',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: report.status == 'Selesai Ditinjau'
                            ? null
                            : () {
                                Navigator.pop(context);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _editReport(report);
                                });
                              },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Ubah Gejala'),
                      ),
                    ),
                  ],
                ),
              ),
              if (report.status == 'Diajukan' ||
                  report.status == 'Ditinjau') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule_rounded, color: Color(0xFF946313)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Menunggu peninjauan penyuluh. Anda akan menerima notifikasi setelah laporan selesai ditinjau.',
                          style: TextStyle(
                            color: Color(0xFF72500E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'Diagnosis Penyuluh',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services_outlined,
                            color: _green,
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              report.diagnosis ?? 'Diagnosis belum tersedia',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.recommendation ?? 'Ikuti arahan petugas dan pantau kondisi tanaman secara berkala.',
                        style: const TextStyle(
                          color: _muted,
                          height: 1.4,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (report.status == 'Selesai Ditinjau') ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Rekomendasi Obat',
                    child: Column(
                      children: [
                        if (recommendedProducts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Belum ada obat tersedia di AgriMarket.',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ),
                          ),
                        ...recommendedProducts.map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDF0D8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _productIcon(product.category),
                                    color: _green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        product.category,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatPrice(product.price),
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() => _selectedIndex = 2);
                            },
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text('Lihat Obat & Pesan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openConversation(report),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Chat dengan Penyuluh'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, MarketOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _OrderDetailScreen(order: order)),
    );
  }

  void _openConversation([CropReport? report]) {
    final conversationReport =
        report ?? (_reports.isEmpty ? null : _reports.first);
    if (conversationReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buat laporan terlebih dahulu untuk memulai chat.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatScreen(
          repository: _chatRepository,
          role: widget.role,
          reportId: conversationReport.id,
          reportCaption:
              '${conversationReport.id} · ${_reportTitle(conversationReport)}',
          reportStatus: conversationReport.status,
          currentUserName: _currentUserName,
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
    final product = await Navigator.of(context).push<MarketProduct>(
      MaterialPageRoute<MarketProduct>(
        builder: (_) => _ProductFormScreen(
          imagePicker: widget.imagePicker ?? pickReportImage,
        ),
      ),
    );
    if (product != null) {
      await _runMutation('Produk berhasil ditambahkan.', () async {
        await _repository.createProduct(product);
      });
    }
  }

  Future<MarketOrder?> _checkoutOrder(
    List<MarketOrderItem> items,
    ReportImage paymentProof, {
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
  }) async {
    final now = DateTime.now();
    final order = MarketOrder(
      id: 'P-${now.microsecondsSinceEpoch}',
      customerName: customerName,
      date: now,
      status: 'Dipesan',
      items: items,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      transferProofBytes: paymentProof.bytes,
    );
    final saved = await _runMutation(
      'Pesanan ${order.id} berhasil dibuat.',
      () => _repository.createOrder(order),
    );
    return saved ? order : null;
  }

  Future<bool> _changeProductStock(MarketProduct product, int stock) {
    return _runMutation('Stok ${product.name} diperbarui.', () {
      return _repository.updateProduct(
        MarketProduct(
          id: product.id,
          name: product.name,
          category: product.category,
          price: product.price,
          stock: stock,
          description: product.description,
          photoBytes: product.photoBytes,
        ),
      );
    });
  }

  Future<bool> _updateOrder(MarketOrder order, String status) async {
    return _runMutation(
      'Status pesanan ${order.id} diperbarui.',
      () => _repository.updateOrder(order.copyWith(status: status)),
    );
  }

  Future<void> _editProduct(MarketProduct product) async {
    final updated = await Navigator.of(context).push<MarketProduct>(
      MaterialPageRoute<MarketProduct>(
        builder: (_) => _ProductFormScreen(
          product: product,
          imagePicker: widget.imagePicker ?? pickReportImage,
        ),
      ),
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
    final subject = profile == null ? 'akun pelapor' : 'akun ${profile.name}';
    if (!await _confirmDelete(context, subject)) return;
    final secondConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi terakhir'),
        content: const Text(
          'Akun dan profil lokal akan dihapus. Tindakan ini tidak dapat dibatalkan. Lanjutkan?',
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
            child: const Text('Ya, hapus akun'),
          ),
        ],
      ),
    );
    if (secondConfirmation != true) return;

    final deleted = profile == null
        ? true
        : await _runMutation(
            'Akun berhasil dihapus.',
            () => _repository.deleteProfile(profile.id),
          );
    if (deleted && mounted) widget.onLogout?.call();
  }

  void _openNotifications() {
    setState(() {
      _selectedIndex = switch (widget.role) {
        SihamaRole.pelapor => 3,
        SihamaRole.penyuluh || SihamaRole.mitraToko => 2,
      };
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNotifications});

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      color: _forest,
      child: Row(
        children: [
          const Text(
            'SIHAMA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onNotifications,
            tooltip: 'Notifikasi',
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
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
                            ? const Color(0xFFE7F2ED)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 21,
                            color: selected
                                ? _green
                                : const Color(0xFF6F7D74),
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
                                  : const Color(0xFF6F7D74),
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
    required this.displayName,
    required this.latestReport,
    required this.reviewedReport,
    required this.onCreateReport,
    required this.onOpenHistory,
    required this.onOpenReport,
    required this.onOpenConversations,
  });

  final String displayName;
  final CropReport? latestReport;
  final CropReport? reviewedReport;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenHistory;
  final ValueChanged<CropReport> onOpenReport;
  final VoidCallback onOpenConversations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            const SizedBox(height: 200),
            Container(
              height: 176,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 48),
              decoration: const BoxDecoration(
                color: Color(0xFF25833E),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat pagi,',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        SizedBox(height: 3),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bagaimana kondisi tanaman Anda hari ini?',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenConversations,
                    tooltip: 'Percakapan',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 0,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onCreateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF23833D),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text(
                    'Buat Laporan Sekarang',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Laporan Terakhir',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenHistory,
                    child: const Text('Lihat semua'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (latestReport == null)
                const _EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Belum ada laporan',
                  message:
                      'Buat laporan pertama untuk melihat perkembangannya.',
                )
              else
                _HomeReportCard(
                  report: latestReport!,
                  onTap: () => onOpenReport(latestReport!),
                ),
              if (reviewedReport != null) ...[
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFFE0F4E4),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => onOpenReport(reviewedReport!),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF21803D),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Laporan ${reviewedReport!.id} sudah ditinjau. Lihat rekomendasi obat.',
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: _green,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _WorkflowCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeReportCard extends StatelessWidget {
  const _HomeReportCard({required this.report, required this.onTap});

  final CropReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F0D5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.eco_outlined, color: _green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.crop == _unspecifiedCrop
                          ? report.id
                          : '${report.crop} · ${report.id}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: report.status),
                    const SizedBox(height: 4),
                    Text(
                      'Indikasi awal: ${_initialDiagnosis(report.crop)}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    Text(
                      '${report.status == 'Selesai Ditinjau' ? 'Ditinjau penyuluh' : 'Menunggu penyuluh'} · ${_formatDate(report.date).split(' - ').first}',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initialDiagnosis(String crop) => switch (crop.toLowerCase()) {
  'cabai' => 'Antraknosa',
  'tomat' => 'Layu Fusarium',
  _ => 'Hawar daun',
};

String _reportTitle(CropReport report) => report.crop == _unspecifiedCrop
    ? report.location
    : '${report.crop} - ${report.location}';

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
            'Alur Kerja SIHAMA',
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

class _ConversationTab extends StatefulWidget {
  const _ConversationTab({
    required this.onBack,
    required this.onOpenChat,
    required this.report,
    required this.repository,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final CropReport? report;
  final SihamaChatRepository repository;

  @override
  State<_ConversationTab> createState() => _ConversationTabState();
}

class _ConversationTabState extends State<_ConversationTab> {
  final _searchController = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
  }

  Future<List<ChatMessage>> _loadMessages() {
    final report = widget.report;
    return report == null
        ? Future.value(const <ChatMessage>[])
        : widget.repository.getChatMessages(report.id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final reportCaption = report == null
        ? ''
        : '${report.id} · ${_reportTitle(report)}';

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Percakapan',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Sesi chat dengan penyuluh',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ChatMessage>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessage>[];
              final latestMessage = messages.isEmpty ? null : messages.last;
              final searchText = _searchController.text.trim().toLowerCase();
              final searchableText = [
                reportCaption,
                latestMessage?.senderName ?? '',
                latestMessage?.text ?? '',
              ].join(' ').toLowerCase();
              final isVisible =
                  searchText.isEmpty || searchableText.contains(searchText);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        _inputDecoration('Cari nama, laporan, atau pesan')
                            .copyWith(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: _muted,
                              ),
                              isDense: true,
                            ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFA1241A),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Percakapan gagal dimuat: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFA1241A),
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _messagesFuture = _loadMessages(),
                            ),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    )
                  else if (report == null)
                    const _EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Belum ada percakapan',
                      message: 'Percakapan akan tersedia setelah Anda membuat laporan.',
                    )
                  else if (isVisible)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: widget.onOpenChat,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFD8F0D5),
                                child: Text(
                                  _initials(
                                    latestMessage?.senderName ?? 'Percakapan',
                                  ),
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      latestMessage?.senderName ??
                                          'Percakapan laporan',
                                      style: const TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      reportCaption,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      latestMessage?.text ?? 'Belum ada pesan. Ketuk untuk memulai percakapan.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (latestMessage != null)
                                Text(
                                  '${latestMessage.sentAt.hour.toString().padLeft(2, '0')}.${latestMessage.sentAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen({
    required this.repository,
    required this.role,
    required this.reportId,
    required this.reportCaption,
    required this.reportStatus,
    required this.currentUserName,
  });

  final SihamaChatRepository repository;
  final SihamaRole role;
  final String reportId;
  final String reportCaption;
  final String reportStatus;
  final String currentUserName;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final _controller = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;

  String get _myName => widget.currentUserName;
  String get _partnerName =>
      widget.role == SihamaRole.pelapor ? 'Penyuluh' : 'Pelapor';

  bool _isOwnMessage(ChatMessage message) =>
      message.senderRole.trim().toLowerCase() ==
          widget.role.name.toLowerCase() ||
      message.senderRole.trim().toLowerCase() ==
          widget.role.label.toLowerCase();

  @override
  void initState() {
    super.initState();
    _messagesFuture = widget.repository.getChatMessages(widget.reportId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    try {
      await widget.repository.addChatMessage(
        ChatMessage(
          reportId: widget.reportId,
          senderRole: widget.role.label,
          senderName: _myName,
          text: value,
          sentAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(
        () => _messagesFuture = widget.repository.getChatMessages(
          widget.reportId,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _controller.text = value;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pesan gagal disimpan: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFD8F0D5),
              child: Text(
                _initials(_partnerName),
                style: const TextStyle(color: _green, fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _partnerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Percakapan laporan',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reportCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        widget.reportStatus,
                        style: TextStyle(fontSize: 10, color: _green),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Ubah gejala',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <ChatMessage>[];
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (messages.isNotEmpty)
                      const Center(
                        child: Chip(
                          label: Text(
                            'Riwayat percakapan',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ...messages.map((message) {
                      final mine = _isOwnMessage(message);
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFF25833E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  message.senderName,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: mine ? Colors.white : _ink,
                                  height: 1.4,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${message.sentAt.hour.toString().padLeft(2, '0')}.${message.sentAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: mine ? Colors.white70 : _muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (snapshot.connectionState == ConnectionState.done &&
                        messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'Belum ada pesan. Mulai percakapan dengan mengirim pesan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _green,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3EAE5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: _green),
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE4EBE5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _SymptomChips extends StatelessWidget {
  const _SymptomChips({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final symptoms = description
        .split(RegExp(r'[,;\n.]'))
        .map((value) => value.trim())
        .where((value) => value.length > 2)
        .take(4)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: symptoms
          .map(
            (symptom) => Chip(
              label: Text(symptom, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFF0F5F1),
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE2F0FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFF3976A8),
          size: 15,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF315E82),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MarketCheckoutScreen extends StatefulWidget {
  const _MarketCheckoutScreen({
    required this.items,
    required this.profile,
    required this.imagePicker,
    required this.onPlaceOrder,
  });

  final List<MarketOrderItem> items;
  final FarmerProfile? profile;
  final ReportImagePicker imagePicker;
  final Future<MarketOrder?> Function({
    required ReportImage proof,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
  })
  onPlaceOrder;

  @override
  State<_MarketCheckoutScreen> createState() => _MarketCheckoutScreenState();
}

class _MarketCheckoutScreenState extends State<_MarketCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.profile?.phone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.profile?.address ?? '',
  );
  ReportImage? _proof;
  String? _proofError;
  bool _saving = false;

  int get _total => widget.items.fold(0, (total, item) => total + item.total);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Detail pesanan',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            const Text(
              'Periksa detail sebelum membuat pesanan.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Alamat pengiriman',
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('checkout-name'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Nama penerima'),
                    validator: _requiredValue,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-phone'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('Nomor telepon'),
                    validator: _requiredValue,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('checkout-address'),
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _inputDecoration('Alamat lengkap'),
                    validator: _requiredValue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Barang yang dipesan',
              child: Column(
                children: [
                  ...widget.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity} × ${_formatPrice(item.unitPrice)}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                _formatPrice(item.total),
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total harga',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _formatPrice(_total),
                        style: const TextStyle(
                          color: Color(0xFF18834A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Bukti transfer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_proof == null)
                    OutlinedButton.icon(
                      key: const ValueKey('checkout-upload-proof'),
                      onPressed: _pickProof,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Unggah bukti transfer'),
                    )
                  else
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _proof!.bytes,
                            width: 76,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _proof!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ganti bukti transfer',
                          onPressed: _pickProof,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Hapus bukti transfer',
                          onPressed: () => setState(() {
                            _proof = null;
                            _proofError = 'Bukti transfer wajib diunggah.';
                          }),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  if (_proofError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _proofError!,
                      style: const TextStyle(
                        color: Color(0xFFA1241A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'JPG atau PNG, maksimal 5 MB.',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE1E8E2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total pembayaran',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                    Text(
                      _formatPrice(_total),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('checkout-place-order'),
                onPressed: _saving ? null : _placeOrder,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Pesan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProof() async {
    try {
      final image = await widget.imagePicker();
      if (image == null || !mounted) return;
      final error = validateReportImage(image);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(() {
        _proof = image;
        _proofError = null;
      });
    } on ReportImagePickerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto bukti transfer gagal dibuka: $error')),
        );
      }
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final proof = _proof;
    if (proof == null) {
      setState(() => _proofError = 'Bukti transfer wajib diunggah.');
      return;
    }
    setState(() => _saving = true);
    try {
      final order = await widget.onPlaceOrder(
        proof: proof,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
      );
      if (order != null && mounted) Navigator.pop(context, order);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OrderDetailScreen extends StatelessWidget {
  const _OrderDetailScreen({required this.order});
  final MarketOrder order;

  @override
  Widget build(BuildContext context) {
    final steps = ['Dipesan', 'Diproses', 'Dikirim', 'Selesai'];
    final active = steps.indexOf(order.status).clamp(0, steps.length - 1);
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan ${order.id}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'Mitra Toko · ${_formatDate(order.date)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const Text(
            'Status',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EBE5)),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _StatusBadge(status: order.status),
                ),
                const SizedBox(height: 8),
                ...List.generate(steps.length, (index) {
                  final reached = index <= active;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: reached
                                    ? const Color(0xFF2A9148)
                                    : const Color(0xFFE4EBE5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                index < active
                                    ? Icons.check_rounded
                                    : Icons.circle,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                            if (index < steps.length - 1)
                              Container(
                                width: 2,
                                height: 28,
                                color: index < active
                                    ? const Color(0xFF2A9148)
                                    : const Color(0xFFE4EBE5),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          steps[index],
                          style: TextStyle(
                            color: reached ? _ink : _muted,
                            fontSize: 12,
                            fontWeight: index == active
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Rincian pesanan',
            child: Column(
              children: [
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} × ${_formatPrice(item.unitPrice)}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              _formatPrice(item.total),
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatPrice(order.total),
                      style: const TextStyle(
                        color: Color(0xFF18834A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Penerima & alamat pengiriman',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  order.customerPhone.isEmpty
                      ? 'Kontak belum diisi'
                      : order.customerPhone,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 8),
                Text(
                  order.deliveryAddress.isEmpty
                      ? 'Alamat belum diisi'
                      : order.deliveryAddress,
                  style: const TextStyle(color: _ink, height: 1.4),
                ),
              ],
            ),
          ),
          if (order.transferProofBytes != null) ...[
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Bukti transfer',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  order.transferProofBytes!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
  List<DiagnosisReference> _diagnosisReferences = [];
  bool _loadingDiagnosisReferences = true;
  Object? _diagnosisLoadError;
  final Set<int> _selectedProductIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnosisReferences();
  }

  @override
  void dispose() {
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
    setState(() => _diagnosis = selected.name);
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _diagnosisLoadError = error;
        _loadingDiagnosisReferences = false;
      });
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
    final selectedProducts = widget.products
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
    final saved = await widget.onSave(
      widget.report.copyWith(
        status: 'Selesai Ditinjau',
        diagnosis: diagnosis.name,
        recommendation: completeRecommendation,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
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
            '${widget.report.crop} · ${_formatDate(widget.report.date)}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (widget.report.photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.memory(
              widget.report.photoBytes!,
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
                'Laporan ${widget.report.id} · ${widget.report.location}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusBadge(status: widget.report.status),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Gejala dilaporkan',
          child: Text(
            widget.report.description,
            style: const TextStyle(color: _ink, height: 1.45),
          ),
        ),
        const SizedBox(height: 8),
        _SymptomChips(description: widget.report.description),
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
        ...widget.products
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
                onDelete: null,
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
  List<DiagnosisReference> _symptomReferences = [];
  bool _loadingSymptoms = true;
  Object? _symptomLoadError;

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
  }

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
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 18, 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onCancel,
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
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25833E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Kirim laporan'),
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
        references: _symptomReferences,
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

  Future<void> _loadSymptoms() async {
    setState(() {
      _loadingSymptoms = true;
      _symptomLoadError = null;
    });
    try {
      final references = await widget.repository.getDiagnosisReferences();
      if (!mounted) return;
      setState(() {
        _symptomReferences = references
            .where((reference) => reference.firstSymptoms.trim().isNotEmpty)
            .toList();
        _loadingSymptoms = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _symptomLoadError = error;
        _loadingSymptoms = false;
      });
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
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tanaman wajib dipilih.')),
      );
      return;
    }

    final now = DateTime.now();
    final id = 'L-${now.millisecondsSinceEpoch % 10000 + 1000}';
    final notes = _descriptionController.text.trim();
    final symptomText = _selectedSymptoms.join(', ');
    final description = [
      if (symptomText.isNotEmpty) symptomText,
      if (notes.isNotEmpty) 'Catatan: $notes',
    ].join('\n');
    final saved = await widget.onSubmit(
      CropReport(
        id: id,
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
  }
}

class _SymptomPickerSheet extends StatefulWidget {
  const _SymptomPickerSheet({
    required this.references,
    required this.selectedSymptoms,
  });

  final List<DiagnosisReference> references;
  final Set<String> selectedSymptoms;

  @override
  State<_SymptomPickerSheet> createState() => _SymptomPickerSheetState();
}

class _SymptomPickerSheetState extends State<_SymptomPickerSheet> {
  late final Set<String> _selectedSymptoms = Set.of(widget.selectedSymptoms);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visibleSymptoms = widget.references
        .expand(
          (reference) => _splitSemicolonItems(reference.firstSymptoms)
              .where(
                (symptom) => [
                  reference.name,
                  reference.category,
                  symptom,
                ].join(' ').toLowerCase().contains(_query),
              )
              .map((symptom) => (reference: reference, symptom: symptom)),
        )
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
                          final reference = item.reference;
                          final symptom = item.symptom;
                          return CheckboxListTile(
                            value: _selectedSymptoms.contains(symptom),
                            title: Text(
                              symptom,
                              style: const TextStyle(color: _ink, fontSize: 13),
                            ),
                            subtitle: Text(
                              '${reference.name} · ${reference.category}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
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

class _MarketTab extends StatefulWidget {
  const _MarketTab({
    required this.products,
    required this.recommendedProducts,
    required this.profile,
    required this.canOrder,
    required this.canManage,
    required this.imagePicker,
    required this.onCheckout,
    required this.onChangeStock,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MarketProduct> products;
  final List<MarketProduct> recommendedProducts;
  final FarmerProfile? profile;
  final bool canOrder;
  final bool canManage;
  final ReportImagePicker imagePicker;
  final Future<MarketOrder?> Function(
    List<MarketOrderItem> items,
    ReportImage proof, {
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
  })
  onCheckout;
  final Future<bool> Function(MarketProduct product, int stock) onChangeStock;
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
    final recommendedProducts = visibleProducts.where((product) {
      return widget.recommendedProducts.any(
        (recommended) => recommended.id != null && recommended.id == product.id,
      );
    }).toList();
    final recommendedKeys = recommendedProducts
        .map((product) => product.id ?? product.name)
        .toSet();
    final otherProducts = visibleProducts
        .where(
          (product) => !recommendedKeys.contains(product.id ?? product.name),
        )
        .toList();
    final cartItems = _cartItems();
    final cartTotal = cartItems.fold(0, (total, item) => total + item.total);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.canManage ? 'Produk & Stok' : 'AgriMarket',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.canManage
                              ? 'Atur produk, harga, dan stok toko.'
                              : 'Obat pertanian dari toko mitra',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (widget.canManage)
                    FilledButton.icon(
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah produk'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: _inputDecoration('Cari produk').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              if (!widget.canOrder)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: _green, size: 17),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Pemesanan akan tersedia setelah laporan tanaman selesai ditinjau.',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!widget.canManage && recommendedProducts.isNotEmpty) ...[
                const _MarketSectionHeading(title: 'Direkomendasikan'),
                const SizedBox(height: 8),
                const _MarketRecommendationNote(),
                const SizedBox(height: 12),
                ...recommendedProducts.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductCard(
                      product: product,
                      canOrder: widget.canOrder,
                      canManage: false,
                      isRecommended: true,
                      showRecommendationBadge: true,
                      quantity: _cart[product.id] ?? 0,
                      onOrder: () => _addToCart(product),
                      onRemoveFromCart: () => _removeFromCart(product),
                      onChangeStock: (stock) =>
                          widget.onChangeStock(product, stock),
                      onEdit: () => widget.onEdit(product),
                      onDelete: () => widget.onDelete(product),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (visibleProducts.isEmpty)
                const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Produk tidak ditemukan',
                  message: 'Coba kata kunci atau kategori yang berbeda.',
                )
              else if (otherProducts.isNotEmpty) ...[
                _MarketSectionHeading(
                  title: widget.canManage
                      ? 'Produk Toko'
                      : recommendedProducts.isNotEmpty
                      ? 'Obat Lainnya'
                      : 'Produk Tersedia',
                ),
                if (!widget.canManage && recommendedProducts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Produk lain tetap tersedia, tetapi tidak direkomendasikan untuk diagnosis ini.',
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                  ),
                ],
                const SizedBox(height: 10),
                ...otherProducts.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProductCard(
                      product: product,
                      canOrder: widget.canOrder,
                      canManage: widget.canManage,
                      isRecommended: false,
                      showRecommendationBadge:
                          !widget.canManage &&
                          widget.recommendedProducts.isNotEmpty,
                      quantity: _cart[product.id] ?? 0,
                      onOrder: () => _addToCart(product),
                      onRemoveFromCart: () => _removeFromCart(product),
                      onChangeStock: (stock) =>
                          widget.onChangeStock(product, stock),
                      onEdit: () => widget.onEdit(product),
                      onDelete: () => widget.onDelete(product),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!widget.canManage)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F8F5),
              border: Border(top: BorderSide(color: Color(0xFFE1E8E2))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total keranjang',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatPrice(cartTotal),
                        style: const TextStyle(
                          color: Color(0xFF1E6A30),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.canOrder && cartItems.isNotEmpty
                        ? _checkout
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded),
                    label: Text(
                      cartItems.isEmpty
                          ? 'Keranjang kosong'
                          : 'Lanjutkan pesanan (${cartItems.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<MarketOrderItem> _cartItems() {
    return widget.products
        .where((product) => product.id != null && _cart.containsKey(product.id))
        .map(
          (product) => MarketOrderItem(
            productId: product.id!,
            productName: product.name,
            quantity: _cart[product.id]!,
            unitPrice: product.price,
          ),
        )
        .toList();
  }

  void _addToCart(MarketProduct product) {
    if (!widget.canOrder) {
      _showOrderUnavailable();
      return;
    }
    final id = product.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk belum siap untuk dipesan.')),
      );
      return;
    }
    final quantity = _cart[id] ?? 0;
    if (quantity >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${product.name} tidak mencukupi.')),
      );
      return;
    }
    setState(() => _cart[id] = quantity + 1);
  }

  void _removeFromCart(MarketProduct product) {
    final id = product.id;
    if (id == null) {
      return;
    }
    final quantity = _cart[id] ?? 0;
    if (quantity == 0) {
      return;
    }
    setState(() {
      if (quantity == 1) {
        _cart.remove(id);
      } else {
        _cart[id] = quantity - 1;
      }
    });
  }

  Future<void> _checkout() async {
    final items = _cartItems();
    if (items.isEmpty) return;
    final order = await Navigator.of(context).push<MarketOrder>(
      MaterialPageRoute<MarketOrder>(
        builder: (_) => _MarketCheckoutScreen(
          items: items,
          profile: widget.profile,
          imagePicker: widget.imagePicker,
          onPlaceOrder:
              ({
                required ReportImage proof,
                required String customerName,
                required String customerPhone,
                required String deliveryAddress,
              }) => widget.onCheckout(
                items,
                proof,
                customerName: customerName,
                customerPhone: customerPhone,
                deliveryAddress: deliveryAddress,
              ),
        ),
      ),
    );
    if (order == null || !mounted) return;
    setState(_cart.clear);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _OrderDetailScreen(order: order)),
    );
  }

  void _showOrderUnavailable() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline_rounded, color: _green),
        title: const Text('Pemesanan belum tersedia'),
        content: const Text(
          'Tunggu sampai laporan tanaman selesai ditinjau untuk memesan produk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab({
    required this.role,
    required this.reports,
    required this.orders,
    required this.onOpenReport,
    required this.onOpenOrder,
  });

  final SihamaRole role;
  final List<CropReport> reports;
  final List<MarketOrder> orders;
  final ValueChanged<CropReport> onOpenReport;
  final ValueChanged<MarketOrder> onOpenOrder;

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _SihamaNotificationItem {
  const _SihamaNotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.date,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String date;
  final VoidCallback? onTap;
}

class _NotificationsTabState extends State<_NotificationsTab> {
  @override
  Widget build(BuildContext context) {
    final reporterOrders = widget.orders;
    final trackedOrder = reporterOrders.isEmpty ? null : reporterOrders.first;
    final pendingOrders = widget.orders
        .where((order) => order.status == 'Dipesan')
        .toList();
    final notices = switch (widget.role) {
      SihamaRole.pelapor =>
        widget.reports
            .map(
              (report) => _SihamaNotificationItem(
                icon: Icons.description_outlined,
                title: report.status == 'Selesai Ditinjau'
                    ? 'Laporan ${report.id} selesai ditinjau'
                    : 'Status laporan ${report.id}: ${report.status}',
                message: report.diagnosis?.trim().isNotEmpty == true
                    ? 'Diagnosis: ${report.diagnosis}'
                    : report.recommendation?.trim().isNotEmpty == true
                    ? 'Rekomendasi: ${report.recommendation}'
                    : report.description,
                date: _formatDate(report.date),
                onTap: () => widget.onOpenReport(report),
              ),
            )
            .toList(),
      SihamaRole.penyuluh =>
        widget.reports
            .where((report) => report.status != 'Selesai Ditinjau')
            .map(
              (report) => _SihamaNotificationItem(
                icon: Icons.assignment_outlined,
                title: 'Laporan ${report.id} menunggu peninjauan',
                message: '${report.crop} · ${report.location}',
                date: _formatDate(report.date),
                onTap: () => widget.onOpenReport(report),
              ),
            )
            .toList(),
      SihamaRole.mitraToko =>
        pendingOrders
            .map(
              (order) => _SihamaNotificationItem(
                icon: Icons.shopping_bag_outlined,
                title: 'Pesanan ${order.id} perlu diproses',
                message:
                    'Pesanan dari ${order.customerName} menunggu diproses.',
                date: _formatDate(order.date),
                onTap: () => widget.onOpenOrder(order),
              ),
            )
            .toList(),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Notifikasi',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (widget.role == SihamaRole.pelapor) ...[
          const SizedBox(height: 8),
          const Text(
            'Status Pesanan',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (trackedOrder == null)
            const _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Belum ada pesanan',
              message: 'Pesanan Anda akan tercatat di bagian ini.',
            )
          else
            GestureDetector(
              onTap: () => widget.onOpenOrder(trackedOrder),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5ECE6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pesanan ${trackedOrder.id}',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusBadge(status: trackedOrder.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatDate(trackedOrder.date).split(' - ').first} · ${trackedOrder.items.length} item',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatPrice(trackedOrder.total),
                      style: TextStyle(
                        color: Color(0xFF18834A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Pemberitahuan',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (notices.isEmpty)
          const _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Belum ada notifikasi',
            message: 'Pembaruan akan muncul di sini saat ada aktivitas.',
          )
        else
          ...notices.map(
            (notice) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: notice.onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5ECE6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F3E6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(notice.icon, color: _green, size: 17),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notice.message,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notice.date,
                            style: const TextStyle(color: _muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
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
    }
  }

  Future<void> _refreshEntries() async {
    final entries = await widget.repository.getDiagnosisReferences();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadError = null;
    });
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
        slug: _slugController.text.trim(),
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        shortDescription: _descriptionController.text.trim(),
        affectedPlantParts: _affectedPartsController.text.trim(),
        growthPhase: _growthPhaseController.text.trim(),
        firstSymptoms: _symptomsController.text.trim(),
        typicalCauses: _causesController.text.trim(),
        moreInfo: _moreInfoController.text.trim(),
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

class _ShopOrdersTab extends StatefulWidget {
  const _ShopOrdersTab({
    required this.orders,
    required this.shopName,
    required this.onUpdateOrder,
  });

  final List<MarketOrder> orders;
  final String shopName;
  final Future<bool> Function(MarketOrder order, String status) onUpdateOrder;

  @override
  State<_ShopOrdersTab> createState() => _ShopOrdersTabState();
}

class _ShopOrdersTabState extends State<_ShopOrdersTab> {
  String _statusFilter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final statuses = ['Semua', 'Dipesan', 'Diproses', 'Dikirim', 'Selesai'];
    final orders = widget.orders.where(
      (order) => _statusFilter == 'Semua' || order.status == _statusFilter,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const Text(
          'Pesanan Masuk',
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Pesanan untuk ${widget.shopName}',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses
                .map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusFilter == status ? Colors.white : _ink,
                        ),
                      ),
                      selected: _statusFilter == status,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF25833E),
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada pesanan',
            message: 'Pesanan baru dari petani akan muncul di sini.',
          ),
        ...orders.map(
          (order) => _ShopOrderCard(
            order: order,
            onTap: () => _showOrderDetails(order),
          ),
        ),
      ],
    );
  }

  Future<void> _showOrderDetails(MarketOrder order) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ShopOrderDetailScreen(
          order: order,
          onUpdateOrder: widget.onUpdateOrder,
        ),
      ),
    );
  }
}

class _ShopOrderCard extends StatelessWidget {
  const _ShopOrderCard({required this.order, required this.onTap});

  final MarketOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE5ECE6)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${order.id} · ${_formatDate(order.date).split(' - ').first}',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.items.length} item',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
                Text(
                  _formatPrice(order.total),
                  style: const TextStyle(
                    color: Color(0xFF18834A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShopOrderDetailScreen extends StatelessWidget {
  const _ShopOrderDetailScreen({
    required this.order,
    required this.onUpdateOrder,
  });

  final MarketOrder order;
  final Future<bool> Function(MarketOrder order, String status) onUpdateOrder;

  @override
  Widget build(BuildContext context) {
    const steps = ['Dipesan', 'Diproses', 'Dikirim', 'Selesai'];
    final active = steps.indexOf(order.status);
    final nextStatus = switch (order.status) {
      'Dipesan' => 'Diproses',
      'Diproses' => 'Dikirim',
      'Dikirim' => 'Selesai',
      _ => null,
    };
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan ${order.id}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${order.customerName} · ${_formatDate(order.date).split(' - ').first}',
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Status',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          _DetailCard(
            title: 'Rincian pesanan',
            child: Column(
              children: [
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} × ${_formatPrice(item.unitPrice)}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              _formatPrice(item.total),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatPrice(order.total),
                      style: const TextStyle(
                        color: Color(0xFF18834A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Penerima & alamat pengiriman',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  order.customerPhone.isEmpty
                      ? 'Kontak belum diisi'
                      : order.customerPhone,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 7),
                Text(
                  order.deliveryAddress.isEmpty
                      ? 'Alamat belum diisi'
                      : order.deliveryAddress,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bukti transfer',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFD7F0D3), Color(0xFFB8DF9B)],
              ),
            ),
            child: order.transferProofBytes == null
                ? const Center(
                    child: Text(
                      'Bukti transfer belum tersedia',
                      style: TextStyle(color: _green, fontSize: 10),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      order.transferProofBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Perjalanan pesanan',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _DetailCard(
            title: 'Status pesanan',
            child: Column(
              children: [
                ...List.generate(steps.length, (index) {
                  final reached = active >= 0 && index <= active;
                  final current = index == active;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Column(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: reached
                                    ? const Color(0xFF25833E)
                                    : const Color(0xFFE3EAE4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                index < active
                                    ? Icons.check_rounded
                                    : Icons.circle,
                                size: 11,
                                color: reached ? Colors.white : _muted,
                              ),
                            ),
                            if (index < steps.length - 1)
                              Container(
                                width: 2,
                                height: 24,
                                color: index < active
                                    ? const Color(0xFF25833E)
                                    : const Color(0xFFE3EAE4),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[index],
                              style: TextStyle(
                                color: reached ? _ink : _muted,
                                fontSize: 11,
                                fontWeight: current
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (current)
                              const Text(
                                'Status saat ini',
                                style: TextStyle(color: _muted, fontSize: 9),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                if (order.status == 'Dibatalkan')
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pesanan dibatalkan',
                      style: TextStyle(color: Color(0xFF9B4038), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (nextStatus != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () async {
                  final saved = await onUpdateOrder(order, nextStatus);
                  if (saved && context.mounted) Navigator.of(context).pop();
                },
                child: Text(switch (nextStatus) {
                  'Diproses' => 'Konfirmasi pesanan',
                  'Dikirim' => 'Tandai dikirim',
                  _ => 'Tandai selesai',
                }),
              ),
            ),
          ],
          if (order.status == 'Dipesan' || order.status == 'Diproses')
            TextButton(
              onPressed: () async {
                final cancel = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Batalkan pesanan?'),
                    content: const Text(
                      'Stok produk akan dikembalikan ke katalog toko.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Kembali'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Batalkan'),
                      ),
                    ],
                  ),
                );
                if (cancel == true && context.mounted) {
                  final saved = await onUpdateOrder(order, 'Dibatalkan');
                  if (saved && context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Batalkan pesanan',
                style: TextStyle(color: Color(0xFF9B4038)),
              ),
            ),
        ],
      ),
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
    required this.userName,
    required this.userEmail,
    required this.onEdit,
    required this.onDelete,
    required this.onLogout,
    required this.reportCount,
    required this.orderCount,
  });

  final FarmerProfile? profile;
  final SihamaRole role;
  final String userName;
  final String? userEmail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function()? onLogout;
  final int reportCount;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    final isReporter = role == SihamaRole.pelapor;
    final details =
        profile ??
        FarmerProfile(
          name: userName,
          role: role.label,
          region: '',
          phone: '',
          address: '',
        );
    final displayName = details.name.trim().isEmpty ? userName : details.name;
    final email = userEmail?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        const _PageHeading(
          eyebrow: 'Akun Anda',
          title: 'Profil',
          subtitle: 'Informasi akun dan preferensi aplikasi.',
        ),
        const SizedBox(height: 18),
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
                      isReporter ? 'Pelapor (Petani)' : role.label,
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
                value: '$orderCount',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
        if (profile == null && isReporter) ...[
          const SizedBox(height: 18),
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
        ],
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
          subtitle: email == null || email.isEmpty
              ? 'Email tidak tersedia'
              : email,
          onTap: null,
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
            subtitle: details.address.isEmpty ? 'Belum diisi' : details.address,
            onTap: onEdit,
          ),
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
        if (isReporter) ...[
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
            label: const Text('Hapus akun'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: onLogout == null
              ? null
              : () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Keluar dari akun?'),
                      content: const Text(
                        'Anda dapat masuk kembali menggunakan email dan kata sandi akun.',
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
                  if (shouldLogout == true) {
                    try {
                      await onLogout!();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal keluar dari akun: $error'),
                          ),
                        );
                      }
                    }
                  }
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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB9E7A1), Color(0xFF5D8D46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.grass_rounded,
                  size: 38,
                  color: Colors.white,
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
                      _reportTitle(report),
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
        const Color(0xFFE8F7EE),
        const Color(0xFF1E8A5D),
      ),
      'Ditinjau' => (
        'Ditinjau',
        const Color(0xFFFFF2D8),
        const Color(0xFF93640A),
      ),
      'Selesai Ditinjau' => (
        'Selesai Ditinjau',
        const Color(0xFFE7F0FA),
        const Color(0xFF356A9A),
      ),
      'Diproses' => (
        'Diproses',
        const Color(0xFFE7F0FA),
        const Color(0xFF356A9A),
      ),
      'Dikirim' => (
        'Dikirim',
        const Color(0xFFE7F0FA),
        const Color(0xFF356A9A),
      ),
      'Selesai' => (
        'Selesai',
        const Color(0xFFE8F7EE),
        const Color(0xFF1E8A5D),
      ),
      'Dibatalkan' => (
        'Dibatalkan',
        const Color(0xFFFCE9E7),
        const Color(0xFF9B4038),
      ),
      'Dipesan' => (
        'Dipesan',
        const Color(0xFFFFF2D8),
        const Color(0xFF93640A),
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

class _MarketSectionHeading extends StatelessWidget {
  const _MarketSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: _ink,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _MarketRecommendationNote extends StatelessWidget {
  const _MarketRecommendationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.eco_outlined, color: Color(0xFF1E6A30), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Direkomendasikan penyuluh untuk diagnosis Anda. Obat lain tetap tersedia, tetapi tidak direkomendasikan untuk kasus ini.',
              style: TextStyle(
                color: Color(0xFF1E6A30),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canOrder,
    required this.canManage,
    required this.isRecommended,
    required this.showRecommendationBadge,
    required this.quantity,
    required this.onOrder,
    required this.onRemoveFromCart,
    required this.onChangeStock,
    required this.onEdit,
    required this.onDelete,
  });

  final MarketProduct product;
  final bool canOrder;
  final bool canManage;
  final bool isRecommended;
  final bool showRecommendationBadge;
  final int quantity;
  final VoidCallback onOrder;
  final VoidCallback onRemoveFromCart;
  final ValueChanged<int> onChangeStock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended
              ? const Color(0xFF25813A)
              : const Color(0xFFE1E8E2),
          width: isRecommended ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1E3C23),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!canManage && showRecommendationBadge)
                _ProductRecommendationBadge(isRecommended: isRecommended),
              const Spacer(),
              if (canManage)
                PopupMenuButton<_CrudAction>(
                  tooltip: 'Aksi produk',
                  onSelected: (action) {
                    if (action == _CrudAction.edit) {
                      onEdit();
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _CrudAction.edit,
                      child: Text('Edit produk'),
                    ),
                    PopupMenuItem(
                      value: _CrudAction.delete,
                      child: Text('Hapus produk'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD7F0DA), Color(0xFFC9E4A8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.photoBytes == null
                    ? const Icon(
                        Icons.eco_outlined,
                        size: 26,
                        color: Color(0xFF1E6A30),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          product.photoBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1B2A1F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(product.price),
                      style: const TextStyle(
                        color: Color(0xFF1E6A30),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stok ${product.stock} · ${product.stock <= 5 ? 'Stok Menipis' : 'Tersedia'}',
                  style: TextStyle(
                    color: product.stock <= 5
                        ? const Color(0xFF93640A)
                        : _muted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (canManage)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundMarketButton(
                      icon: Icons.remove,
                      tooltip: 'Kurangi stok ${product.name}',
                      onPressed: product.stock == 0
                          ? null
                          : () => onChangeStock(product.stock - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${product.stock}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _RoundMarketButton(
                      icon: Icons.add,
                      tooltip: 'Tambah stok ${product.name}',
                      filled: true,
                      onPressed: () => onChangeStock(product.stock + 1),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundMarketButton(
                      icon: Icons.remove,
                      tooltip: 'Kurangi ${product.name} dari keranjang',
                      onPressed: quantity == 0 ? null : onRemoveFromCart,
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1B2A1F),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _RoundMarketButton(
                      icon: canOrder ? Icons.add : Icons.lock_outline_rounded,
                      tooltip: canOrder
                          ? product.stock == 0
                                ? 'Stok habis'
                                : 'Tambah ${product.name} ke keranjang'
                          : 'Pemesanan terkunci',
                      filled: true,
                      onPressed: canOrder && product.stock == 0
                          ? null
                          : onOrder,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductRecommendationBadge extends StatelessWidget {
  const _ProductRecommendationBadge({required this.isRecommended});

  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final color = isRecommended
        ? const Color(0xFF14612B)
        : const Color(0xFF55645A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isRecommended
            ? const Color(0xFFDCF5E1)
            : const Color(0xFFEEF2EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRecommended
                ? Icons.eco_outlined
                : Icons.do_not_disturb_on_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isRecommended ? 'Direkomendasikan' : 'Tidak direkomendasikan',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundMarketButton extends StatelessWidget {
  const _RoundMarketButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Container(
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF25813A) : Colors.white,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: const Color(0xFFE1E8E2)),
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            foregroundColor: filled ? Colors.white : const Color(0xFF1B2A1F),
            backgroundColor: Colors.transparent,
            disabledForegroundColor: const Color(0xFF9AA59D),
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
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
  final VoidCallback? onTap;

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
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: _muted),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _green,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
        ),
      ],
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
            color: selected ? const Color(0xFFDCEDE4) : Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _forest : _muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackChatRepository implements SihamaChatRepository {
  static final Map<String, List<ChatMessage>> _messagesByReport = {};

  @override
  Future<List<ChatMessage>> getChatMessages(String reportId) async {
    final messages = List<ChatMessage>.of(
      _messagesByReport[reportId] ?? const [],
    );
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return messages;
  }

  @override
  Future<void> addChatMessage(ChatMessage message) async {
    _messagesByReport.putIfAbsent(message.reportId, () => []).add(message);
  }
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
                if (widget.report.crop != _unspecifiedCrop) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _crop,
                    decoration: _inputDecoration('Tanaman'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Padi sawah',
                        child: Text('Padi sawah'),
                      ),
                      DropdownMenuItem(value: 'Padi', child: Text('Padi')),
                      DropdownMenuItem(value: 'Cabai', child: Text('Cabai')),
                      DropdownMenuItem(value: 'Tomat', child: Text('Tomat')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _crop = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
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
                photoBytes: widget.report.photoBytes,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto produk gagal dibuka: $error')),
        );
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

IconData _productIcon(String category) {
  if (category == 'Fungisida') return Icons.spa_outlined;
  if (category == 'Bakterisida') return Icons.biotech_outlined;
  if (category == 'Insektisida') return Icons.pest_control_outlined;
  return Icons.grass_rounded;
}

List<MarketProduct> _recommendedProducts(
  CropReport report,
  List<MarketProduct> products,
) {
  final storedNames = RegExp(r'Obat yang disarankan:\s*([^\n]+)')
      .firstMatch(report.recommendation ?? '')
      ?.group(1)
      ?.split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  if (storedNames != null && storedNames.isNotEmpty) {
    return products
        .where((product) => storedNames.contains(product.name))
        .toList();
  }
  return products.where((product) => product.stock > 0).take(2).toList();
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
