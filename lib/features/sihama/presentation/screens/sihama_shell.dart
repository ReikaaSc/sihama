import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:sihama/features/auth/domain/entities/sihama_role.dart';
import 'package:sihama/features/reports/data/datasources/report_image.dart';
import 'package:sihama/features/sihama/data/datasources/sihama_database.dart';
import 'package:sihama/shared/domain/repositories/sihama_repository.dart';
import 'package:sihama/shared/models/sihama_models.dart';

part '../../../home/presentation/widgets/home_widgets.dart';
part '../../../chat/presentation/screens/chat_screens.dart';
part '../../../market/presentation/screens/checkout_screens.dart';
part '../../../reports/presentation/screens/adviser_review_screen.dart';
part '../../../reports/presentation/screens/report_screens.dart';
part '../../../market/presentation/screens/market_screen.dart';
part '../../../notifications/presentation/screens/notifications_screen.dart';
part '../../../diagnosis/presentation/screens/diagnosis_screens.dart';
part '../../../market/presentation/screens/shop_orders_screen.dart';
part '../../../profile/presentation/screens/profile_screen.dart';
part '../../../../shared/widgets/sihama_widgets.dart';
part '../../../auth/presentation/widgets/delete_account_dialog.dart';
part '../../../reports/presentation/widgets/report_form_dialog.dart';
part '../../../market/presentation/widgets/product_forms.dart';
part '../../../profile/presentation/widgets/profile_form_dialog.dart';
part '../../../../shared/widgets/sihama_helpers.dart';

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
    this.onDeleteAccount,
    this.onLogout,
  });

  final SihamaRepository? repository;
  final ReportImagePicker? imagePicker;
  final SihamaRole role;
  final String? userName;
  final String? userEmail;
  final Future<void> Function(String password)? onDeleteAccount;
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
  List<SihamaNotification> _notifications = [];
  FarmerProfile? _profile;
  bool _loading = true;
  Object? _loadError;
  Timer? _refreshTimer;
  bool _isLoadingData = false;
  bool _hasBackgroundRefreshError = false;

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
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_loadData(showLoading: false)),
    );
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (_isLoadingData) return;
    _isLoadingData = true;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      await _repository.initialize();
      final reports = await _repository.getReports();
      final products = await _repository.getProducts();
      final orders = await _repository.getOrders();
      final profile = await _repository.getProfile();
      final notifications = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _products = products;
        _orders = orders;
        _notifications = notifications;
        _profile = profile;
        _loadError = null;
        _loading = false;
      });
      _hasBackgroundRefreshError = false;
    } catch (error) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _loadError = error;
          _loading = false;
        });
      } else {
        final shouldNotify = !_hasBackgroundRefreshError;
        _hasBackgroundRefreshError = true;
        if (shouldNotify) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pembaruan data gagal: $error')),
          );
        }
      }
    } finally {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  Future<bool> _submitReport(CropReport report) async {
    try {
      await _repository.createReport(report);
      await _loadData(showLoading: false);
      if (!mounted) return false;
      var savedReport = report;
      for (final existingReport in _reports) {
        if (existingReport.id == report.id) {
          savedReport = existingReport;
          break;
        }
      }
      setState(() {
        _selectedIndex = 1;
        _showReportForm = false;
        _showConversations = false;
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: _green),
          title: const Text('Laporan berhasil dikirim'),
          content: Text(
            'Laporan ${savedReport.id} sudah tersimpan dan siap dilihat.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lihat detail laporan'),
            ),
          ],
        ),
      );
      if (!mounted) return true;
      _showReportDetails(context, savedReport);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Laporan gagal dikirim: $error')));
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
                onSubmit: _submitReport,
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
          repository: _repository,
          products: _products,
          reviewedReports: _reports
              .where((report) => report.status == 'Selesai Ditinjau')
              .toList(),
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
        notifications: _notifications,
        onOpenReport: (report) => _showReportDetails(context, report),
        onOpenOrder: (order) => _showOrderDetails(context, order),
        onOpenNotification: _openNotification,
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
        builder: (context) => _RefreshingReportScreen(
          report: report,
          products: _products,
          repository: _repository,
          builder: (context, report, products) {
            final recommendedProducts = _recommendedProducts(report, products);
            return Scaffold(
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
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
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
                          Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF946313),
                          ),
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
                                  report.diagnosis ??
                                      'Diagnosis belum tersedia',
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
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                    ),
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
            );
          },
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, MarketOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _OrderDetailScreen(order: order, repository: _repository),
      ),
    );
  }

  Future<void> _openNotification(SihamaNotification notification) async {
    try {
      if (!notification.isRead) {
        await _repository.markNotificationRead(notification.id);
        await _loadData(showLoading: false);
      }
      if (!mounted) return;
      final reportId = notification.reportId;
      if (reportId != null) {
        for (final report in _reports) {
          if (report.id == reportId) {
            _showReportDetails(context, report);
            return;
          }
        }
      }
      final orderId = notification.orderId;
      if (orderId != null) {
        for (final order in _orders) {
          if (order.id == orderId) {
            _showOrderDetails(context, order);
            return;
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data terkait notifikasi tidak ditemukan.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notifikasi gagal diperbarui: $error')),
      );
    }
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
          dataRepository: _repository,
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
    List<DiagnosisReference> diagnoses = const [];
    if (widget.role == SihamaRole.penyuluh) {
      try {
        diagnoses = await _repository.getDiagnosisReferences();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Referensi penyakit gagal dimuat: $error')),
        );
        return;
      }
    }
    if (!mounted) return;
    final updated = await showDialog<CropReport>(
      context: context,
      builder: (context) => _ReportFormDialog(
        report: report,
        role: widget.role,
        diagnoses: diagnoses,
      ),
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
    required String reportId,
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
      reportId: reportId,
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
    final existingProfile = _profile;
    final profileForEdit =
        existingProfile != null &&
            (existingProfile.name.trim().isEmpty ||
                existingProfile.name.trim() == 'Pengguna SIHAMA')
        ? FarmerProfile(
            id: existingProfile.id,
            name: _currentUserName,
            role: existingProfile.role,
            region: existingProfile.region,
            phone: existingProfile.phone,
            address: existingProfile.address,
            certification: existingProfile.certification,
            institution: existingProfile.institution,
            shopName: existingProfile.shopName,
            legality: existingProfile.legality,
          )
        : existingProfile;
    final profile = await showDialog<FarmerProfile>(
      context: context,
      builder: (context) =>
          _ProfileFormDialog(profile: profileForEdit, role: widget.role),
    );
    if (profile != null) await _saveProfile(profile);
  }

  Future<void> _deleteProfile() async {
    final profile = _profile;
    final subject = profile == null ? 'akun pelapor' : 'akun ${profile.name}';
    if (!await _confirmDelete(
      context,
      subject,
      title: 'Langkah 1 dari 2',
      confirmLabel: 'Lanjutkan',
    )) {
      return;
    }
    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    try {
      final deleteAccount = widget.onDeleteAccount;
      if (deleteAccount != null) {
        await deleteAccount(password);
        return;
      }
      if (widget.userEmail != null) {
        throw StateError('Verifikasi kata sandi akun tidak tersedia.');
      }
      if (profile == null) {
        throw StateError('Profil tidak ditemukan untuk dihapus.');
      }
      await _repository.deleteProfile(profile.id);
      if (!mounted) return;
      setState(() => _profile = null);
      await widget.onLogout?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Penghapusan akun gagal: $error')));
    }
  }
}
