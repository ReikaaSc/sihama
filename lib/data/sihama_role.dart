enum SihamaRole {
  pelapor('Pelapor', 'budi@sihama.id'),
  penyuluh('Penyuluh', 'siti@sihama.id'),
  mitraToko('Mitra Toko', 'tanimakmur@sihama.id');

  const SihamaRole(this.label, this.demoEmail);

  final String label;
  final String demoEmail;

  String get accessRole => switch (this) {
    SihamaRole.pelapor => 'pelapor',
    SihamaRole.penyuluh => 'penyuluh',
    SihamaRole.mitraToko => 'mitra_toko',
  };

  static SihamaRole fromAccessRole(String value) => switch (value) {
    'pelapor' => SihamaRole.pelapor,
    'penyuluh' => SihamaRole.penyuluh,
    'mitra_toko' => SihamaRole.mitraToko,
    _ => throw FormatException('Peran SIHAMA tidak dikenal: $value'),
  };
}
