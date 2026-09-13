import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class DefectModel {
  final String id;
  final String name; // название замечания
  final String description; // описание
  final String? category; //свет/трубы/стены/пол/потолок/и тд

  final String objectId; // id объекта
  final String locationId; // помещение
  final String customerId; // заказчик
  final String? contractorId; // подрядчик

  final String severity; // тяжесть нарушений
  final List<String> photoBefore; // ссылка на фото до
  final List<String> photoAfter; // ссылка на фото после
  final String status; // статус

  final DateTime dateOfCreation; // когда создали
  final List<DateTime>
  datesOfStart; // когда начинали исправлять (каждая итерация)
  final List<DateTime>
  datesOfCorrect; // когда подрядчик исправлял (каждая итерация)
  final List<DateTime> datesOfReopened; // когда переоткрывали (каждая итерация)

  final DateTime? dateOfCheck;
  final DateTime? deadline; //срок устранения

  final int iterCount; //сколько раз исправляли
  final String? verificationStatus; // статус проверки (accepted/rejected)
  final List<String> reopenReasons; // причина переоткрытия

  DefectModel({
    required this.id,
    required this.name,
    this.category,
    required this.description,
    required this.severity,
    required this.objectId,
    required this.locationId,
    required this.customerId,
    this.contractorId,
    required this.photoBefore,
    required this.photoAfter,
    required this.status,
    required this.dateOfCreation,
    required this.datesOfStart,
    required this.datesOfCorrect,
    required this.datesOfReopened,
    this.dateOfCheck,
    this.deadline,
    this.iterCount = 1,
    this.verificationStatus,
    this.reopenReasons = const [],
  });

  factory DefectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<String> photoBeforeList = [];
    if (data['photoBefore'] != null) {
      if (data['photoBefore'] is List) {
        photoBeforeList = List<String>.from(data['photoBefore']);
      } else if (data['photoBefore'] is String &&
          data['photoBefore'].toString().isNotEmpty) {
        photoBeforeList = [data['photoBefore']];
      }
    }

    List<String> photoAfterList = [];
    if (data['photoAfter'] != null) {
      if (data['photoAfter'] is List) {
        photoAfterList = List<String>.from(data['photoAfter']);
      } else if (data['photoAfter'] is String &&
          data['photoAfter'].toString().isNotEmpty) {
        photoAfterList = [data['photoAfter']];
      }
    }

    List<DateTime> datesOfStart = [];
    if (data['datesOfStart'] != null && data['datesOfStart'] is List) {
      datesOfStart = (data['datesOfStart'] as List)
          .map((e) => (e as Timestamp).toDate())
          .toList();
    } else if (data['dateOfStart'] != null) {
      datesOfStart = [(data['dateOfStart'] as Timestamp).toDate()];
    }

    List<DateTime> datesOfCorrect = [];
    if (data['datesOfCorrect'] != null && data['datesOfCorrect'] is List) {
      datesOfCorrect = (data['datesOfCorrect'] as List)
          .map((e) => (e as Timestamp).toDate())
          .toList();
    } else if (data['dateOfCorrect'] != null) {
      datesOfCorrect = [(data['dateOfCorrect'] as Timestamp).toDate()];
    }

    List<DateTime> datesOfReopened = [];
    if (data['datesOfReopened'] != null && data['datesOfReopened'] is List) {
      datesOfReopened = (data['datesOfReopened'] as List)
          .map((e) => (e as Timestamp).toDate())
          .toList();
    } else if (data['dateOfReopened'] != null) {
      datesOfReopened = [(data['dateOfReopened'] as Timestamp).toDate()];
    }

    int iterCount = data['iterCount'] ?? 1;
    if (iterCount == 1 &&
        (datesOfStart.length > 1 || datesOfCorrect.length > 1)) {
      iterCount = max(
        datesOfStart.length,
        max(datesOfCorrect.length, datesOfReopened.length),
      );
    }

    List<String> reopenReasons = [];
    if (data['reopenReasons'] != null && data['reopenReasons'] is List) {
      reopenReasons = List<String>.from(data['reopenReasons']);
    } else if (data['reopenReason'] != null &&
        data['reopenReason'].toString().isNotEmpty) {
      // Обратная совместимость: если была одна причина
      reopenReasons = [data['reopenReason'].toString()];
    }

    return DefectModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      severity: data['severity'] ?? 'minor',
      objectId: data['objectId'] ?? '',
      locationId: data['locationId'] ?? '',
      customerId: data['customerId'] ?? '',
      contractorId: data['contractorId'],
      photoBefore: photoBeforeList,
      photoAfter: photoAfterList,
      status: data['status'] ?? 'open',
      dateOfCreation:
          (data['dateOfCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
      datesOfStart: datesOfStart,
      datesOfCorrect: datesOfCorrect,
      datesOfReopened: datesOfReopened,
      dateOfCheck: (data['dateOfCheck'] as Timestamp?)?.toDate(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      iterCount: iterCount,
      verificationStatus: data['verificationStatus'],
      reopenReasons: reopenReasons,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'objectId': objectId,
      'locationId': locationId,
      'customerId': customerId,
      'contractorId': contractorId,
      'name': name,
      'description': description,
      'category': category,
      'severity': severity,
      'photoBefore': photoBefore,
      'photoAfter': photoAfter,
      'status': status,
      'dateOfCreation': FieldValue.serverTimestamp(),
      'datesOfStart': datesOfStart.map((d) => Timestamp.fromDate(d)).toList(),
      'datesOfCorrect': datesOfCorrect
          .map((d) => Timestamp.fromDate(d))
          .toList(),
      'datesOfReopened': datesOfReopened
          .map((d) => Timestamp.fromDate(d))
          .toList(),
      'dateOfCheck': dateOfCheck != null
          ? Timestamp.fromDate(dateOfCheck!)
          : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'iterCount': iterCount,
      'verificationStatus': verificationStatus,
      'reopenReasons': reopenReasons,
    };
  }

  double? getReactionTimeInDays(int iterationIndex) {
    if (iterationIndex >= datesOfStart.length) return null;

    final startDate = datesOfStart[iterationIndex];
    final previousDate = iterationIndex == 0
        ? dateOfCreation
        : datesOfReopened[iterationIndex - 1];

    return startDate.difference(previousDate).inDays.toDouble();
  }

  double? getFixTimeInDays(int iterationIndex) {
    if (iterationIndex >= datesOfCorrect.length) return null;
    if (iterationIndex >= datesOfStart.length) return null;

    return datesOfCorrect[iterationIndex]
        .difference(datesOfStart[iterationIndex])
        .inDays
        .toDouble();
  }

  double get averageReactionTimeInDays {
    if (datesOfStart.isEmpty) return 0;
    double total = 0;
    for (int i = 0; i < datesOfStart.length; i++) {
      final time = getReactionTimeInDays(i);
      if (time != null) total += time;
    }
    return total / datesOfStart.length;
  }

  double get averageFixTimeInDays {
    if (datesOfCorrect.isEmpty) return 0;
    double total = 0;
    for (int i = 0; i < datesOfCorrect.length; i++) {
      final time = getFixTimeInDays(i);
      if (time != null) total += time;
    }
    return total / datesOfCorrect.length;
  }

  bool get isOverdue {
    if (deadline == null) return false;
    if (status == 'closed') return false;
    return DateTime.now().isAfter(deadline!);
  }

  int get overdueDays {
    if (!isOverdue) return 0;
    return DateTime.now().difference(deadline!).inDays;
  }

  DefectModel copyWith({
    String? name,
    String? description,
    String? category,
    String? status,
    List<DateTime>? datesOfStart,
    List<DateTime>? datesOfCorrect,
    List<DateTime>? datesOfReopened,
    DateTime? dateOfCheck,
    int? iterCount,
    String? verificationStatus,
    List<String>? photoAfter,
    List<String>? reopenReasons,
  }) {
    return DefectModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity,
      objectId: objectId,
      locationId: locationId,
      customerId: customerId,
      contractorId: contractorId,
      photoBefore: photoBefore,
      photoAfter: photoAfter ?? this.photoAfter,
      status: status ?? this.status,
      dateOfCreation: dateOfCreation,
      datesOfStart: datesOfStart ?? this.datesOfStart,
      datesOfCorrect: datesOfCorrect ?? this.datesOfCorrect,
      datesOfReopened: datesOfReopened ?? this.datesOfReopened,
      dateOfCheck: dateOfCheck ?? this.dateOfCheck,
      deadline: deadline,
      iterCount: iterCount ?? this.iterCount,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      reopenReasons: reopenReasons ?? this.reopenReasons,
    );
  }

  static List<String> categories = [
    'Стены',
    'Пол',
    'Электрика',
    'Вентиляция',
    'Отопление',
    'Сантехника',
    'Окна',
    'Двери',
    'Системы пож. безопасности',
    'Отделка помещения',
  ];

  DateTime? get dateOfStart =>
      datesOfStart.isNotEmpty ? datesOfStart.last : null;
  DateTime? get dateOfCorrect =>
      datesOfCorrect.isNotEmpty ? datesOfCorrect.last : null;
  DateTime? get dateOfReopened =>
      datesOfReopened.isNotEmpty ? datesOfReopened.last : null;
}
