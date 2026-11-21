class CropReport {
  const CropReport({
    required this.id,
    required this.crop,
    required this.location,
    required this.description,
    required this.date,
    required this.status,
  });

  final String id;
  final String crop;
  final String location;
  final String description;
  final DateTime date;
  final String status;

  Map<String, Object?> toMap() => {
    'id': id,
    'crop': crop,
    'location': location,
    'description': description,
    'date': date.toIso8601String(),
    'status': status,
  };

  factory CropReport.fromMap(Map<String, Object?> map) => CropReport(
    id: map['id']! as String,
    crop: map['crop']! as String,
    location: map['location']! as String,
    description: map['description']! as String,
    date: DateTime.parse(map['date']! as String),
    status: map['status']! as String,
  );
}

class MarketProduct {
  const MarketProduct({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    this.stock = 0,
  });

  final int? id;
  final String name;
  final String category;
  final int price;
  final int stock;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'price': price,
    'stock': stock,
  };

  factory MarketProduct.fromMap(Map<String, Object?> map) => MarketProduct(
    id: map['id']! as int,
    name: map['name']! as String,
    category: map['category']! as String,
    price: map['price']! as int,
    stock: (map['stock'] as int?) ?? 0,
  );
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
  Future<FarmerProfile?> getProfile();
  Future<void> createProfile(FarmerProfile profile);
  Future<void> updateProfile(FarmerProfile profile);
  Future<void> deleteProfile(int id);
}
