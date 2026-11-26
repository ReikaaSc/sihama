part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

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
