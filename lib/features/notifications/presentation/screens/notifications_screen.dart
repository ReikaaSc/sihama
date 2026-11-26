part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab({
    required this.role,
    required this.reports,
    required this.orders,
    required this.notifications,
    required this.onOpenReport,
    required this.onOpenOrder,
    required this.onOpenNotification,
  });

  final SihamaRole role;
  final List<CropReport> reports;
  final List<MarketOrder> orders;
  final List<SihamaNotification> notifications;
  final ValueChanged<CropReport> onOpenReport;
  final ValueChanged<MarketOrder> onOpenOrder;
  final ValueChanged<SihamaNotification> onOpenNotification;

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _SihamaNotificationItem {
  const _SihamaNotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.date,
    required this.isRead,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String date;
  final bool isRead;
  final VoidCallback? onTap;
}

class _NotificationsTabState extends State<_NotificationsTab> {
  @override
  Widget build(BuildContext context) {
    final reporterOrders = widget.orders;
    final trackedOrder = reporterOrders.isEmpty ? null : reporterOrders.first;
    final trackedOrderUnread =
        trackedOrder != null &&
        widget.notifications.any(
          (notification) =>
              notification.orderId == trackedOrder.id && !notification.isRead,
        );
    final notices = widget.notifications
        .where(
          (notification) => widget.role == SihamaRole.pelapor
              ? notification.reportId != null || notification.orderId != null
              : widget.role == SihamaRole.penyuluh
              ? notification.reportId != null
              : notification.orderId != null,
        )
        .map(
          (notification) => _SihamaNotificationItem(
            icon: notification.orderId == null
                ? Icons.assignment_outlined
                : Icons.shopping_bag_outlined,
            title: notification.title,
            message: notification.message,
            date: _formatDate(notification.date),
            isRead: notification.isRead,
            onTap: () => widget.onOpenNotification(notification),
          ),
        )
        .toList();

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
                  color: trackedOrderUnread
                      ? const Color(0xFFEAF4EE)
                      : Colors.white,
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
                  color: notice.isRead ? Colors.white : const Color(0xFFEAF4EE),
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
