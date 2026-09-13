// models/feedback_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ContrReviewModel {
  final String id;
  final String defectId;
  final String contractorId;
  final int communication; // взаимодействие с подрядом (1-5)
  final int materials; // качество материалов (1-5)
  final int workQuality; // качество работы (1-5)
  final DateTime createdAt;

  ContrReviewModel({
    required this.id,
    required this.defectId,
    required this.contractorId,
    required this.communication,
    required this.materials,
    required this.workQuality,
    required this.createdAt,
  });

  factory ContrReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContrReviewModel(
      id: doc.id,
      defectId: data['defectId'] ?? '',
      contractorId: data['contractorId'] ?? '',
      communication: data['communication'] ?? 3,
      materials: data['materials'] ?? 3,
      workQuality: data['workQuality'] ?? 3,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'defectId': defectId,
      'contractorId': contractorId,
      'communication': communication,
      'materials': materials,
      'workQuality': workQuality,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  double get averageRating => (communication + materials + workQuality) / 3;
}
