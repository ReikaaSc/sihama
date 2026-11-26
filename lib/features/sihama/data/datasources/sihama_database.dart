import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'package:sihama/features/diagnosis/data/datasources/diagnosis_dataset.dart';
import 'package:sihama/shared/domain/repositories/sihama_repository.dart';
import 'package:sihama/shared/models/sihama_models.dart';

class SihamaDatabase implements SihamaRepository, SihamaChatRepository {
  SihamaDatabase();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final databasePath = path.join(await getDatabasesPath(), 'sihama.db');
    _database = await openDatabase(
      databasePath,
      version: 13,
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
            recommendation TEXT,
            diagnosis_reference_id INTEGER,
            adviser_id TEXT
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
        await db.execute(_diagnosisReferencesTable);
        await db.execute(_diagnosisReferencesIndex);
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
        await _createErdTables(db);

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
        await _seedDiagnosisReferences(db);
        await _syncDiseases(db);
        await _migrateReportSymptoms(db);
        await _migrateOrderItems(db);
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
        if (oldVersion < 9) {
          await db.execute(_diagnosisReferencesTable);
          await db.execute(_diagnosisReferencesIndex);
          await _seedDiagnosisReferences(db);
        } else if (oldVersion < 10) {
          await _migrateDiagnosisReferences(db);
        }
        if (oldVersion < 11) {
          await db.update(
            'diagnosis_references',
            {'name': 'Agas jamur (lalat hitam media tanam)'},
            where: 'slug = ?',
            whereArgs: ['trauermuecken'],
          );
        }
        if (oldVersion >= 4 && oldVersion < 12) {
          await db.execute(
            "ALTER TABLE market_orders ADD COLUMN customer_phone TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE market_orders ADD COLUMN delivery_address TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 13) {
          await db.execute(
            'ALTER TABLE reports ADD COLUMN diagnosis_reference_id INTEGER',
          );
          await db.execute('ALTER TABLE reports ADD COLUMN adviser_id TEXT');
          if (oldVersion >= 4) {
            await db.execute(
              'ALTER TABLE market_orders ADD COLUMN report_id TEXT',
            );
          }
          await _createErdTables(db);
          await _syncDiseases(db);
          await _migrateReportSymptoms(db);
          await _migrateOrderItems(db);
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
    final database = await _db;
    final rows = await database.query('reports', orderBy: 'date DESC');
    final reportSymptoms = await database.query('report_symptoms');
    final symptomIds = <String, List<int>>{};
    for (final row in reportSymptoms) {
      symptomIds
          .putIfAbsent(row['report_id']! as String, () => [])
          .add(row['symptom_id']! as int);
    }
    return rows.map((row) {
      final values = Map<String, Object?>.from(row)
        ..['symptom_ids'] = symptomIds[row['id']] ?? const <int>[];
      return CropReport.fromMap(values);
    }).toList();
  }

  @override
  Future<void> createReport(CropReport report) async {
    final database = await _db;
    final existing = await database.query(
      'reports',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [report.id],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await database.transaction((txn) async {
      await txn.insert('reports', _reportValues(report));
      for (final symptomId in report.symptomIds.toSet()) {
        await txn.insert('report_symptoms', {
          'report_id': report.id,
          'symptom_id': symptomId,
        });
      }
      await _addReportNotifications(
        txn,
        report,
        'Laporan baru menunggu peninjauan.',
      );
    });
  }

  @override
  Future<void> updateReport(CropReport report) async {
    final database = await _db;
    await database.transaction((txn) async {
      final changed = await txn.update(
        'reports',
        _reportValues(report),
        where: 'id = ?',
        whereArgs: [report.id],
      );
      _requireUpdated(changed, 'Laporan');
      await txn.delete(
        'report_symptoms',
        where: 'report_id = ?',
        whereArgs: [report.id],
      );
      for (final symptomId in report.symptomIds.toSet()) {
        await txn.insert('report_symptoms', {
          'report_id': report.id,
          'symptom_id': symptomId,
        });
      }
      await _addReportNotifications(
        txn,
        report,
        'Status laporan diperbarui: ${report.status}',
      );
    });
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
  Future<List<Symptom>> getSymptoms() async {
    final rows = await (await _db).query(
      'symptoms',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Symptom.fromMap).toList();
  }

  @override
  Future<List<DiagnosisReference>> getDiagnosisReferences() async {
    final database = await _db;
    final rows = await database.rawQuery('''
      SELECT diseases.id, diagnosis_references.*
      FROM diagnosis_references
      LEFT JOIN diseases ON diseases.legacy_slug = diagnosis_references.slug
      ORDER BY diagnosis_references.category COLLATE NOCASE,
               diagnosis_references.name COLLATE NOCASE
    ''');
    final medicineLinks = await database.query('disease_medicines');
    final medicineIds = <int, List<int>>{};
    for (final link in medicineLinks) {
      medicineIds
          .putIfAbsent(link['disease_id']! as int, () => [])
          .add(link['medicine_id']! as int);
    }
    final symptomLinks = await database.query('disease_symptoms');
    final symptomIds = <int, List<int>>{};
    for (final link in symptomLinks) {
      symptomIds
          .putIfAbsent(link['disease_id']! as int, () => [])
          .add(link['symptom_id']! as int);
    }
    return rows.map((row) {
      final values = Map<String, Object?>.from(row)
        ..['medicine_ids'] = medicineIds[row['id']! as int] ?? const <int>[]
        ..['symptom_ids'] = symptomIds[row['id']! as int] ?? const <int>[];
      return DiagnosisReference.fromMap(values);
    }).toList();
  }

  @override
  Future<void> createDiagnosisReference(DiagnosisReference reference) async {
    final database = await _db;
    await database.transaction((txn) async {
      await txn.insert('diagnosis_references', _diagnosisValues(reference));
      await _syncDisease(txn, reference);
    });
  }

  @override
  Future<void> updateDiagnosisReference(DiagnosisReference reference) async {
    final database = await _db;
    await database.transaction((txn) async {
      final changed = await txn.update(
        'diagnosis_references',
        _diagnosisValues(reference),
        where: 'slug = ?',
        whereArgs: [reference.slug],
      );
      _requireUpdated(changed, 'Referensi diagnosis');
      await _syncDisease(txn, reference);
    });
  }

  @override
  Future<void> deleteDiagnosisReference(String slug) async {
    final deleted = await (await _db).delete(
      'diagnosis_references',
      where: 'slug = ?',
      whereArgs: [slug],
    );
    _requireUpdated(deleted, 'Referensi diagnosis');
    await (await _db).delete(
      'diseases',
      where: 'legacy_slug = ?',
      whereArgs: [slug],
    );
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
    final database = await _db;
    final rows = await database.query('market_orders', orderBy: 'date DESC');
    final items = await database.query('order_items');
    final itemsByOrder = <String, List<MarketOrderItem>>{};
    for (final row in items) {
      itemsByOrder
          .putIfAbsent(row['order_id']! as String, () => [])
          .add(
            MarketOrderItem(
              productId: (row['medicine_id'] as int?) ?? 0,
              productName: row['product_name']! as String,
              quantity: row['quantity']! as int,
              unitPrice: row['unit_price']! as int,
            ),
          );
    }
    return rows.map((row) {
      final values = Map<String, Object?>.from(row);
      final normalizedItems = itemsByOrder[row['id']];
      if (normalizedItems != null && normalizedItems.isNotEmpty) {
        values['items'] = jsonEncode(
          normalizedItems.map((item) => item.toMap()).toList(),
        );
      }
      return MarketOrder.fromMap(values);
    }).toList();
  }

  @override
  Future<void> createOrder(MarketOrder order) async {
    if (order.items.isEmpty) {
      throw ArgumentError.value(order.items, 'order.items');
    }
    await (await _db).transaction((txn) async {
      final reportId = order.reportId;
      if (reportId == null) {
        throw ArgumentError.value(
          reportId,
          'order.reportId',
          'Pesanan harus terkait dengan laporan yang sudah ditinjau.',
        );
      }
      final reports = await txn.query(
        'reports',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [reportId],
        limit: 1,
      );
      if (reports.isEmpty || reports.single['status'] != 'Selesai Ditinjau') {
        throw StateError('Laporan terkait belum selesai ditinjau.');
      }
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
      for (final item in order.items) {
        await txn.insert('order_items', {
          'order_id': order.id,
          'medicine_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.total,
        });
      }
      await _addOrderNotifications(
        txn,
        order,
        'Pesanan baru menunggu diproses.',
      );
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
      await _addOrderNotifications(
        txn,
        order,
        'Status pesanan diperbarui: ${order.status}',
      );
    });
  }

  @override
  Future<FarmerProfile?> getProfile() async {
    final database = await _db;
    final rows = await database.query(
      'farmer_profiles',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final values = Map<String, Object?>.from(rows.first);
    final profileId = values['id'] as int;
    if (values['role'] == 'Penyuluh') {
      final details = await database.query(
        'adviser_profiles',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      if (details.isNotEmpty) {
        values['certification'] = details.first['certification_number'];
        values['institution'] = details.first['institution'];
      }
    } else if (values['role'] == 'Mitra Toko') {
      final details = await database.query(
        'shop_profiles',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      if (details.isNotEmpty) {
        values['shop_name'] = details.first['shop_name'];
        values['legality'] = details.first['legality'];
      }
    }
    return FarmerProfile.fromMap(values);
  }

  @override
  Future<void> createProfile(FarmerProfile profile) async {
    final database = await _db;
    await database.insert('farmer_profiles', _farmerProfileValues(profile));
    await _saveRoleProfile(database, profile);
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    final changed = await (await _db).update(
      'farmer_profiles',
      _farmerProfileValues(profile),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    _requireUpdated(changed, 'Profil');
    await _saveRoleProfile(await _db, profile);
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

  static Map<String, Object?> _farmerProfileValues(FarmerProfile profile) => {
    'id': profile.id,
    'name': profile.name,
    'role': profile.role,
    'region': profile.region,
    'phone': profile.phone,
    'address': profile.address,
  };

  static Future<void> _saveRoleProfile(
    DatabaseExecutor db,
    FarmerProfile profile,
  ) async {
    if (profile.role == 'Penyuluh') {
      await db.insert('adviser_profiles', {
        'profile_id': profile.id,
        'certification_number': profile.certification,
        'institution': profile.institution,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (profile.role == 'Mitra Toko') {
      await db.insert('shop_profiles', {
        'profile_id': profile.id,
        'shop_name': profile.shopName,
        'legality': profile.legality,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<List<SihamaNotification>> getNotifications() async {
    final database = await _db;
    final profiles = await database.query(
      'farmer_profiles',
      columns: ['role'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (profiles.isEmpty) return [];
    final recipientRole = switch (profiles.single['role']) {
      'Penyuluh' => 'penyuluh',
      'Mitra Toko' => 'mitra_toko',
      _ => 'pelapor',
    };
    final rows = await database.query(
      'notifications',
      where: 'recipient_role = ?',
      whereArgs: [recipientRole],
      orderBy: 'date DESC, id DESC',
    );
    return rows
        .map(
          (row) => SihamaNotification(
            id: row['id']! as int,
            title: row['title']! as String,
            message: row['message']! as String,
            date: DateTime.parse(row['date']! as String),
            reportId: row['report_id'] as String?,
            orderId: row['order_id'] as String?,
            isRead: (row['status_read']! as int) == 1,
          ),
        )
        .toList();
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final changed = await (await _db).update(
      'notifications',
      {'status_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _requireUpdated(changed, 'Notifikasi');
  }

  void _requireUpdated(int count, String entity) {
    if (count != 1) {
      throw StateError('$entity tidak ditemukan atau sudah dihapus.');
    }
  }

  static const _marketOrdersTable = '''
    CREATE TABLE market_orders (
      id TEXT PRIMARY KEY,
      report_id TEXT,
      customer_name TEXT NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL,
      items TEXT NOT NULL,
      total INTEGER NOT NULL CHECK (total >= 0),
      customer_phone TEXT NOT NULL DEFAULT '',
      delivery_address TEXT NOT NULL DEFAULT '',
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

  static const _diagnosisReferencesTable = '''
    CREATE TABLE diagnosis_references (
      slug TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      short_description TEXT NOT NULL DEFAULT '',
      affected_plant_parts TEXT NOT NULL DEFAULT '',
      growth_phase TEXT NOT NULL DEFAULT '',
      first_symptoms TEXT NOT NULL DEFAULT '',
      typical_causes TEXT NOT NULL DEFAULT '',
      more_info TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const _diagnosisReferencesIndex =
      'CREATE INDEX diagnosis_references_category_idx '
      'ON diagnosis_references(category)';

  static const _diseasesTable = '''
    CREATE TABLE diseases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      legacy_slug TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL UNIQUE,
      category TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      general_treatment TEXT NOT NULL DEFAULT '',
      affected_plant_parts TEXT NOT NULL DEFAULT '',
      growth_phase TEXT NOT NULL DEFAULT '',
      first_symptoms TEXT NOT NULL DEFAULT '',
      typical_causes TEXT NOT NULL DEFAULT '',
      more_info TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const _symptomsTable = '''
    CREATE TABLE symptoms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      icon_path TEXT
    )
  ''';

  static const _diseaseSymptomsTable = '''
    CREATE TABLE disease_symptoms (
      disease_id INTEGER NOT NULL REFERENCES diseases(id) ON DELETE CASCADE,
      symptom_id INTEGER NOT NULL REFERENCES symptoms(id) ON DELETE CASCADE,
      PRIMARY KEY (disease_id, symptom_id)
    )
  ''';

  static const _reportSymptomsTable = '''
    CREATE TABLE report_symptoms (
      report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
      symptom_id INTEGER NOT NULL REFERENCES symptoms(id) ON DELETE RESTRICT,
      PRIMARY KEY (report_id, symptom_id)
    )
  ''';

  static const _diseaseMedicinesTable = '''
    CREATE TABLE disease_medicines (
      disease_id INTEGER NOT NULL REFERENCES diseases(id) ON DELETE CASCADE,
      medicine_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      PRIMARY KEY (disease_id, medicine_id)
    )
  ''';

  static const _orderItemsTable = '''
    CREATE TABLE order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL REFERENCES market_orders(id) ON DELETE CASCADE,
      medicine_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      unit_price INTEGER NOT NULL CHECK (unit_price >= 0),
      subtotal INTEGER NOT NULL
    )
  ''';

  static const _adviserProfilesTable = '''
    CREATE TABLE adviser_profiles (
      profile_id INTEGER PRIMARY KEY REFERENCES farmer_profiles(id)
        ON DELETE CASCADE,
      certification_number TEXT NOT NULL DEFAULT '',
      institution TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const _shopProfilesTable = '''
    CREATE TABLE shop_profiles (
      profile_id INTEGER PRIMARY KEY REFERENCES farmer_profiles(id)
        ON DELETE CASCADE,
      shop_name TEXT NOT NULL DEFAULT '',
      legality TEXT NOT NULL DEFAULT ''
    )
  ''';

  static const _notificationsTable = '''
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recipient_role TEXT NOT NULL,
      report_id TEXT REFERENCES reports(id) ON DELETE CASCADE,
      order_id TEXT REFERENCES market_orders(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      date TEXT NOT NULL,
      status_read INTEGER NOT NULL DEFAULT 0 CHECK (status_read IN (0, 1)),
      CHECK (report_id IS NOT NULL OR order_id IS NOT NULL)
    )
  ''';

  static Future<void> _createErdTables(DatabaseExecutor db) async {
    await db.execute(_diseasesTable);
    await db.execute(_symptomsTable);
    await db.execute(_diseaseSymptomsTable);
    await db.execute(_reportSymptomsTable);
    await db.execute(_diseaseMedicinesTable);
    await db.execute(_orderItemsTable);
    await db.execute(_adviserProfilesTable);
    await db.execute(_shopProfilesTable);
    await db.execute(_notificationsTable);
  }

  static Map<String, Object?> _reportValues(CropReport report) =>
      report.toMap()..remove('symptom_ids');

  static Map<String, Object?> _diagnosisValues(DiagnosisReference reference) =>
      reference.toMap()
        ..remove('id')
        ..remove('symptom_ids')
        ..remove('medicine_ids');

  static Future<void> _syncDiseases(DatabaseExecutor db) async {
    final rows = await db.query('diagnosis_references');
    for (final row in rows) {
      await _syncDisease(db, DiagnosisReference.fromMap(row));
    }
  }

  static Future<void> _syncDisease(
    DatabaseExecutor db,
    DiagnosisReference reference,
  ) async {
    final diseaseValues = {
      'legacy_slug': reference.slug,
      'name': reference.name,
      'category': reference.category,
      'description': reference.shortDescription,
      'general_treatment': reference.moreInfo,
      'affected_plant_parts': reference.affectedPlantParts,
      'growth_phase': reference.growthPhase,
      'first_symptoms': reference.firstSymptoms,
      'typical_causes': reference.typicalCauses,
      'more_info': reference.moreInfo,
    };
    final diseaseRows = await db.query(
      'diseases',
      columns: ['id', 'legacy_slug'],
      where: 'legacy_slug = ?',
      whereArgs: [reference.slug],
      limit: 1,
    );
    late final int diseaseId;
    if (diseaseRows.isEmpty) {
      diseaseId = await db.insert('diseases', diseaseValues);
    } else {
      diseaseId = diseaseRows.single['id']! as int;
      await db.update(
        'diseases',
        diseaseValues,
        where: 'id = ?',
        whereArgs: [diseaseId],
      );
    }
    await db.delete(
      'disease_symptoms',
      where: 'disease_id = ?',
      whereArgs: [diseaseId],
    );
    for (final symptomName in _splitSymptoms(reference.firstSymptoms)) {
      await db.insert('symptoms', {
        'name': symptomName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final symptomRows = await db.query(
        'symptoms',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [symptomName],
        limit: 1,
      );
      await db.insert('disease_symptoms', {
        'disease_id': diseaseId,
        'symptom_id': symptomRows.single['id'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.delete(
      'disease_medicines',
      where: 'disease_id = ?',
      whereArgs: [diseaseId],
    );
    for (final medicineId in reference.medicineIds.toSet()) {
      await db.insert('disease_medicines', {
        'disease_id': diseaseId,
        'medicine_id': medicineId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static List<String> _splitSymptoms(String value) => value
      .split(RegExp(r'[;\n,]+'))
      .map((symptom) => symptom.trim())
      .where((symptom) => symptom.isNotEmpty)
      .toSet()
      .toList();

  static Future<void> _migrateReportSymptoms(DatabaseExecutor db) async {
    final reports = await db.query('reports');
    final symptoms = await db.query('symptoms');
    final symptomIds = {
      for (final symptom in symptoms)
        (symptom['name']! as String).toLowerCase(): symptom['id']! as int,
    };
    for (final report in reports) {
      for (final name in _splitSymptoms(report['description']! as String)) {
        final symptomId = symptomIds[name.toLowerCase()];
        if (symptomId == null) continue;
        await db.insert('report_symptoms', {
          'report_id': report['id'],
          'symptom_id': symptomId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  static Future<void> _migrateOrderItems(DatabaseExecutor db) async {
    final orders = await db.query('market_orders');
    final products = await db.query('products', columns: ['id']);
    final productIds = products.map((row) => row['id']! as int).toSet();
    for (final row in orders) {
      final order = MarketOrder.fromMap(Map<String, Object?>.from(row));
      for (final item in order.items) {
        await db.insert('order_items', {
          'order_id': order.id,
          'medicine_id': productIds.contains(item.productId)
              ? item.productId
              : null,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.total,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  static Future<void> _addReportNotifications(
    DatabaseExecutor db,
    CropReport report,
    String message,
  ) async {
    final title = 'Laporan ${report.id}';
    await db.insert('notifications', {
      'recipient_role': 'pelapor',
      'report_id': report.id,
      'title': title,
      'message': message,
      'date': DateTime.now().toIso8601String(),
    });
    await db.insert('notifications', {
      'recipient_role': 'penyuluh',
      'report_id': report.id,
      'title': title,
      'message': message,
      'date': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> _addOrderNotifications(
    DatabaseExecutor db,
    MarketOrder order,
    String message,
  ) async {
    final title = 'Pesanan ${order.id}';
    for (final role in ['pelapor', 'mitra_toko']) {
      await db.insert('notifications', {
        'recipient_role': role,
        'order_id': order.id,
        'title': title,
        'message': message,
        'date': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<void> _seedDiagnosisReferences(
    DatabaseExecutor executor,
  ) async {
    final source = await rootBundle.loadString(DiagnosisDataset.assetPath);
    final references = DiagnosisDataset.parse(source);
    final batch = executor.batch();
    for (final reference in references) {
      batch.insert(
        'diagnosis_references',
        reference.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _migrateDiagnosisReferences(Database db) async {
    final oldRows = await db.query('diagnosis_references');
    final source = await rootBundle.loadString(DiagnosisDataset.assetPath);
    final references = DiagnosisDataset.parse(source);
    final translations = {
      for (final reference in references) reference.slug: reference,
    };

    await db.execute('DROP INDEX IF EXISTS diagnosis_references_category_idx');
    await db.execute(
      'ALTER TABLE diagnosis_references RENAME TO diagnosis_references_legacy',
    );
    await db.execute(_diagnosisReferencesTable);
    await db.execute(_diagnosisReferencesIndex);

    final batch = db.batch();
    for (final row in oldRows) {
      final slug = row['slug']! as String;
      final translated = translations.remove(slug);
      batch.insert(
        'diagnosis_references',
        (translated ?? _referenceFromLegacyMap(row)).toMap(),
      );
    }
    for (final reference in translations.values) {
      batch.insert('diagnosis_references', reference.toMap());
    }
    await batch.commit(noResult: true);
    await db.execute('DROP TABLE diagnosis_references_legacy');
  }

  static DiagnosisReference _referenceFromLegacyMap(Map<String, Object?> map) {
    final englishName = (map['name_en'] as String?) ?? '';
    return DiagnosisReference(
      slug: map['slug']! as String,
      name: englishName.isEmpty
          ? (map['name_de'] as String?) ?? ''
          : englishName,
      category: _translateLegacyCategory(map['category']! as String),
      shortDescription: map['short_description']! as String,
      affectedPlantParts: map['affected_plant_parts']! as String,
      growthPhase: map['growth_phase']! as String,
      firstSymptoms: map['first_symptoms']! as String,
      typicalCauses: map['typical_causes']! as String,
      moreInfo: map['more_info']! as String,
    );
  }

  static String _translateLegacyCategory(String category) => switch (category) {
    'Krankheiten / Pilzbefall' => 'Penyakit / jamur',
    'Schaedlinge' => 'Hama',
    'Naehrstoffmangel' => 'Kekurangan nutrisi',
    'Naehrstoffueberschuss' => 'Kelebihan nutrisi',
    'Bewaesserungsprobleme' => 'Masalah pengairan',
    'Wurzelprobleme' => 'Masalah akar',
    'Umweltstress' => 'Stres lingkungan',
    'Temperatur / Luftfeuchtigkeit / VPD' => 'Suhu / kelembapan / VPD',
    'pH-/EC-Probleme' => 'Masalah pH / EC',
    'Lichtstress' => 'Stres cahaya',
    'Bluete-/Ernteprobleme' => 'Masalah pembungaan / panen',
    'Wachstums- und Trainingsprobleme' => 'Masalah pertumbuhan',
    _ => category,
  };

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
