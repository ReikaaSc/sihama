part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

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
                            color: selected ? _green : const Color(0xFF6F7D74),
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
