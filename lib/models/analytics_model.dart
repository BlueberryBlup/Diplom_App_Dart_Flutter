// models/analytics_model.dart
class AnalyticsModel {
  final int totalDefects;
  final int newDefects;
  final int inProgressDefects;
  final int closedDefects;
  final int criticalDefects;
  final int totalLocations;
  final Map<String, int> defectsByCategory; // категория -> количество
  final Map<String, int> defectsByStatus; // статус -> количество
  final Map<String, int> defectsBySeverity; // тяжесть -> количество
  final Map<String, int> defectsByLocation; // помещение -> количество

  AnalyticsModel({
    required this.totalDefects,
    required this.newDefects,
    required this.inProgressDefects,
    required this.closedDefects,
    required this.criticalDefects,
    required this.totalLocations,
    required this.defectsByCategory,
    required this.defectsByStatus,
    required this.defectsBySeverity,
    required this.defectsByLocation,
  });
}
