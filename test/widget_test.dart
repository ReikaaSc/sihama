import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sihama/data/sihama_repository.dart';
import 'package:sihama/main.dart';

void main() {
  testWidgets('SIHAMA navigation opens the requested sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SihamaApp(repository: _MemoryRepository()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Halo, Pak Budi'), findsOneWidget);
    expect(find.text('Laporan terbaru'), findsOneWidget);
    expect(find.text('Buat Laporan Sekarang'), findsOneWidget);

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat laporan'), findsOneWidget);
    expect(find.text('Padi sawah - Petak Utara'), findsOneWidget);
    await tester.tap(find.text('Selesai Ditinjau'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada laporan'), findsOneWidget);
    await tester.tap(find.text('Diajukan').first);
    await tester.pumpAndSettle();
    expect(find.text('Padi sawah - Petak Utara'), findsOneWidget);

    await tester.tap(find.text('AgriMarket'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pemesanan akan tersedia setelah laporan tanaman selesai ditinjau.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kocide 54 WDG'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'kocide');
    await tester.pumpAndSettle();
    expect(find.text('Kocide 54 WDG'), findsOneWidget);
    expect(find.text('Nordox 56 WP'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit profil'));
    await tester.pumpAndSettle();
    final profileFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(profileFields.at(0), 'Budi Santoso');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Profil belum dibuat'), findsOneWidget);

    await tester.tap(find.text('Buat profil'));
    await tester.pumpAndSettle();
    final createProfileFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(createProfileFields.at(0), 'Budi Baru');
    await tester.enterText(createProfileFields.at(2), 'Bogor');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Baru'), findsOneWidget);
  });

  testWidgets('Mitra Toko can create, edit, and delete products', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SihamaApp(repository: _MemoryRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mitra Toko'));
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Produk & Stok'), findsOneWidget);

    await tester.tap(find.text('Tambah produk'));
    await tester.pumpAndSettle();
    final productFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(productFields.at(0), 'Z-Pupuk uji');
    await tester.enterText(productFields.at(1), '12500');
    await tester.enterText(productFields.at(2), '12');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Z-Pupuk uji'), findsOneWidget);
    expect(find.text('Stok 12 · Tersedia'), findsOneWidget);

    await tester.ensureVisible(find.text('Z-Pupuk uji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aksi produk').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit produk'));
    await tester.pumpAndSettle();
    final editProductFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(editProductFields.at(0), 'Z-Pupuk diperbarui');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Z-Pupuk diperbarui'), findsOneWidget);

    await tester.ensureVisible(find.text('Z-Pupuk diperbarui'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aksi produk').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Z-Pupuk diperbarui'), findsNothing);
  });

  testWidgets(
    'Penyuluh can access reports, disease references, and notifications',
    (WidgetTester tester) async {
      await tester.pumpWidget(SihamaApp(repository: _MemoryRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Penyuluh'));
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan Masuk'), findsWidgets);

      await tester.tap(find.text('Basis Data'));
      await tester.pumpAndSettle();
      expect(find.text('Basis Data Gejala-Penyakit'), findsOneWidget);
      expect(find.text('Hawar Daun Bakteri'), findsOneWidget);

      await tester.tap(find.text('Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Pembaruan akun'), findsOneWidget);
      expect(find.text('Laporan baru masuk'), findsOneWidget);
    },
  );

  testWidgets('submitting a report adds it to history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SihamaApp(repository: _MemoryRepository()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Laporan Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Ceritakan gejala'), findsOneWidget);

    final cropDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(cropDropdown);
    await tester.tap(cropDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cabai').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Petak Selatan');
    await tester.enterText(fields.at(1), 'Daun terlihat menguning.');
    final formList = find.ancestor(
      of: find.text('Ceritakan gejala'),
      matching: find.byType(ListView),
    );
    await tester.drag(formList, const Offset(0, -450));
    await tester.pumpAndSettle();
    final submitButton = find.byType(FilledButton);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Riwayat laporan'), findsOneWidget);
    expect(find.text('Cabai - Petak Selatan'), findsOneWidget);

    await tester.tap(find.byTooltip('Aksi laporan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit laporan'));
    await tester.pumpAndSettle();
    final editReportFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(editReportFields.at(0), 'Petak Revisi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Cabai - Petak Revisi'), findsOneWidget);

    await tester.tap(find.byTooltip('Aksi laporan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus laporan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Cabai - Petak Revisi'), findsNothing);
  });
}

class _MemoryRepository implements SihamaRepository {
  final reports = <CropReport>[
    CropReport(
      id: 'SIH-240618',
      crop: 'Padi sawah',
      location: 'Petak Utara',
      description: 'Daun menguning di beberapa bagian.',
      date: DateTime(2025, 6, 18, 8, 24),
      status: 'Diajukan',
    ),
  ];

  final products = <MarketProduct>[
    const MarketProduct(
      id: 1,
      name: 'Kocide 54 WDG',
      category: 'Bakterisida',
      price: 85000,
      stock: 42,
    ),
    const MarketProduct(
      id: 2,
      name: 'Nordox 56 WP',
      category: 'Bakterisida',
      price: 72000,
      stock: 4,
    ),
    const MarketProduct(
      id: 3,
      name: 'Score 250 EC',
      category: 'Fungisida',
      price: 142000,
      stock: 18,
    ),
    const MarketProduct(
      id: 4,
      name: 'Dithane M-45 80 WP',
      category: 'Fungisida',
      price: 68000,
      stock: 3,
    ),
  ];

  FarmerProfile? profile = const FarmerProfile(
    name: 'Budi Santoso',
    role: 'Petani',
    region: 'Kabupaten Bogor',
    phone: '',
    address: '',
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<List<CropReport>> getReports() async => List.of(reports);

  @override
  Future<void> createReport(CropReport report) async =>
      reports.insert(0, report);

  @override
  Future<void> updateReport(CropReport report) async {
    final index = reports.indexWhere((item) => item.id == report.id);
    if (index < 0) throw StateError('Report not found');
    reports[index] = report;
  }

  @override
  Future<void> deleteReport(String id) async =>
      reports.removeWhere((item) => item.id == id);

  @override
  Future<List<MarketProduct>> getProducts() async => List.of(products);

  @override
  Future<int> createProduct(MarketProduct product) async {
    final id =
        products.fold<int>(0, (max, item) => item.id! > max ? item.id! : max) +
        1;
    products.add(
      MarketProduct(
        id: id,
        name: product.name,
        category: product.category,
        price: product.price,
        stock: product.stock,
      ),
    );
    return id;
  }

  @override
  Future<void> updateProduct(MarketProduct product) async {
    final index = products.indexWhere((item) => item.id == product.id);
    if (index < 0) throw StateError('Product not found');
    products[index] = product;
  }

  @override
  Future<void> deleteProduct(int id) async =>
      products.removeWhere((item) => item.id == id);

  @override
  Future<FarmerProfile?> getProfile() async => profile;

  @override
  Future<void> createProfile(FarmerProfile value) async {
    if (profile != null) throw StateError('Profile already exists');
    profile = value;
  }

  @override
  Future<void> updateProfile(FarmerProfile value) async => profile = value;

  @override
  Future<void> deleteProfile(int id) async => profile = null;
}
