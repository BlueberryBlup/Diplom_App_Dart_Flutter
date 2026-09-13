
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AnalyticsModel> getAnalytics(String objectId) async {
    final defectsSnapshot = await _firestore
        .collection('defects')
        .where('objectId', isEqualTo: objectId)
        .get();

    final defects = defectsSnapshot.docs;

    final totalDefects = defects.length;

    final newDefects = defects.where((d) => d['status'] == 'new').length;

    //в работе
    final inProgressDefects = defects
        .where((d) => d['status'] == 'in_progress')
        .length;

    //закрытые
    final closedDefects = defects
        .where((d) => d['status'] == 'closed' || d['status'] == 'verified')
        .length;

    //критич.
    final criticalDefects = defects
        .where((d) => d['severity'] == 'critical')
        .length;

    //помещения
    final locationsSnapshot = await _firestore
        .collection('locations')
        .where('objectId', isEqualTo: objectId)
        .get();
    final totalLocations = locationsSnapshot.docs.length;

    //по категориям
    final Map<String, int> defectsByCategory = {};
    for (final defect in defects) {
      final category = defect['category'] ?? 'Без категории';
      defectsByCategory[category] = (defectsByCategory[category] ?? 0) + 1;
    }

    //по статусам
    final Map<String, int> defectsByStatus = {};
    for (final defect in defects) {
      final status = defect['status'] ?? 'unknown';
      defectsByStatus[status] = (defectsByStatus[status] ?? 0) + 1;
    }

    //по критичности
    final Map<String, int> defectsBySeverity = {};
    for (final defect in defects) {
      final severity = defect['severity'] ?? 'minor';
      defectsBySeverity[severity] = (defectsBySeverity[severity] ?? 0) + 1;
    }

    //по помещениям
    final Map<String, int> defectsByLocation = {};
    for (final defect in defects) {
      final locationId = defect['locationId'];
      if (locationId != null) {
        defectsByLocation[locationId] =
            (defectsByLocation[locationId] ?? 0) + 1;
      }
    }

    return AnalyticsModel(
      totalDefects: totalDefects,
      newDefects: newDefects,
      inProgressDefects: inProgressDefects,
      closedDefects: closedDefects,
      criticalDefects: criticalDefects,
      totalLocations: totalLocations,
      defectsByCategory: defectsByCategory,
      defectsByStatus: defectsByStatus,
      defectsBySeverity: defectsBySeverity,
      defectsByLocation: defectsByLocation,
    );
  }

  Future<List<Map<String, dynamic>>> getUserObjects(
    String userId,
    String role,
  ) async {
    Query query = _firestore.collection('objects');

    if (role == 'Заказчик') {
      query = query.where('customerId', isEqualTo: userId);
    } else if (role == 'Генеральный подрядчик') {
      query = query.where('generalContractorId', isEqualTo: userId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, 'name': doc['name'] ?? 'Без названия'};
    }).toList();
  }
}
