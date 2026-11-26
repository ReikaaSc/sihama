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
    this.diagnosisReferenceId,
    this.adviserId,
    this.symptomIds = const [],
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
  final int? diagnosisReferenceId;
  final String? adviserId;
  final List<int> symptomIds;
  final String? recommendation;

  CropReport copyWith({
    String? status,
    String? diagnosis,
    int? diagnosisReferenceId,
    String? adviserId,
    List<int>? symptomIds,
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
    diagnosisReferenceId: diagnosisReferenceId ?? this.diagnosisReferenceId,
    adviserId: adviserId ?? this.adviserId,
    symptomIds: symptomIds ?? this.symptomIds,
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
    'diagnosis_reference_id': diagnosisReferenceId,
    'adviser_id': adviserId,
    'symptom_ids': symptomIds,
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
      diagnosisReferenceId: map['diagnosis_reference_id'] as int?,
      adviserId: map['adviser_id'] as String?,
      symptomIds: (map['symptom_ids'] as List<int>?) ?? const [],
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
    this.certification = '',
    this.institution = '',
    this.shopName = '',
    this.legality = '',
  });

  final int id;
  final String name;
  final String role;
  final String region;
  final String phone;
  final String address;
  final String certification;
  final String institution;
  final String shopName;
  final String legality;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'role': role,
    'region': region,
    'phone': phone,
    'address': address,
    'certification': certification,
    'institution': institution,
    'shop_name': shopName,
    'legality': legality,
  };

  factory FarmerProfile.fromMap(Map<String, Object?> map) => FarmerProfile(
    id: map['id']! as int,
    name: map['name']! as String,
    role: map['role']! as String,
    region: map['region']! as String,
    phone: map['phone']! as String,
    address: map['address']! as String,
    certification: (map['certification'] as String?) ?? '',
    institution: (map['institution'] as String?) ?? '',
    shopName: (map['shop_name'] as String?) ?? '',
    legality: (map['legality'] as String?) ?? '',
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
    this.reportId,
    this.customerPhone = '',
    this.deliveryAddress = '',
    this.transferProofBytes,
  });

  final String id;
  final String customerName;
  final DateTime date;
  final String status;
  final List<MarketOrderItem> items;
  final String? reportId;
  final String customerPhone;
  final String deliveryAddress;
  final Uint8List? transferProofBytes;

  int get total => items.fold(0, (sum, item) => sum + item.total);

  MarketOrder copyWith({String? status}) => MarketOrder(
    id: id,
    customerName: customerName,
    date: date,
    status: status ?? this.status,
    items: items,
    reportId: reportId,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
    transferProofBytes: transferProofBytes,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'customer_name': customerName,
    'date': date.toIso8601String(),
    'status': status,
    'items': jsonEncode(items.map((item) => item.toMap()).toList()),
    'report_id': reportId,
    'total': total,
    'customer_phone': customerPhone,
    'delivery_address': deliveryAddress,
    'transfer_proof_bytes': transferProofBytes,
  };

  factory MarketOrder.fromMap(Map<String, Object?> map) {
    final decodedItems = jsonDecode(map['items']! as String) as List<dynamic>;
    return MarketOrder(
      id: map['id']! as String,
      customerName: map['customer_name']! as String,
      date: DateTime.parse(map['date']! as String),
      status: map['status']! as String,
      customerPhone: (map['customer_phone'] as String?) ?? '',
      deliveryAddress: (map['delivery_address'] as String?) ?? '',
      items: decodedItems
          .map(
            (item) =>
                MarketOrderItem.fromMap(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
      reportId: map['report_id'] as String?,
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

class DiagnosisReference {
  const DiagnosisReference({
    this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.shortDescription,
    required this.affectedPlantParts,
    required this.growthPhase,
    required this.firstSymptoms,
    required this.typicalCauses,
    required this.moreInfo,
    this.symptomIds = const [],
    this.medicineIds = const [],
  });

  final int? id;
  final String slug;
  final String name;
  final String category;
  final String shortDescription;
  final String affectedPlantParts;
  final String growthPhase;
  final String firstSymptoms;
  final String typicalCauses;
  final String moreInfo;
  final List<int> symptomIds;
  final List<int> medicineIds;

  DiagnosisReference copyWith({
    List<int>? symptomIds,
    List<int>? medicineIds,
  }) => DiagnosisReference(
    id: id,
    slug: slug,
    name: name,
    category: category,
    shortDescription: shortDescription,
    affectedPlantParts: affectedPlantParts,
    growthPhase: growthPhase,
    firstSymptoms: firstSymptoms,
    typicalCauses: typicalCauses,
    moreInfo: moreInfo,
    symptomIds: symptomIds ?? this.symptomIds,
    medicineIds: medicineIds ?? this.medicineIds,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'slug': slug,
    'name': name,
    'category': category,
    'short_description': shortDescription,
    'affected_plant_parts': affectedPlantParts,
    'growth_phase': growthPhase,
    'first_symptoms': firstSymptoms,
    'typical_causes': typicalCauses,
    'more_info': moreInfo,
    'symptom_ids': symptomIds,
    'medicine_ids': medicineIds,
  };

  factory DiagnosisReference.fromMap(Map<String, Object?> map) =>
      DiagnosisReference(
        id: map['id'] as int?,
        slug: map['slug']! as String,
        name: map['name']! as String,
        category: map['category']! as String,
        shortDescription: map['short_description']! as String,
        affectedPlantParts: map['affected_plant_parts']! as String,
        growthPhase: map['growth_phase']! as String,
        firstSymptoms: map['first_symptoms']! as String,
        typicalCauses: map['typical_causes']! as String,
        moreInfo: map['more_info']! as String,
        symptomIds: (map['symptom_ids'] as List?)?.cast<int>() ?? const [],
        medicineIds: (map['medicine_ids'] as List?)?.cast<int>() ?? const [],
      );
}

class Symptom {
  const Symptom({required this.id, required this.name, this.iconPath});

  final int id;
  final String name;
  final String? iconPath;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon_path': iconPath,
  };

  factory Symptom.fromMap(Map<String, Object?> map) => Symptom(
    id: map['id']! as int,
    name: map['name']! as String,
    iconPath: map['icon_path'] as String?,
  );
}

class SihamaNotification {
  const SihamaNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.reportId,
    this.orderId,
    this.isRead = false,
  });

  final int id;
  final String title;
  final String message;
  final DateTime date;
  final String? reportId;
  final String? orderId;
  final bool isRead;
}
