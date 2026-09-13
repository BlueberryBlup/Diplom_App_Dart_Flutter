import 'package:cloud_firestore/cloud_firestore.dart';

//поля класса
class DefectHistoryModel {
  final String id; // уникальный номер записи истории
  final String defectId; // к какому замечанию относится
  final String oldStatus; // начальный статус
  final String newStatus; // новый статус
  final String whoChanged; // кто изменил (id пользователя)
  final DateTime dateOfChange; // когда изменил

  DefectHistoryModel({
    required this.id,
    required this.defectId,
    required this.oldStatus,
    required this.newStatus,
    required this.whoChanged,
    required this.dateOfChange,
  });

  //преобразование документа Firestore в объект Dart
  factory DefectHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DefectHistoryModel(
      id: doc.id,
      defectId: data['defectId'] ?? '',
      oldStatus: data['oldStatus'] ?? '',
      newStatus: data['newStatus'] ?? '',
      whoChanged: data['whoChanged'] ?? '',
      dateOfChange:
          (data['dateOfChange'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'defectId': defectId,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'whoChanged': whoChanged,
      'dateOfChange': Timestamp.fromDate(dateOfChange),
    };
  }
}
