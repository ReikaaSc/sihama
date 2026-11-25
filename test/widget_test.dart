import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sihama/data/diagnosis_dataset.dart';
import 'package:sihama/data/report_image.dart';
import 'package:sihama/data/sihama_repository.dart';
import 'package:sihama/main.dart';
import 'package:sihama/data/sihama_role.dart';
import 'package:sihama/sihama_shell.dart';

void main() {
  testWidgets('diagnosis dataset parses all bundled records', (
    WidgetTester tester,
  ) async {
    final references = await tester.runAsync(() async {
      final source = await rootBundle.loadString(DiagnosisDataset.assetPath);
      return DiagnosisDataset.parse(source);
    });
    expect(references, isNotNull);
    final dataset = references!;
    final aphids = dataset.singleWhere(
      (reference) => reference.slug == 'blattlaeuse',
    );

    expect(dataset, hasLength(79));
    expect(aphids.name, isNot(contains('Aphid')));
    expect(aphids.category, 'Hama');
    expect(aphids.typicalCauses, contains('semut'));
    expect(dataset.map((reference) => reference.slug).toSet(), hasLength(79));
  });

  testWidgets('adviser can add a persistent diagnosis reference', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SihamaShell(repository: repository, role: SihamaRole.penyuluh),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basis Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah referensi'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'powdery-mildew');
    await tester.enterText(fields.at(1), 'Embun tepung');
    await tester.enterText(fields.at(2), 'Penyakit / jamur');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.diagnosisReferences.single.name, 'Embun tepung');
    expect(find.text('Embun tepung'), findsOneWidget);
  });

  testWidgets('diagnosis dropdown searches symptoms and shows matching onset', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryRepository();
    repository.diagnosisReferences.addAll(const [
      DiagnosisReference(
        slug: 'antraknosa',
        name: 'Antraknosa',
        category: 'Penyakit / jamur',
        shortDescription: 'Infeksi jamur pada tanaman.',
        affectedPlantParts: 'Daun dan batang',
        growthPhase: 'Semua fase',
        firstSymptoms: 'Bercak cokelat cekung pada daun.',
        typicalCauses: 'Kondisi lembap berkepanjangan.',
        moreInfo: '',
      ),
      DiagnosisReference(
        slug: 'kutu-daun',
        name: 'Kutu daun',
        category: 'Hama',
        shortDescription: 'Serangga kecil pada tunas.',
        affectedPlantParts: 'Tunas muda',
        growthPhase: 'Fase pertumbuhan',
        firstSymptoms: 'Kelompok serangga kecil di ujung tunas.',
        typicalCauses: 'Tanaman terinfeksi.',
        moreInfo: '',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: SihamaShell(repository: repository, role: SihamaRole.penyuluh),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Padi sawah - Petak Utara'));
    await tester.pumpAndSettle();

    final diagnosisPicker = find.byKey(const ValueKey('diagnosis-picker'));
    await tester.ensureVisible(diagnosisPicker);
    await tester.tap(diagnosisPicker);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('diagnosis-search')),
      'cokelat',
    );
    await tester.pumpAndSettle();

    expect(find.text('Antraknosa'), findsOneWidget);
    expect(find.text('Kutu daun'), findsNothing);
    await tester.tap(find.text('Antraknosa'));
    await tester.pumpAndSettle();
    expect(find.text('Bercak cokelat cekung pada daun.'), findsOneWidget);

    final recommendationField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Tulis rekomendasi yang akan diterima petani',
    );
    await tester.enterText(recommendationField, 'Pantau kelembapan tanaman.');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Diagnosis'));
    await tester.pumpAndSettle();
    expect(repository.reports.first.diagnosis, 'Antraknosa');
  });

  testWidgets('reporter can search and select dataset initial symptoms', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryRepository();
    repository.diagnosisReferences.addAll(const [
      DiagnosisReference(
        slug: 'antraknosa',
        name: 'Antraknosa',
        category: 'Penyakit / jamur',
        shortDescription: 'Infeksi jamur pada tanaman.',
        affectedPlantParts: 'Daun dan batang',
        growthPhase: 'Semua fase',
        firstSymptoms:
            'Bercak cokelat cekung pada daun; Daun menguning di ujung.',
        typicalCauses: 'Kondisi lembap berkepanjangan.',
        moreInfo: '',
      ),
      DiagnosisReference(
        slug: 'kutu-daun',
        name: 'Kutu daun',
        category: 'Hama',
        shortDescription: 'Serangga kecil pada tunas.',
        affectedPlantParts: 'Tunas muda',
        growthPhase: 'Fase pertumbuhan',
        firstSymptoms: 'Kelompok serangga kecil di ujung tunas.',
        typicalCauses: 'Tanaman terinfeksi.',
        moreInfo: '',
      ),
    ]);

    await tester.pumpWidget(SihamaApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Laporan Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-symptom-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('symptom-search')),
      'menguning',
    );
    await tester.pumpAndSettle();

    expect(find.text('Daun menguning di ujung.'), findsOneWidget);
    expect(find.text('Bercak cokelat cekung pada daun'), findsNothing);
    expect(find.text('Kelompok serangga kecil di ujung tunas.'), findsNothing);
    await tester.tap(find.text('Daun menguning di ujung.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan gejala (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Daun menguning di ujung.'), findsOneWidget);
  });

  testWidgets('diagnosis detail stays left aligned on narrow screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    final repository = _MemoryRepository();
    repository.diagnosisReferences.add(
      const DiagnosisReference(
        slug: 'agas-jamur',
        name: 'Agas jamur (lalat hitam media tanam)',
        category: 'Hama',
        shortDescription: 'Lalat hitam kecil yang larvanya memakan rambut akar dan bahan organik di substrat yang lembap.',
        affectedPlantParts: 'Rambut akar; permukaan substrat',
        growthPhase: 'Semua fase; terutama saat substrat terus lembap',
        firstSymptoms:
            'Lalat hitam kecil beterbangan; pertumbuhan sedikit melambat',
        typicalCauses: 'Permukaan substrat terlalu lembap; bahan organik menjadi sumber makanan larva',
        moreInfo: 'https://plantclue.com/a-very-long-diagnosis-reference-url/',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SihamaShell(repository: repository, role: SihamaRole.penyuluh),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basis Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agas jamur (lalat hitam media tanam)'));
    await tester.pumpAndSettle();

    final labelPosition = tester.getTopLeft(
      find.text('Bagian tanaman terdampak'),
    );
    final valuePosition = tester.getTopLeft(find.text('Rambut akar'));
    expect((labelPosition.dx - valuePosition.dx).abs(), lessThan(20));
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('report image validation accepts only supported image formats', () {
    final png = ReportImage(name: 'plant.PNG', bytes: _samplePng);
    final jpeg = ReportImage(
      name: 'plant.jpeg',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
    );
    final jpg = ReportImage(
      name: 'plant.jpg',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
    );

    expect(validateReportImage(png), isNull);
    expect(validateReportImage(jpeg), isNull);
    expect(validateReportImage(jpg), isNull);
    expect(
      validateReportImage(ReportImage(name: 'notes.pdf', bytes: _samplePng)),
      isNotNull,
    );
    expect(
      validateReportImage(
        ReportImage(
          name: 'fake.jpg',
          bytes: Uint8List.fromList([
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
          ]),
        ),
      ),
      isNotNull,
    );
    expect(
      validateReportImage(
        ReportImage(
          name: 'large.png',
          bytes: Uint8List(maxReportImageBytes + 1),
        ),
      ),
      'Ukuran foto maksimal 5 MB.',
    );
  });

  test('report image bytes survive the repository map conversion', () {
    final report = CropReport(
      id: 'L-1001',
      crop: 'Padi',
      location: 'Petak Utara',
      description: 'Daun menguning',
      date: DateTime(2025, 5, 15),
      status: 'Diajukan',
      photoBytes: _samplePng,
    );

    final restored = CropReport.fromMap(report.toMap());
    expect(restored.photoBytes, orderedEquals(_samplePng));
  });

  test('market order map conversion preserves item details and total', () {
    final order = MarketOrder(
      id: 'P-1001',
      customerName: 'Budi Santoso',
      date: DateTime(2025, 5, 13),
      status: 'Dipesan',
      customerPhone: '08123456789',
      deliveryAddress: 'Jl. Raya Bogor No. 10',
      items: const [
        MarketOrderItem(
          productId: 2,
          productName: 'Nordox 56 WP',
          quantity: 2,
          unitPrice: 72000,
        ),
      ],
    );

    final restored = MarketOrder.fromMap(order.toMap());

    expect(restored.id, order.id);
    expect(restored.status, 'Dipesan');
    expect(restored.customerPhone, '08123456789');
    expect(restored.deliveryAddress, 'Jl. Raya Bogor No. 10');
    expect(restored.total, 144000);
    expect(restored.items.single.productName, 'Nordox 56 WP');
    expect(restored.items.single.quantity, 2);

    final oldMap = Map<String, Object?>.from(order.toMap())
      ..remove('customer_phone')
      ..remove('delivery_address');
    final restoredOldOrder = MarketOrder.fromMap(oldMap);
    expect(restoredOldOrder.customerPhone, isEmpty);
    expect(restoredOldOrder.deliveryAddress, isEmpty);
  });

  testWidgets('SIHAMA navigation opens the requested sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SihamaApp(repository: _MemoryRepository()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Laporan Terakhir'), findsOneWidget);
    expect(find.text('Buat Laporan Sekarang'), findsOneWidget);

    await tester.tap(find.byTooltip('Percakapan'));
    await tester.pumpAndSettle();
    expect(find.text('Percakapan'), findsOneWidget);
    expect(find.text('Ir. Siti Rahmawati'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Status Pesanan'), findsOneWidget);
    expect(find.text('Pesanan P-2201'), findsOneWidget);
    expect(find.text('Tandai dibaca'), findsOneWidget);
    await tester.tap(find.text('Tandai dibaca'));
    await tester.pumpAndSettle();
    expect(find.text('Sudah dibaca'), findsOneWidget);

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

  testWidgets(
    'AgriMarket groups diagnosis recommendations and tracks quantity',
    (WidgetTester tester) async {
      final repository = _MemoryRepository();
      final report = repository.reports.first;
      repository.reports[0] = CropReport(
        id: report.id,
        crop: report.crop,
        location: report.location,
        description: report.description,
        date: report.date,
        status: 'Selesai Ditinjau',
        recommendation: 'Obat yang disarankan: Nordox 56 WP',
      );

      await tester.pumpWidget(SihamaApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AgriMarket'));
      await tester.pumpAndSettle();

      expect(find.text('Direkomendasikan'), findsNWidgets(2));
      expect(find.text('Nordox 56 WP'), findsOneWidget);
      expect(
        find.text(
          'Pemesanan akan tersedia setelah laporan tanaman selesai ditinjau.',
        ),
        findsNothing,
      );

      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      final addToCart = find.byTooltip('Tambah Nordox 56 WP ke keranjang');
      await tester.ensureVisible(addToCart);
      await tester.tap(addToCart);
      await tester.pumpAndSettle();
      expect(find.textContaining('Lanjutkan pesanan (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Kurangi Nordox 56 WP dari keranjang'));
      await tester.pumpAndSettle();
      expect(find.text('Keranjang kosong'), findsOneWidget);
    },
  );

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
      expect(find.text('Notifikasi'), findsWidgets);
      expect(find.text('Laporan baru masuk'), findsOneWidget);
    },
  );

  testWidgets('reviewed report unlocks checkout and shop order processing', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryRepository();
    final report = repository.reports.first;
    repository.reports[0] = CropReport(
      id: report.id,
      crop: report.crop,
      location: report.location,
      description: report.description,
      date: report.date,
      status: 'Selesai Ditinjau',
    );
    await tester.pumpWidget(
      SihamaApp(
        key: const ValueKey('reporter'),
        repository: repository,
        imagePicker: () async =>
            ReportImage(name: 'transfer.png', bytes: _samplePng),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AgriMarket'));
    await tester.pumpAndSettle();
    final addToCart = find.byTooltip('Tambah Kocide 54 WDG ke keranjang');
    await tester.ensureVisible(addToCart);
    await tester.tap(addToCart);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.textContaining('Lanjutkan pesanan'));
    await tester.pumpAndSettle();
    expect(find.text('Detail pesanan'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone')),
      '08123456789',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkout-address')),
      'Jl. Raya Bogor No. 10',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-place-order')));
    await tester.pumpAndSettle();
    expect(find.text('Bukti transfer wajib diunggah.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('checkout-upload-proof')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-place-order')));
    await tester.pumpAndSettle();

    final placedOrder = repository.orders.first;
    expect(placedOrder.status, 'Dipesan');
    expect(placedOrder.customerName, 'Budi Santoso');
    expect(placedOrder.customerPhone, '08123456789');
    expect(placedOrder.deliveryAddress, 'Jl. Raya Bogor No. 10');
    expect(placedOrder.transferProofBytes, isNotNull);
    expect(repository.products.first.stock, 41);
    expect(find.text('Penerima & alamat pengiriman'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);
    expect(find.text('Jl. Raya Bogor No. 10'), findsOneWidget);

    await tester.pumpWidget(
      SihamaApp(key: const ValueKey('shop'), repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mitra Toko'));
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(placedOrder.id));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Penerima & alamat pengiriman'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);
    expect(find.text('Jl. Raya Bogor No. 10'), findsOneWidget);
    await tester.tap(find.text('Konfirmasi pesanan'));
    await tester.pumpAndSettle();

    expect(
      repository.orders
          .firstWhere((order) => order.id == placedOrder.id)
          .status,
      'Diproses',
    );
  });

  testWidgets('submitting a report adds it to history', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryRepository();
    repository.diagnosisReferences.add(
      const DiagnosisReference(
        slug: 'bercak-cekung',
        name: 'Bercak cekung pada buah',
        category: 'Penyakit / jamur',
        shortDescription: 'Gejala berupa bercak cekung pada buah.',
        affectedPlantParts: 'Buah',
        growthPhase: 'Fase pembungaan',
        firstSymptoms: 'Bercak cekung pada buah',
        typicalCauses: 'Infeksi jamur.',
        moreInfo: '',
      ),
    );
    await tester.pumpWidget(
      SihamaApp(
        repository: repository,
        imagePicker: () async =>
            ReportImage(name: 'plant.png', bytes: _samplePng),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Laporan Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Gejala yang terlihat (opsional)'), findsOneWidget);
    expect(find.text('Komoditas'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('report-symptom-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('symptom-search')),
      'cekung',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bercak cekung pada buah'), findsOneWidget);
    await tester.tap(find.text('Bercak cekung pada buah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan gejala (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ambil atau pilih foto'));
    await tester.pumpAndSettle();
    expect(find.text('plant.png'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('report-notes')),
      'Daun terlihat bercak.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('report-location')),
      'Petak Selatan',
    );
    final formList = find.byType(ListView).first;
    await tester.drag(formList, const Offset(0, -450));
    await tester.pumpAndSettle();
    final submitButton = find.text('Kirim laporan');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Riwayat laporan'), findsOneWidget);
    expect(find.text('Petak Selatan'), findsOneWidget);

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
    expect(find.text('Petak Revisi'), findsOneWidget);

    await tester.tap(find.byTooltip('Aksi laporan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus laporan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Petak Revisi'), findsNothing);
  });
}

final _samplePng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/rG0AAAAASUVORK5CYII=',
  ),
);

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

  final diagnosisReferences = <DiagnosisReference>[];

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

  final orders = <MarketOrder>[
    MarketOrder(
      id: 'P-2201',
      customerName: 'Budi Santoso',
      date: DateTime(2025, 5, 13),
      status: 'Diproses',
      items: const [
        MarketOrderItem(
          productId: 2,
          productName: 'Nordox 56 WP',
          quantity: 2,
          unitPrice: 72000,
        ),
      ],
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
  Future<List<DiagnosisReference>> getDiagnosisReferences() async =>
      List.of(diagnosisReferences);

  @override
  Future<void> createDiagnosisReference(DiagnosisReference reference) async =>
      diagnosisReferences.add(reference);

  @override
  Future<void> updateDiagnosisReference(DiagnosisReference reference) async {
    final index = diagnosisReferences.indexWhere(
      (item) => item.slug == reference.slug,
    );
    if (index < 0) throw StateError('Diagnosis reference not found');
    diagnosisReferences[index] = reference;
  }

  @override
  Future<void> deleteDiagnosisReference(String slug) async =>
      diagnosisReferences.removeWhere((item) => item.slug == slug);

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
  Future<List<MarketOrder>> getOrders() async => List.of(orders);

  @override
  Future<void> createOrder(MarketOrder order) async {
    for (final item in order.items) {
      final index = products.indexWhere(
        (product) => product.id == item.productId,
      );
      if (index < 0 || products[index].stock < item.quantity) {
        throw StateError('Insufficient stock');
      }
    }
    for (final item in order.items) {
      final index = products.indexWhere(
        (product) => product.id == item.productId,
      );
      final product = products[index];
      products[index] = MarketProduct(
        id: product.id,
        name: product.name,
        category: product.category,
        price: product.price,
        stock: product.stock - item.quantity,
      );
    }
    orders.insert(0, order);
  }

  @override
  Future<void> updateOrder(MarketOrder order) async {
    final index = orders.indexWhere((item) => item.id == order.id);
    if (index < 0) throw StateError('Order not found');
    final current = orders[index];
    if (current.status == order.status) return;
    final allowed = order.status == 'Dibatalkan'
        ? current.status == 'Dipesan' || current.status == 'Diproses'
        : switch (current.status) {
            'Dipesan' => order.status == 'Diproses',
            'Diproses' => order.status == 'Dikirim',
            'Dikirim' => order.status == 'Selesai',
            _ => false,
          };
    if (!allowed) throw StateError('Invalid order status transition');
    if (order.status == 'Dibatalkan') {
      for (final item in current.items) {
        final productIndex = products.indexWhere(
          (product) => product.id == item.productId,
        );
        if (productIndex < 0) continue;
        final product = products[productIndex];
        products[productIndex] = MarketProduct(
          id: product.id,
          name: product.name,
          category: product.category,
          price: product.price,
          stock: product.stock + item.quantity,
        );
      }
    }
    orders[index] = order;
  }

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
