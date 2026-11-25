import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sihama_repository.dart';

class SupabaseSihamaRepository
    implements SihamaRepository, SihamaChatRepository {
  SupabaseSihamaRepository(this._client);

  static const _bucket = 'sihama-media';
  final SupabaseClient _client;

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
        .select()
        .order('date', ascending: false);
    return Future.wait(rows.map((row) async {
      final values = Map<String, Object?>.from(row);
      final photoPath = values.remove('photo_path') as String?;
      values['photo_bytes'] = await _download(photoPath);
      return CropReport.fromMap(values);
    }));
  }

  @override
  Future<void> createReport(CropReport report) async {
    final photoPath = report.photoBytes == null
        ? null
        : _mediaPath('reports', report.id, report.photoBytes!);
    if (photoPath != null) {
      await _upload(photoPath, report.photoBytes!);
    }
    final values = report.toMap()
      ..remove('photo_bytes')
      ..['owner_id'] = _userId
      ..['photo_path'] = photoPath;
    try {
      await _client.from('reports').insert(values);
    } catch (error, stackTrace) {
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
    final values = report.toMap()
      ..remove('photo_bytes')
      ..['owner_id'] = existing['owner_id']
      ..['photo_path'] = photoPath;
    try {
      final updated = await _client
          .from('reports')
          .update(values)
          .eq('id', report.id)
          .select('id');
      if (updated.isEmpty) throw StateError('Laporan tidak ditemukan.');
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
        .from('diagnosis_references')
        .select()
        .order('category')
        .order('name');
    return rows
        .map(
          (row) => DiagnosisReference.fromMap(
            Map<String, Object?>.from(row),
          ),
        )
        .toList();
  }

  @override
  Future<void> createDiagnosisReference(
    DiagnosisReference reference,
  ) async {
    await _client
        .from('diagnosis_references')
        .insert(reference.toMap());
  }

  @override
  Future<void> updateDiagnosisReference(
    DiagnosisReference reference,
  ) async {
    final updated = await _client
        .from('diagnosis_references')
        .update(reference.toMap())
        .eq('slug', reference.slug)
        .select('slug');
    if (updated.isEmpty) {
      throw StateError('Referensi diagnosis tidak ditemukan.');
    }
  }

  @override
  Future<void> deleteDiagnosisReference(String slug) async {
    final deleted = await _client
        .from('diagnosis_references')
        .delete()
        .eq('slug', slug)
        .select('slug');
    if (deleted.isEmpty) {
      throw StateError('Referensi diagnosis tidak ditemukan.');
    }
  }

  @override
  Future<List<MarketProduct>> getProducts() async {
    final rows = await _client
        .from('products')
        .select()
        .order('name');
    return Future.wait(rows.map((row) async {
      final values = Map<String, Object?>.from(row);
      final photoPath = values.remove('photo_path') as String?;
      values['photo_bytes'] = await _download(photoPath);
      return MarketProduct.fromMap(values);
    }));
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
        .select()
        .order('date', ascending: false);
    return Future.wait(rows.map((row) async {
      final values = Map<String, Object?>.from(row);
      final items = values['items'];
      values['items'] = items is String ? items : jsonEncode(items);
      final proofPath = values.remove('transfer_proof_path') as String?;
      values['transfer_proof_bytes'] = await _download(proofPath);
      return MarketOrder.fromMap(values);
    }));
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
      params: {
        'p_order_id': order.id,
        'p_next_status': order.status,
      },
    );
  }

  @override
  Future<FarmerProfile?> getProfile() async {
    final row = await _client
        .from('farmer_profiles')
        .select('id, name, role, region, phone, address')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    return FarmerProfile.fromMap(Map<String, Object?>.from(row));
  }

  @override
  Future<void> createProfile(FarmerProfile profile) async {
    await _client.from('farmer_profiles').upsert(
      _profileValues(profile)..['user_id'] = _userId,
      onConflict: 'user_id',
    );
  }

  @override
  Future<void> updateProfile(FarmerProfile profile) async {
    final updated = await _client
        .from('farmer_profiles')
        .update(_profileValues(profile))
        .eq('user_id', _userId)
        .select('id');
    if (updated.isEmpty) throw StateError('Profil tidak ditemukan.');
  }

  @override
  Future<void> deleteProfile(int id) async {
    await _client.rpc('delete_current_account');
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
    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        contentType: _contentType(path),
        upsert: true,
      ),
    );
  }

  Future<Uint8List?> _download(String? path) async {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(_bucket).download(path);
  }

  Future<void> _remove(String? path) async {
    if (path == null || path.isEmpty) return;
    await _client.storage.from(_bucket).remove([path]);
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
