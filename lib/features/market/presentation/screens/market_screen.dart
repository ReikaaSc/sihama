part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _MarketTab extends StatefulWidget {
  const _MarketTab({
    required this.repository,
    required this.products,
    required this.reviewedReports,
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

  final SihamaRepository repository;
  final List<MarketProduct> products;
  final List<CropReport> reviewedReports;
  final List<MarketProduct> recommendedProducts;
  final FarmerProfile? profile;
  final bool canOrder;
  final bool canManage;
  final ReportImagePicker imagePicker;
  final Future<MarketOrder?> Function(
    List<MarketOrderItem> items,
    ReportImage proof, {
    required String reportId,
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
  final _searchController = TextEditingController();
  final Map<int, int> _cart = {};

  static const _categories = [
    'Semua',
    'Fungisida',
    'Bakterisida',
    'Insektisida',
    'Herbisida',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = widget.products.where((product) {
      final searchableText = [
        product.name,
        product.category,
        product.description,
      ].join(' ').toLowerCase();
      final matchesQuery = searchableText.contains(_searchQuery);
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
                key: const ValueKey('market-product-search'),
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: _inputDecoration('Cari produk').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          tooltip: 'Hapus pencarian produk',
                          icon: const Icon(Icons.clear_rounded),
                        ),
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
          reviewedReports: widget.reviewedReports,
          profile: widget.profile,
          imagePicker: widget.imagePicker,
          onPlaceOrder:
              ({
                required ReportImage proof,
                required String reportId,
                required String customerName,
                required String customerPhone,
                required String deliveryAddress,
              }) => widget.onCheckout(
                items,
                proof,
                reportId: reportId,
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
      MaterialPageRoute<void>(
        builder: (_) =>
            _OrderDetailScreen(order: order, repository: widget.repository),
      ),
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
