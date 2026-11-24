import 'dart:convert';
import 'dart:typed_data';

class CropReport {
  const CropReport({
    required this.id,
    required this.crop,
    required this.location,
    required this.description,
    required this.date,
    required this.status,
    this.photoBytes,
    this.diagnosis,
    this.recommendation,
  });

  final String id;
  final String crop;
  final String location;
  final String description;
  final DateTime date;
  final String status;
  final Uint8List? photoBytes;
  final String? diagnosis;
  final String? recommendation;

  CropReport copyWith({
    String? status,
    String? diagnosis,
    String? recommendation,
  }) => CropReport(
    id: id,
    crop: crop,
    location: location,
    description: description,
    date: date,
    status: status ?? this.status,
    photoBytes: photoBytes,
    diagnosis: diagnosis ?? this.diagnosis,
    recommendation: recommendation ?? this.recommendation,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'crop': crop,
    'location': location,
    'description': description,
    'date': date.toIso8601String(),
    'status': status,
    'photo_bytes': photoBytes,
    'diagnosis': diagnosis,
    'recommendation': recommendation,
  };

  factory CropReport.fromMap(Map<String, Object?> map) {
    final photo = map['photo_bytes'];
    return CropReport(
      id: map['id']! as String,
      crop: map['crop']! as String,
      location: map['location']! as String,
      description: map['description']! as String,
      date: DateTime.parse(map['date']! as String),
      status: map['status']! as String,
      photoBytes: photo is Uint8List
          ? photo
          : photo is List<int>
          ? Uint8List.fromList(photo)
          : null,
      diagnosis: map['diagnosis'] as String?,
      recommendation: map['recommendation'] as String?,
    );
  }
}

class MarketProduct {
  const MarketProduct({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    this.stock = 0,
    this.description = '',
    this.photoBytes,
  });

  final int? id;
  final String name;
  final String category;
  final int price;
  final int stock;
  final String description;
  final Uint8List? photoBytes;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'price': price,
    'stock': stock,
    'description': description,
    'photo_bytes': photoBytes,
  };

  factory MarketProduct.fromMap(Map<String, Object?> map) {
    final photo = map['photo_bytes'];
    return MarketProduct(
      id: map['id']! as int,
      name: map['name']! as String,
      category: map['category']! as String,
      price: map['price']! as int,
      stock: (map['stock'] as int?) ?? 0,
      description: (map['description'] as String?) ?? '',
      photoBytes: photo is Uint8List
          ? photo
          : photo is List<int>
          ? Uint8List.fromList(photo)
          : null,
    );
  }
}

class FarmerProfile {
  const FarmerProfile({
    this.id = 1,
    required this.name,
    required this.role,
    required this.region,
    required this.phone,
    required this.address,
  });

  final int id;
  final String name;
  final String role;
  final String region;
  final String phone;
  final String address;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'role': role,
    'region': region,
    'phone': phone,
    'address': address,
  };

  factory FarmerProfile.fromMap(Map<String, Object?> map) => FarmerProfile(
    id: map['id']! as int,
    name: map['name']! as String,
    role: map['role']! as String,
    region: map['region']! as String,
    phone: map['phone']! as String,
    address: map['address']! as String,
  );
}

class MarketOrderItem {
  const MarketOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final int quantity;
  final int unitPrice;

  int get total => quantity * unitPrice;

  Map<String, Object?> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
  };

  factory MarketOrderItem.fromMap(Map<String, Object?> map) => MarketOrderItem(
    productId: map['product_id']! as int,
    productName: map['product_name']! as String,
    quantity: map['quantity']! as int,
    unitPrice: map['unit_price']! as int,
  );
}

class MarketOrder {
  const MarketOrder({
    required this.id,
    required this.customerName,
    required this.date,
    required this.status,
    required this.items,
    this.transferProofBytes,
  });

  final String id;
  final String customerName;
  final DateTime date;
  final String status;
  final List<MarketOrderItem> items;
  final Uint8List? transferProofBytes;

  int get total => items.fold(0, (sum, item) => sum + item.total);

  MarketOrder copyWith({String? status}) => MarketOrder(
    id: id,
    customerName: customerName,
    date: date,
    status: status ?? this.status,
    items: items,
    transferProofBytes: transferProofBytes,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'customer_name': customerName,
    'date': date.toIso8601String(),
    'status': status,
    'items': jsonEncode(items.map((item) => item.toMap()).toList()),
    'total': total,
    'transfer_proof_bytes': transferProofBytes,
  };

  factory MarketOrder.fromMap(Map<String, Object?> map) {
    final decodedItems = jsonDecode(map['items']! as String) as List<dynamic>;
    return MarketOrder(
      id: map['id']! as String,
      customerName: map['customer_name']! as String,
      date: DateTime.parse(map['date']! as String),
      status: map['status']! as String,
      items: decodedItems
          .map(
            (item) =>
                MarketOrderItem.fromMap(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
      transferProofBytes: map['transfer_proof_bytes'] is Uint8List
          ? map['transfer_proof_bytes'] as Uint8List
          : map['transfer_proof_bytes'] is List<int>
          ? Uint8List.fromList(map['transfer_proof_bytes'] as List<int>)
          : null,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.reportId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  final int? id;
  final String reportId;
  final String senderRole;
  final String senderName;
  final String text;
  final DateTime sentAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'report_id': reportId,
    'sender_role': senderRole,
    'sender_name': senderName,
    'message': text,
    'sent_at': sentAt.toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
    id: map['id'] as int?,
    reportId: map['report_id']! as String,
    senderRole: map['sender_role']! as String,
    senderName: map['sender_name']! as String,
    text: map['message']! as String,
    sentAt: DateTime.parse(map['sent_at']! as String),
  );
}

abstract interface class SihamaChatRepository {
  Future<List<ChatMessage>> getChatMessages(String reportId);
  Future<void> addChatMessage(ChatMessage message);
}

abstract interface class SihamaRepository {
  Future<void> initialize();
  Future<List<CropReport>> getReports();
  Future<void> createReport(CropReport report);
  Future<void> updateReport(CropReport report);
  Future<void> deleteReport(String id);
  Future<List<MarketProduct>> getProducts();
  Future<int> createProduct(MarketProduct product);
  Future<void> updateProduct(MarketProduct product);
  Future<void> deleteProduct(int id);
  Future<List<MarketOrder>> getOrders();
  Future<void> createOrder(MarketOrder order);
  Future<void> updateOrder(MarketOrder order);
  Future<FarmerProfile?> getProfile();
  Future<void> createProfile(FarmerProfile profile);
  Future<void> updateProfile(FarmerProfile profile);
  Future<void> deleteProfile(int id);
}
