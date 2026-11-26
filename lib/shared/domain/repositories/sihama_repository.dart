import 'package:sihama/shared/models/sihama_models.dart';

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
  Future<List<DiagnosisReference>> getDiagnosisReferences();
  Future<List<Symptom>> getSymptoms();
  Future<void> createDiagnosisReference(DiagnosisReference reference);
  Future<void> updateDiagnosisReference(DiagnosisReference reference);
  Future<void> deleteDiagnosisReference(String slug);
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
  Future<List<SihamaNotification>> getNotifications();
  Future<void> markNotificationRead(int id);
}
