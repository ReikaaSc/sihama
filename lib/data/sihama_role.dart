enum SihamaRole {
  pelapor('Pelapor', 'budi@sihama.id'),
  penyuluh('Penyuluh', 'siti@sihama.id'),
  mitraToko('Mitra Toko', 'tanimakmur@sihama.id');

  const SihamaRole(this.label, this.demoEmail);

  final String label;
  final String demoEmail;
}
