part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _MarketCheckoutScreen extends StatefulWidget {
  const _MarketCheckoutScreen({
    required this.items,
    required this.reviewedReports,
    required this.profile,
    required this.imagePicker,
    required this.onPlaceOrder,
  });

  final List<MarketOrderItem> items;
  final List<CropReport> reviewedReports;
  final FarmerProfile? profile;
  final ReportImagePicker imagePicker;
  final Future<MarketOrder?> Function({
    required ReportImage proof,
    required String reportId,
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
  String? _selectedReportId;
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
              title: 'Laporan terkait',
              child: DropdownButtonFormField<String>(
                initialValue: _selectedReportId,
                decoration: _inputDecoration('Pilih laporan selesai ditinjau'),
                items: widget.reviewedReports
                    .map(
                      (report) => DropdownMenuItem(
                        value: report.id,
                        child: Text(
                          '${report.id} · ${_reportTitle(report)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null
                    ? 'Pilih laporan yang terkait dengan pesanan ini.'
                    : null,
                onChanged: (value) => setState(() => _selectedReportId = value),
              ),
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
        reportId: _selectedReportId!,
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

class _RefreshingReportScreen extends StatefulWidget {
  const _RefreshingReportScreen({
    required this.report,
    required this.products,
    required this.repository,
    required this.builder,
  });

  final CropReport report;
  final List<MarketProduct> products;
  final SihamaRepository repository;
  final Widget Function(
    BuildContext context,
    CropReport report,
    List<MarketProduct> products,
  )
  builder;

  @override
  State<_RefreshingReportScreen> createState() =>
      _RefreshingReportScreenState();
}

class _RefreshingReportScreenState extends State<_RefreshingReportScreen> {
  late CropReport _report = widget.report;
  late List<MarketProduct> _products = widget.products;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshData()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final reports = await widget.repository.getReports();
      final products = await widget.repository.getProducts();
      if (!mounted) return;
      for (final report in reports) {
        if (report.id == _report.id) {
          setState(() => _report = report);
          break;
        }
      }
      setState(() => _products = products);
      _refreshFailed = false;
    } catch (error) {
      if (!mounted || _refreshFailed) return;
      _refreshFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembaruan detail laporan gagal: $error')),
      );
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _report, _products);
}

class _OrderDetailScreen extends StatefulWidget {
  const _OrderDetailScreen({required this.order, required this.repository});

  final MarketOrder order;
  final SihamaRepository repository;

  @override
  State<_OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<_OrderDetailScreen> {
  late MarketOrder _order = widget.order;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshOrder()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final orders = await widget.repository.getOrders();
      MarketOrder? latestOrder;
      for (final order in orders) {
        if (order.id == _order.id) {
          latestOrder = order;
          break;
        }
      }
      if (!mounted) return;
      if (latestOrder != null) setState(() => _order = latestOrder!);
      _refreshFailed = false;
    } catch (error) {
      if (!mounted || _refreshFailed) return;
      _refreshFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembaruan pesanan gagal: $error')),
      );
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
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
