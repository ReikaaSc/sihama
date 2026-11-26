# SIHAMA Class Diagram

Diagram kelas ini menampilkan model domain, kontrak repository, implementasi penyimpanan, dan autentikasi SIHAMA.

```mermaid
classDiagram
direction LR

class SihamaRole {
  <<enumeration>>
  pelapor
  penyuluh
  mitraToko
  +label
  +demoEmail
  +accessRole
  +fromAccessRole(value)
}

class CropReport {
  +String id
  +String crop
  +String location
  +String description
  +DateTime date
  +String status
  +Uint8List photoBytes
  +String diagnosis
  +int diagnosisReferenceId
  +String adviserId
  +List~int~ symptomIds
  +String recommendation
  +copyWith()
  +toMap()
  +fromMap()
}

class FarmerProfile {
  +int id
  +String name
  +String role
  +String region
  +String phone
  +String address
  +String certification
  +String institution
  +String shopName
  +String legality
  +toMap()
  +fromMap()
}

class MarketProduct {
  +int id
  +String name
  +String category
  +int price
  +int stock
  +String description
  +Uint8List photoBytes
  +toMap()
  +fromMap()
}

class MarketOrder {
  +String id
  +String customerName
  +String customerPhone
  +String deliveryAddress
  +DateTime date
  +String status
  +String reportId
  +int total
  +Uint8List transferProofBytes
  +copyWith()
  +toMap()
  +fromMap()
}

class MarketOrderItem {
  +int productId
  +String productName
  +int quantity
  +int unitPrice
  +int total
  +toMap()
  +fromMap()
}

class ChatMessage {
  +int id
  +String reportId
  +String senderRole
  +String senderName
  +String text
  +DateTime sentAt
  +toMap()
  +fromMap()
}

class DiagnosisReference {
  +int id
  +String slug
  +String name
  +String category
  +String shortDescription
  +String affectedPlantParts
  +String growthPhase
  +String firstSymptoms
  +String typicalCauses
  +String moreInfo
  +List~int~ symptomIds
  +List~int~ medicineIds
  +toMap()
  +fromMap()
}

class Symptom {
  +int id
  +String name
  +String iconPath
  +toMap()
  +fromMap()
}

class SihamaNotification {
  +int id
  +String title
  +String message
  +DateTime date
  +String reportId
  +String orderId
  +bool isRead
}

class AdviserProfile {
  +String userId
  +String certificationNumber
  +String institution
}

class ShopProfile {
  +String userId
  +String shopName
  +String legality
}

class SihamaRepository {
  <<interface>>
  +initialize()
  +getReports()
  +createReport(report)
  +updateReport(report)
  +deleteReport(id)
  +getDiagnosisReferences()
  +getSymptoms()
  +createDiagnosisReference(reference)
  +updateDiagnosisReference(reference)
  +deleteDiagnosisReference(slug)
  +getProducts()
  +createProduct(product)
  +updateProduct(product)
  +deleteProduct(id)
  +getOrders()
  +createOrder(order)
  +updateOrder(order)
  +getProfile()
  +createProfile(profile)
  +updateProfile(profile)
  +deleteProfile(id)
  +getNotifications()
  +markNotificationRead(id)
}

class SihamaChatRepository {
  <<interface>>
  +getChatMessages(reportId)
  +addChatMessage(message)
}

class SihamaDatabase {
  +initialize()
  +getReports()
  +createReport(report)
  +getProducts()
  +getOrders()
  +getProfile()
  +getChatMessages(reportId)
}

class SupabaseSihamaRepository {
  -SupabaseClient client
  -Map downloadedMedia
  +initialize()
  +getReports()
  +createReport(report)
  +getProducts()
  +getOrders()
  +getProfile()
  +getChatMessages(reportId)
  +clearCachedMedia()
}

class SupabaseAuthService {
  -SupabaseClient client
  +currentEmail
  +currentName
  +submit(registering, name, email, password)
  +currentRole()
  +deleteCurrentAccount(password)
  +signOut()
}

class SupabaseAuthResult {
  +SihamaRole role
  +String message
}

SihamaRepository <|.. SihamaDatabase
SihamaChatRepository <|.. SihamaDatabase
SihamaRepository <|.. SupabaseSihamaRepository
SihamaChatRepository <|.. SupabaseSihamaRepository

SihamaRepository ..> CropReport : mengelola
SihamaRepository ..> FarmerProfile : mengelola
SihamaRepository ..> MarketProduct : mengelola
SihamaRepository ..> MarketOrder : mengelola
SihamaRepository ..> DiagnosisReference : mengelola
SihamaRepository ..> Symptom : mengambil
SihamaRepository ..> SihamaNotification : mengelola
SihamaChatRepository ..> ChatMessage : mengelola

MarketOrder "1" *-- "1..*" MarketOrderItem : berisi
MarketOrderItem ..> MarketProduct : productId
MarketOrder ..> CropReport : reportId
CropReport ..> DiagnosisReference : diagnosisReferenceId
CropReport "0..*" -- "0..*" Symptom : report_symptoms
DiagnosisReference "0..*" -- "0..*" Symptom : disease_symptoms
DiagnosisReference "0..*" -- "0..*" MarketProduct : disease_medicines
FarmerProfile "1" *-- "0..1" AdviserProfile : peran penyuluh
FarmerProfile "1" *-- "0..1" ShopProfile : peran mitra toko
SihamaNotification ..> CropReport : reportId
SihamaNotification ..> MarketOrder : orderId
ChatMessage ..> CropReport : reportId
SupabaseAuthService ..> SupabaseAuthResult : menghasilkan
SupabaseAuthResult ..> SihamaRole : memuat peran
SupabaseAuthService ..> SihamaRole : menentukan peran
```

## Catatan relasi

- `MarketOrder` berisi satu atau lebih `MarketOrderItem`. Item menyimpan ID, nama, dan harga produk saat transaksi.
- Pesanan baru harus merujuk ke laporan pelapor yang berstatus `Selesai Ditinjau`; `reportId` tetap opsional untuk membaca pesanan historis.
- `CropReport.symptomIds` dan gejala penyakit dipersistenkan sebagai relasi many-to-many, bukan hanya teks pada deskripsi.
- Obat yang direkomendasikan untuk penyakit disimpan melalui relasi `disease_medicines`; rekomendasi spesifik laporan tetap tersimpan pada `CropReport`.
- `FarmerProfile` memuat detail khusus Penyuluh atau Mitra Toko melalui profil peran masing-masing.
- `SihamaNotification` memiliki relasi opsional ke laporan atau pesanan dan status baca.
- `ChatMessage.reportId` menghubungkan pesan percakapan dengan laporan.
- Pemilik laporan disimpan sebagai `owner_id` di Supabase, bukan sebagai field pada class `CropReport`.
- `FarmerProfile` menyimpan data profil aplikasi; autentikasi akun ditangani terpisah oleh Supabase Auth.
