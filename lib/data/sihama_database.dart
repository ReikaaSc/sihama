import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'sihama_repository.dart';

class SihamaDatabase implements SihamaRepository, SihamaChatRepository {
  SihamaDatabase();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final databasePath = path.join(await getDatabasesPath(), 'sihama.db');
    _database = await openDatabase(
      databasePath,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            crop TEXT NOT NULL,
            location TEXT NOT NULL,
            description TEXT NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            photo_bytes BLOB,
            diagnosis TEXT,
            recommendation TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price INTEGER NOT NULL CHECK (price >= 0),
            stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
            description TEXT NOT NULL DEFAULT '',
            photo_bytes BLOB
          )
        ''');
        await db.execute(_marketOrdersTable);
        await db.execute(_chatMessagesTable);
        await db.execute('''
          CREATE TABLE farmer_profiles (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            region TEXT NOT NULL,
            phone TEXT NOT NULL,
            address TEXT NOT NULL
          )
        ''');

        final batch = db.batch();
        batch.insert('reports', {
          'id': 'SIH-240618',
          'crop': 'Padi sawah',
          'location': 'Petak Utara',
          'description': 'Daun menguning di beberapa bagian.',
          'date': DateTime(2025, 6, 18, 8, 24).toIso8601String(),
          'status': 'Diajukan',
        });
        batch.insert('products', {
          'name': 'Kocide 54 WDG',
          'category': 'Bakterisida',
          'price': 85000,
          'stock': 42,
        });
        batch.insert('products', {
          'name': 'Nordox 56 WP',
          'category': 'Bakterisida',
          'price': 72000,
          'stock': 4,
        });
        batch.insert('products', {
          'name': 'Score 250 EC',
          'category': 'Fungisida',
          'price': 142000,
          'stock': 18,
        });
        batch.insert('products', {
          'name': 'Dithane M-45 80 WP',
          'category': 'Fungisida',
          'price': 68000,
          'stock': 3,
        });
        _addSampleOrders(batch);
        _addSampleChatMessages(batch);
        batch.insert('farmer_profiles', {
          'id': 1,
          'name': 'Budi Santoso',
          'role': 'Petani',
          'region': 'Kabupaten Bogor',
          'phone': '',
          'address': '',
        });
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)',
          );
          await db.update(
            'farmer_profiles',
            {'name': 'Budi Santoso'},
            where: 'id = ? AND name = ?',
            whereArgs: [1, 'Pak Budi'],
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE reports ADD COLUMN photo_bytes BLOB');
        }
        if (oldVersion < 4) {
          await db.execute(_marketOrdersTable);
          final batch = db.batch();
          _addSampleOrders(batch);
          await batch.commit(noResult: true);
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE reports ADD COLUMN diagnosis TEXT');
          await db.execute(
            'ALTER TABLE reports ADD COLUMN recommendation TEXT',
          );
        }
        if (oldVersion >= 4 && oldVersion < 6) {
          await db.execute(
            'ALTER TABLE market_orders ADD COLUMN transfer_proof_bytes BLOB',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            "ALTER TABLE products ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('ALTER TABLE products ADD COLUMN photo_bytes BLOB');
        }
        if (oldVersion < 8) {
          await db.execute(_chatMessagesTable);
          final batch = db.batch();
          _addSampleChatMessages(batch);
          await batch.commit(noResult: true);
        }
      },
    );
    return _database!;
  }

  @override
  Future<void> initialize() async {
    await _db;
  }

  @override
  Future<List<CropReport>> getReports() async {
    final rows = await (await _db).query('reports', orderBy: 'date DESC');
    return rows.map(CropReport.fromMap).toList();
  }

  @override
  Future<void> createReport(CropReport report) async {
    await (await _db).insert('reports', report.toMap());
  }

  @override
  Future<void> updateReport(CropReport report) async {
    final changed = await (await _db).update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
    _requireUpdated(changed, 'Laporan');
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String reportId) async {
    final rows = await (await _db).query(
      'chat_messages',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'sent_at ASC, id ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  @override
  Future<void> addChatMessage(ChatMessage message) async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    await (await _db).insert(
      'chat_messages',
      ChatMessage(
        reportId: message.reportId,
        senderRole: message.senderRole,
        senderName: message.senderName,
        text: text,
        sentAt: message.sentAt,
      ).toMap(),
    );
  }

  @override
  Future<void> deleteReport(String id) async {
    final deleted = await (await _db).delete(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(deleted, 'Laporan');
  }

  @override
  Future<List<MarketProduct>> getProducts() async {
    final rows = await (await _db).query(
      'products',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(MarketProduct.fromMap).toList();
  }

  @override
  Future<int> createProduct(MarketProduct product) async {
    return (await _db).insert('products', product.toMap());
  }

  @override
  Future<void> updateProduct(MarketProduct product) async {
    final id = product.id;
    if (id == null) throw ArgumentError.value(id, 'product.id');
    final changed = await (await _db).update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(changed, 'Produk');
  }

  @override
  Future<void> deleteProduct(int id) async {
    final deleted = await (await _db).delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(deleted, 'Produk');
  }

  @override
  Future<List<MarketOrder>> getOrders() async {
    final rows = await (await _db).query('market_orders', orderBy: 'date DESC');
    return rows.map(MarketOrder.fromMap).toList();
  }

  @override
  Future<void> createOrder(MarketOrder order) async {
    if (order.items.isEmpty) {
      throw ArgumentError.value(order.items, 'order.items');
    }
    await (await _db).transaction((txn) async {
      for (final item in order.items) {
        if (item.quantity <= 0) {
          throw ArgumentError.value(item.quantity, 'item.quantity');
        }
        final changed = await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
          [item.quantity, item.productId, item.quantity],
        );
        if (changed != 1) {
          throw StateError(
            'Stok ${item.productName} tidak mencukupi untuk pesanan.',
          );
        }
      }
      await txn.insert('market_orders', order.toMap());
    });
  }

  @override
  Future<void> updateOrder(MarketOrder order) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'market_orders',
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Pesanan tidak ditemukan.');
      final current = MarketOrder.fromMap(rows.first.cast<String, Object?>());
      if (current.status == order.status) return;
      if (!_canTransitionOrder(current.status, order.status)) {
        throw StateError(
          'Status pesanan tidak dapat diubah dari ${current.status} menjadi ${order.status}.',
        );
      }
      if (order.status == 'Dibatalkan' && current.status != 'Dibatalkan') {
        for (final item in current.items) {
          await txn.rawUpdate(
            'UPDATE products SET stock = stock + ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }
      final changed = await txn.update(
        'market_orders',
        order.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );
      _requireUpdated(changed, 'Pesanan');
    });
  }

  @override
  Future<FarmerProfile?> getProfile() async {
    final rows = await (await _db).query(
      'farmer_profiles',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : FarmerProfile.fromMap(rows.first);
  }

  @override
  Future<void> createProfile(FarmerProfile profile) async {
    await (await _db).insert('farmer_profiles', profile.toMap());
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    final changed = await (await _db).update(
      'farmer_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    _requireUpdated(changed, 'Profil');
  }

  @override
  Future<void> deleteProfile(int id) async {
    final deleted = await (await _db).delete(
      'farmer_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(deleted, 'Profil');
  }

  void _requireUpdated(int count, String entity) {
    if (count != 1) {
      throw StateError('$entity tidak ditemukan atau sudah dihapus.');
    }
  }

  static const _marketOrdersTable = '''
    CREATE TABLE market_orders (
      id TEXT PRIMARY KEY,
      customer_name TEXT NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL,
      items TEXT NOT NULL,
      total INTEGER NOT NULL CHECK (total >= 0),
      transfer_proof_bytes BLOB
    )
  ''';

  static const _chatMessagesTable = '''
    CREATE TABLE chat_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      report_id TEXT NOT NULL,
      sender_role TEXT NOT NULL,
      sender_name TEXT NOT NULL,
      message TEXT NOT NULL,
      sent_at TEXT NOT NULL
    )
  ''';

  static void _addSampleChatMessages(Batch batch) {
    batch.insert('chat_messages', {
      'report_id': 'SIH-240618',
      'sender_role': 'penyuluh',
      'sender_name': 'Ir. Siti Rahmawati',
      'message': 'Daun menguning bisa disebabkan hawar. Apakah bercaknya meluas setelah hujan?',
      'sent_at': DateTime(2025, 6, 18, 9, 20).toIso8601String(),
    });
    batch.insert('chat_messages', {
      'report_id': 'SIH-240618',
      'sender_role': 'pelapor',
      'sender_name': 'Budi Santoso',
      'message': 'Belum meluas, Bu. Saya sudah mengurangi pupuk urea.',
      'sent_at': DateTime(2025, 6, 18, 9, 32).toIso8601String(),
    });
    batch.insert('chat_messages', {
      'report_id': 'SIH-240618',
      'sender_role': 'penyuluh',
      'sender_name': 'Ir. Siti Rahmawati',
      'message': 'Baik. Pantau kondisi tanaman dan kirim kabar lagi jika bercak bertambah.',
      'sent_at': DateTime(2025, 6, 18, 9, 45).toIso8601String(),
    });
  }

  static void _addSampleOrders(Batch batch) {
    final samples = [
      (
        'P-2198',
        'Hendra',
        DateTime(2025, 5, 10),
        'Selesai',
        [
          {
            'product_id': 4,
            'product_name': 'Dithane M-45 80 WP',
            'quantity': 1,
            'unit_price': 68000,
          },
        ],
        68000,
      ),
      (
        'P-2205',
        'Wahyuni',
        DateTime(2025, 5, 15),
        'Dikirim',
        [
          {
            'product_id': 1,
            'product_name': 'Kocide 54 WDG',
            'quantity': 3,
            'unit_price': 85000,
          },
        ],
        255000,
      ),
      (
        'P-2207',
        'Sutrisno',
        DateTime(2025, 5, 16),
        'Dipesan',
        [
          {
            'product_id': 3,
            'product_name': 'Score 250 EC',
            'quantity': 1,
            'unit_price': 142000,
          },
          {
            'product_id': 4,
            'product_name': 'Dithane M-45 80 WP',
            'quantity': 2,
            'unit_price': 68000,
          },
        ],
        278000,
      ),
      (
        'P-2201',
        'Budi Santoso',
        DateTime(2025, 5, 13),
        'Diproses',
        [
          {
            'product_id': 2,
            'product_name': 'Nordox 56 WP',
            'quantity': 2,
            'unit_price': 72000,
          },
        ],
        144000,
      ),
    ];
    for (final sample in samples) {
      batch.insert('market_orders', {
        'id': sample.$1,
        'customer_name': sample.$2,
        'date': sample.$3.toIso8601String(),
        'status': sample.$4,
        'items': jsonEncode(sample.$5),
        'total': sample.$6,
      });
    }
  }

  static bool _canTransitionOrder(String current, String next) {
    if (current == next) return true;
    if (next == 'Dibatalkan') {
      return current == 'Dipesan' || current == 'Diproses';
    }
    return switch (current) {
      'Dipesan' => next == 'Diproses',
      'Diproses' => next == 'Dikirim',
      'Dikirim' => next == 'Selesai',
      _ => false,
    };
  }
}
