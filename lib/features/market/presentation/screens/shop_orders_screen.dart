part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

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
