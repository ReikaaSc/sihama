import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sihama/shared/domain/repositories/sihama_repository.dart';
import 'package:sihama/shared/models/sihama_models.dart';

class SupabaseSihamaRepository
    implements SihamaRepository, SihamaChatRepository {
  SupabaseSihamaRepository(this._client);

  static const _bucket = 'sihama-media';
  final SupabaseClient _client;
  final Map<String, Uint8List> _downloadedMedia = {};

  void clearCachedMedia() => _downloadedMedia.clear();

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Masuk ke akun SIHAMA sebelum mengakses data.');
    }
    return userId;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<CropReport>> getReports() async {
    final rows = await _client
        .from('reports')
        .select('*, report_symptoms(symptom_id)')
        .order('date', ascending: false);
    return Future.wait(
      rows.map((row) async {
        final values = Map<String, Object?>.from(row);
        final linkedSymptoms =
            values.remove('report_symptoms') as List<dynamic>;
        values['diagnosis_reference_id'] = values.remove('disease_id');
        values['symptom_ids'] = linkedSymptoms
            .map((link) => (link as Map<String, dynamic>)['symptom_id'] as int)
            .toList();
        final photoPath = values.remove('photo_path') as String?;
        values['photo_bytes'] = await _download(photoPath);
        return CropReport.fromMap(values);
      }),
    );
  }

  @override
  Future<void> createReport(CropReport report) async {
    final existing = await _client
        .from('reports')
        .select('owner_id')
        .eq('id', report.id)
        .maybeSingle();
    if (existing != null) {
      if (existing['owner_id'] == _userId) return;
      throw StateError('ID laporan sudah digunakan.');
    }

    final photoPath = report.photoBytes == null
        ? null
        : _mediaPath('reports', report.id, report.photoBytes!);
    if (photoPath != null) {
      await _upload(photoPath, report.photoBytes!);
    }
    final values = _reportValues(report)
      ..['owner_id'] = _userId
      ..['photo_path'] = photoPath;
    try {
      await _client.from('reports').insert(values);
      await _syncReportSymptoms(report.id, report.symptomIds);
    } catch (error, stackTrace) {
      final duplicate = await _client
          .from('reports')
          .select('owner_id')
          .eq('id', report.id)
          .maybeSingle();
      if (duplicate != null && duplicate['owner_id'] == _userId) {
        await _syncReportSymptoms(report.id, report.symptomIds);
        return;
      }
      await _removeAfterFailure(photoPath, error, stackTrace);
    }
  }

  @override
  Future<void> updateReport(CropReport report) async {
    final existing = await _client
        .from('reports')
        .select('photo_path, owner_id')
        .eq('id', report.id)
        .maybeSingle();
    if (existing == null) throw StateError('Laporan tidak ditemukan.');
    final oldPhotoPath = existing['photo_path'] as String?;
    var photoPath = oldPhotoPath;
    final isOwner = existing['owner_id'] == _userId;
    String? uploadedPath;
    if (report.photoBytes != null && isOwner) {
      uploadedPath = _mediaPath(
        'reports',
        '${report.id}-${DateTime.now().microsecondsSinceEpoch}',
        report.photoBytes!,
      );
      await _upload(uploadedPath, report.photoBytes!);
      photoPath = uploadedPath;
    }
    final values = _reportValues(report)
      ..['owner_id'] = existing['owner_id']
      ..['adviser_id'] = isOwner ? report.adviserId : _userId
      ..['photo_path'] = photoPath;
    try {
      final updated = await _client
          .from('reports')
          .update(values)
          .eq('id', report.id)
          .select('id');
      if (updated.isEmpty) throw StateError('Laporan tidak ditemukan.');
      await _syncReportSymptoms(report.id, report.symptomIds);
    } catch (error, stackTrace) {
      await _removeAfterFailure(uploadedPath, error, stackTrace);
    }
    if (uploadedPath != null) await _remove(oldPhotoPath);
  }

  @override
  Future<void> deleteReport(String id) async {
    final existing = await _client
        .from('reports')
        .select('photo_path')
        .eq('id', id)
        .maybeSingle();
    if (existing == null) throw StateError('Laporan tidak ditemukan.');
    final photoPath = existing['photo_path'] as String?;
    final deleted = await _client
        .from('reports')
        .delete()
        .eq('id', id)
        .select('id');
    if (deleted.isEmpty) throw StateError('Laporan tidak ditemukan.');
    await _remove(photoPath);
  }

  @override
  Future<List<DiagnosisReference>> getDiagnosisReferences() async {
    final rows = await _client
        .from('diseases')
        .select(
          'id, legacy_slug, name, category, description, affected_plant_parts, growth_phase, first_symptoms, typical_causes, more_info, disease_symptoms(symptom_id), disease_medicines(medicine_id)',
        )
        .order('category')
        .order('name');
    return rows.map((row) {
      final values = Map<String, Object?>.from(row)
        ..['slug'] = row['legacy_slug']
        ..['short_description'] = row['description'];
      final medicineLinks = values.remove('disease_medicines') as List<dynamic>;
      final symptomLinks = values.remove('disease_symptoms') as List<dynamic>;
      values['symptom_ids'] = symptomLinks
          .map((link) => (link as Map<String, dynamic>)['symptom_id'] as int)
          .toList();
      values['medicine_ids'] = medicineLinks
          .map((link) => (link as Map<String, dynamic>)['medicine_id'] as int)
          .toList();
      return DiagnosisReference.fromMap(values);
    }).toList();
  }

  @override
  Future<List<Symptom>> getSymptoms() async {
    final rows = await _client
        .from('symptoms')
        .select('id, name, icon_path')
        .order('name');
    return rows
        .map((row) => Symptom.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<void> createDiagnosisReference(DiagnosisReference reference) async {
    final inserted = await _client
        .from('diseases')
        .insert(_diseaseValues(reference))
        .select('id')
        .single();
    final diseaseId = inserted['id'] as int;
    await _syncDiseaseSymptoms(diseaseId, reference);
    await _syncDiseaseMedicines(diseaseId, reference.medicineIds);
  }

  @override
  Future<void> updateDiagnosisReference(DiagnosisReference reference) async {
    final updated = await _client
        .from('diseases')
        .update(_diseaseValues(reference)..remove('legacy_slug'))
        .eq('legacy_slug', reference.slug)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('Referensi diagnosis tidak ditemukan.');
    }
    final diseaseId = updated.single['id'] as int;
    await _syncDiseaseSymptoms(diseaseId, reference);
    await _syncDiseaseMedicines(diseaseId, reference.medicineIds);
  }

  @override
  Future<void> deleteDiagnosisReference(String slug) async {
    final deleted = await _client
        .from('diseases')
        .delete()
        .eq('legacy_slug', slug)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('Referensi diagnosis tidak ditemukan.');
    }
  }

  @override
  Future<List<MarketProduct>> getProducts() async {
    final rows = await _client.from('products').select().order('name');
    return Future.wait(
      rows.map((row) async {
        final values = Map<String, Object?>.from(row);
        final photoPath = values.remove('photo_path') as String?;
        values['photo_bytes'] = await _download(photoPath);
        return MarketProduct.fromMap(values);
      }),
    );
  }

  @override
  Future<int> createProduct(MarketProduct product) async {
    final values = product.toMap()
      ..remove('photo_bytes')
      ..['created_by'] = _userId;
    final inserted = await _client
        .from('products')
        .insert(values)
        .select('id')
        .single();
    final id = inserted['id'] as int;
    final bytes = product.photoBytes;
    if (bytes == null) return id;

    final photoPath = _mediaPath('products', '$id', bytes);
    try {
      await _upload(photoPath, bytes);
      final updated = await _client
          .from('products')
          .update({'photo_path': photoPath})
          .eq('id', id)
          .select('id');
      if (updated.isEmpty) throw StateError('Produk tidak ditemukan.');
    } catch (error, stackTrace) {
      try {
        await _remove(photoPath);
        await _client.from('products').delete().eq('id', id);
      } catch (cleanupError) {
        throw StateError(
          'Penambahan foto produk gagal: $error. Pembersihan juga gagal: $cleanupError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return id;
  }

  @override
  Future<void> updateProduct(MarketProduct product) async {
    final id = product.id;
    if (id == null) throw ArgumentError.value(id, 'product.id');
    final existing = await _client
        .from('products')
        .select('photo_path')
        .eq('id', id)
        .maybeSingle();
    if (existing == null) throw StateError('Produk tidak ditemukan.');

    final oldPhotoPath = existing['photo_path'] as String?;
    var photoPath = oldPhotoPath;
    final bytes = product.photoBytes;
    String? uploadedPath;
    if (bytes != null) {
      uploadedPath = _mediaPath(
        'products',
        '$id-${DateTime.now().microsecondsSinceEpoch}',
        bytes,
      );
      await _upload(uploadedPath, bytes);
      photoPath = uploadedPath;
    }
    final values = product.toMap()
      ..remove('id')
      ..remove('photo_bytes')
      ..['photo_path'] = photoPath;
    try {
      final updated = await _client
          .from('products')
          .update(values)
          .eq('id', id)
          .select('id');
      if (updated.isEmpty) throw StateError('Produk tidak ditemukan.');
    } catch (error, stackTrace) {
      await _removeAfterFailure(uploadedPath, error, stackTrace);
    }
    if (uploadedPath != null) await _remove(oldPhotoPath);
  }

  @override
  Future<void> deleteProduct(int id) async {
    final existing = await _client
        .from('products')
        .select('photo_path')
        .eq('id', id)
        .maybeSingle();
    if (existing == null) throw StateError('Produk tidak ditemukan.');
    final photoPath = existing['photo_path'] as String?;
    final deleted = await _client
        .from('products')
        .delete()
        .eq('id', id)
        .select('id');
    if (deleted.isEmpty) throw StateError('Produk tidak ditemukan.');
    await _remove(photoPath);
  }

  @override
  Future<List<MarketOrder>> getOrders() async {
    final rows = await _client
        .from('market_orders')
        .select(
          '*, order_items(id, medicine_id, product_name, quantity, unit_price)',
        )
        .order('date', ascending: false);
    return Future.wait(
      rows.map((row) async {
        final values = Map<String, Object?>.from(row);
        final orderItems = values.remove('order_items') as List<dynamic>;
        final items = orderItems.map((item) {
          final row = item as Map<String, dynamic>;
          return {
            'product_id': row['medicine_id'] ?? 0,
            'product_name': row['product_name'],
            'quantity': row['quantity'],
            'unit_price': row['unit_price'],
          };
        }).toList();
        values['items'] = jsonEncode(items.isEmpty ? values['items'] : items);
        final proofPath = values.remove('transfer_proof_path') as String?;
        values['transfer_proof_bytes'] = await _download(proofPath);
        return MarketOrder.fromMap(values);
      }),
    );
  }

  @override
  Future<void> createOrder(MarketOrder order) async {
    if (order.items.isEmpty) {
      throw ArgumentError.value(order.items, 'order.items');
    }
    final proofBytes = order.transferProofBytes;
    if (proofBytes == null) {
      throw ArgumentError.value(
        proofBytes,
        'order.transferProofBytes',
        'Bukti transfer wajib diunggah.',
      );
    }
    final proofPath = _mediaPath('orders', order.id, proofBytes);
    await _upload(proofPath, proofBytes);
    try {
      await _client.rpc(
        'place_market_order',
        params: {
          'p_order_id': order.id,
          'p_report_id': order.reportId,
          'p_customer_name': order.customerName,
          'p_customer_phone': order.customerPhone,
          'p_delivery_address': order.deliveryAddress,
          'p_items': order.items
              .map(
                (item) => {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                },
              )
              .toList(),
          'p_transfer_proof_path': proofPath,
        },
      );
    } catch (error, stackTrace) {
      await _removeAfterFailure(proofPath, error, stackTrace);
    }
  }

  @override
  Future<void> updateOrder(MarketOrder order) async {
    await _client.rpc(
      'update_market_order_status',
      params: {'p_order_id': order.id, 'p_next_status': order.status},
    );
  }

  @override
  Future<FarmerProfile?> getProfile() async {
    final row = await _client
        .from('farmer_profiles')
        .select('id, name, role, region, phone, address, access_role')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    final values = Map<String, Object?>.from(row);
    if (row['access_role'] == 'penyuluh') {
      final details = await _client
          .from('adviser_profiles')
          .select('certification_number, institution')
          .eq('user_id', _userId)
          .maybeSingle();
      values['certification'] = details?['certification_number'] ?? '';
      values['institution'] = details?['institution'] ?? '';
    } else if (row['access_role'] == 'mitra_toko') {
      final details = await _client
          .from('shop_profiles')
          .select('shop_name, legality')
          .eq('user_id', _userId)
          .maybeSingle();
      values['shop_name'] = details?['shop_name'] ?? '';
      values['legality'] = details?['legality'] ?? '';
    }
    return FarmerProfile.fromMap(values);
  }

  @override
  Future<void> createProfile(FarmerProfile profile) async {
    await _client
        .from('farmer_profiles')
        .upsert(
          _profileValues(profile)..['user_id'] = _userId,
          onConflict: 'user_id',
        );
    await _saveRoleProfile(profile);
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    final updated = await _client
        .from('farmer_profiles')
        .update(_profileValues(profile))
        .eq('user_id', _userId)
        .select('id');
    if (updated.isEmpty) throw StateError('Profil tidak ditemukan.');
    await _saveRoleProfile(profile);
  }

  @override
  Future<void> deleteProfile(int id) async {
    await _client.rpc('delete_current_account');
  }

  @override
  Future<List<SihamaNotification>> getNotifications() async {
    final rows = await _client
        .from('notifications')
        .select('id, report_id, order_id, message, date, status_read')
        .order('date', ascending: false)
        .order('id', ascending: false);
    return rows.map((row) {
      final reportId = row['report_id'] as String?;
      final orderId = row['order_id'] as String?;
      return SihamaNotification(
        id: row['id'] as int,
        title: reportId == null ? 'Pesanan $orderId' : 'Laporan $reportId',
        message: row['message'] as String,
        date: DateTime.parse(row['date'] as String),
        reportId: reportId,
        orderId: orderId,
        isRead: row['status_read'] as bool,
      );
    }).toList();
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final updated = await _client
        .from('notifications')
        .update({'status_read': true})
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) throw StateError('Notifikasi tidak ditemukan.');
  }

  Future<void> _syncDiseaseSymptoms(
    int diseaseId,
    DiagnosisReference reference,
  ) async {
    final names = reference.firstSymptoms
        .split(RegExp(r'[;\n,]+'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    await _client.from('disease_symptoms').delete().eq('disease_id', diseaseId);
    if (names.isEmpty) return;
    await _client
        .from('symptoms')
        .upsert(
          names.map((name) => {'name': name}).toList(),
          onConflict: 'name',
        );
    final rows = await _client
        .from('symptoms')
        .select('id')
        .inFilter('name', names);
    await _client
        .from('disease_symptoms')
        .insert(
          rows
              .map((row) => {'disease_id': diseaseId, 'symptom_id': row['id']})
              .toList(),
        );
  }

  Future<void> _syncDiseaseMedicines(
    int diseaseId,
    List<int> medicineIds,
  ) async {
    await _client
        .from('disease_medicines')
        .delete()
        .eq('disease_id', diseaseId);
    final uniqueIds = medicineIds.toSet();
    if (uniqueIds.isEmpty) return;
    await _client
        .from('disease_medicines')
        .insert(
          uniqueIds
              .map(
                (medicineId) => {
                  'disease_id': diseaseId,
                  'medicine_id': medicineId,
                },
              )
              .toList(),
        );
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String reportId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('report_id', reportId)
        .order('sent_at')
        .order('id');
    return rows
        .map((row) => ChatMessage.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<void> addChatMessage(ChatMessage message) async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    await _client.from('chat_messages').insert({
      'report_id': message.reportId,
      'sender_id': _userId,
      'sender_role': message.senderRole,
      'sender_name': message.senderName,
      'message': text,
      'sent_at': message.sentAt.toIso8601String(),
    });
  }

  Map<String, Object?> _profileValues(FarmerProfile profile) => {
    'name': profile.name,
    'role': profile.role,
    'region': profile.region,
    'phone': profile.phone,
    'address': profile.address,
  };

  Future<void> _syncReportSymptoms(
    String reportId,
    List<int> symptomIds,
  ) async {
    final existing = await _client
        .from('report_symptoms')
        .select('symptom_id')
        .eq('report_id', reportId);
    final currentIds = existing.map((row) => row['symptom_id'] as int).toSet();
    final desiredIds = symptomIds.toSet();
    if (currentIds.length == desiredIds.length &&
        currentIds.containsAll(desiredIds)) {
      return;
    }

    await _client.from('report_symptoms').delete().eq('report_id', reportId);
    if (desiredIds.isNotEmpty) {
      await _client
          .from('report_symptoms')
          .insert(
            desiredIds
                .map(
                  (symptomId) => {
                    'report_id': reportId,
                    'symptom_id': symptomId,
                  },
                )
                .toList(),
          );
    }
  }

  Map<String, Object?> _reportValues(CropReport report) {
    final values = report.toMap()
      ..remove('photo_bytes')
      ..remove('symptom_ids');
    values['disease_id'] = values.remove('diagnosis_reference_id');
    return values;
  }

  Map<String, Object?> _diseaseValues(DiagnosisReference reference) => {
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

  Future<void> _saveRoleProfile(FarmerProfile profile) async {
    final role = await _client
        .from('farmer_profiles')
        .select('access_role')
        .eq('user_id', _userId)
        .single();
    if (role['access_role'] == 'penyuluh') {
      await _client.from('adviser_profiles').upsert({
        'user_id': _userId,
        'certification_number': profile.certification,
        'institution': profile.institution,
      });
    } else if (role['access_role'] == 'mitra_toko') {
      await _client.from('shop_profiles').upsert({
        'user_id': _userId,
        'shop_name': profile.shopName,
        'legality': profile.legality,
      });
    }
  }

  String _mediaPath(String folder, String id, Uint8List bytes) {
    final extension = _extensionFor(bytes);
    return '$folder/$_userId/$id$extension';
  }

  String _extensionFor(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    throw const FormatException('Format foto harus JPG atau PNG.');
  }

  String _contentType(String path) =>
      path.endsWith('.png') ? 'image/png' : 'image/jpeg';

  Future<void> _upload(String path, Uint8List bytes) async {
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: _contentType(path),
            upsert: true,
          ),
        );
    _downloadedMedia[path] = bytes;
  }

  Future<Uint8List?> _download(String? path) async {
    if (path == null || path.isEmpty) return null;
    final cached = _downloadedMedia[path];
    if (cached != null) return cached;
    final bytes = await _client.storage.from(_bucket).download(path);
    _downloadedMedia[path] = bytes;
    return bytes;
  }

  Future<void> _remove(String? path) async {
    if (path == null || path.isEmpty) return;
    await _client.storage.from(_bucket).remove([path]);
    _downloadedMedia.remove(path);
  }

  Future<Never> _removeAfterFailure(
    String? path,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await _remove(path);
    } catch (cleanupError) {
      throw StateError(
        'Operasi Supabase gagal: $error. Pembersihan file juga gagal: $cleanupError',
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
