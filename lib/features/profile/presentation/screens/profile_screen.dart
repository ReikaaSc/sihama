part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

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
    final profileName = details.name.trim();
    final displayName = profileName.isEmpty || profileName == 'Pengguna SIHAMA'
        ? userName
        : profileName;
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
        if (profile == null) ...[
          const SizedBox(height: 18),
          _EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'Profil belum dibuat',
            message: 'Lengkapi informasi akun ${role.label.toLowerCase()}.',
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
        _ProfileMenuTile(
          icon: Icons.phone_outlined,
          title: 'Nomor telepon',
          subtitle: details.phone.isEmpty ? 'Belum diisi' : details.phone,
          onTap: onEdit,
        ),
        _ProfileMenuTile(
          icon: Icons.map_outlined,
          title: 'Wilayah',
          subtitle: details.region.isEmpty ? 'Belum diisi' : details.region,
          onTap: onEdit,
        ),
        _ProfileMenuTile(
          icon: Icons.location_on_outlined,
          title: 'Alamat',
          subtitle: details.address.isEmpty ? 'Belum diisi' : details.address,
          onTap: onEdit,
        ),
        if (role == SihamaRole.penyuluh) ...[
          _ProfileMenuTile(
            icon: Icons.verified_outlined,
            title: 'Nomor sertifikasi',
            subtitle: details.certification.isEmpty
                ? 'Belum diisi'
                : details.certification,
            onTap: onEdit,
          ),
          _ProfileMenuTile(
            icon: Icons.account_balance_outlined,
            title: 'Instansi',
            subtitle: details.institution.isEmpty
                ? 'Belum diisi'
                : details.institution,
            onTap: onEdit,
          ),
        ],
        if (role == SihamaRole.mitraToko) ...[
          _ProfileMenuTile(
            icon: Icons.storefront_outlined,
            title: 'Nama toko',
            subtitle: details.shopName.isEmpty
                ? 'Belum diisi'
                : details.shopName,
            onTap: onEdit,
          ),
          _ProfileMenuTile(
            icon: Icons.article_outlined,
            title: 'Legalitas usaha',
            subtitle: details.legality.isEmpty
                ? 'Belum diisi'
                : details.legality,
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
        _ProfileMenuTile(
          icon: Icons.person_outline_rounded,
          title: 'Informasi pribadi',
          subtitle: 'Nama, kontak, dan detail peran',
          onTap: onEdit,
        ),
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
