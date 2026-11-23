import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'sihama_repository.dart';

class SihamaDatabase implements SihamaRepository {
  SihamaDatabase();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final databasePath = path.join(await getDatabasesPath(), 'sihama.db');
    _database = await openDatabase(
      databasePath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            crop TEXT NOT NULL,
            location TEXT NOT NULL,
            description TEXT NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price INTEGER NOT NULL CHECK (price >= 0),
            stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)
          )
        ''');
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
        await db.execute('''
          CREATE TABLE local_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer TEXT NOT NULL,
            products TEXT NOT NULL,
            item_count INTEGER NOT NULL CHECK (item_count > 0),
            total INTEGER NOT NULL CHECK (total >= 0),
            date TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE local_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT NOT NULL,
            body TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');

        final batch = db.batch();
        batch.insert('reports', {
          'id': 'L-1051',
          'crop': 'Cabai',
          'location': 'Petak Selatan',
          'description': 'Bercak gelap terlihat pada buah cabai.',
          'date': DateTime(2025, 5, 15, 8, 24).toIso8601String(),
          'status': 'Diajukan',
        });
        batch.insert('reports', {
          'id': 'L-1042',
          'crop': 'Padi',
          'location': 'Petak Utara',
          'description': 'Daun menguning di beberapa bagian.',
          'date': DateTime(2025, 5, 12, 8, 24).toIso8601String(),
          'status': 'Selesai Ditinjau',
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
          await db.execute('''
            CREATE TABLE local_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer TEXT NOT NULL,
              products TEXT NOT NULL,
              item_count INTEGER NOT NULL CHECK (item_count > 0),
              total INTEGER NOT NULL CHECK (total >= 0),
              date TEXT NOT NULL,
              status TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE local_messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sender TEXT NOT NULL,
              body TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');
          await db.insert(
            'reports',
            {
              'id': 'L-1042',
              'crop': 'Padi',
              'location': 'Petak Utara',
              'description': 'Daun menguning di beberapa bagian.',
              'date': DateTime(2025, 5, 12, 8, 24).toIso8601String(),
              'status': 'Selesai Ditinjau',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
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

  Future<int> createLocalOrder(LocalOrder order) async =>
      (await _db).insert('local_orders', order.toMap());

  Future<int> checkoutLocalOrder(
    LocalOrder order,
    Map<int, int> productQuantities,
  ) async {
    final database = await _db;
    return database.transaction((transaction) async {
      for (final entry in productQuantities.entries) {
        final rows = await transaction.query(
          'products',
          columns: ['stock'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty || (rows.first['stock']! as int) < entry.value) {
          throw StateError('Stok produk tidak mencukupi. Perbarui keranjang Anda.');
        }
        await transaction.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [entry.value, entry.key],
        );
      }
      return transaction.insert('local_orders', order.toMap());
    });
  }

  Future<List<LocalOrder>> getLocalOrders() async {
    final rows = await (await _db).query('local_orders', orderBy: 'date DESC');
    return rows.map(LocalOrder.fromMap).toList();
  }

  Future<void> updateLocalOrderStatus(int id, String status) async {
    final changed = await (await _db).update(
      'local_orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(changed, 'Pesanan');
  }

  Future<void> createLocalMessage(LocalMessage message) async {
    await (await _db).insert('local_messages', message.toMap());
  }

  Future<List<LocalMessage>> getLocalMessages() async {
    final rows = await (await _db).query('local_messages', orderBy: 'date ASC');
    return rows.map(LocalMessage.fromMap).toList();
  }

  void _requireUpdated(int count, String entity) {
    if (count != 1) {
      throw StateError('$entity tidak ditemukan atau sudah dihapus.');
    }
  }
}
