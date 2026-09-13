// services/status_service.dart
import 'package:diplomgrinenko/models/review_model.dart';
import 'package:diplomgrinenko/services/notification_service.dart';
import 'package:diplomgrinenko/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/defect_history_model.dart';

class StatusService {
  static const List<String> allStatuses = [
    'new',
    'in_progress',
    'fixed',
    'verified',
    'reopened',
    'closed',
  ];

  static String getStatusText(String status) {
    switch (status) {
      case 'new':
        return 'Новое';
      case 'in_progress':
        return 'В работе';
      case 'fixed':
        return 'На проверке';
      case 'verified':
        return 'Принято';
      case 'reopened':
        return 'Переоткрыто';
      case 'closed':
        return 'Закрыто';
      default:
        return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'new':
        return AppTheme.purpleApp;
      case 'in_progress':
        return AppTheme.blueApp;
      case 'fixed':
        return AppTheme.orangeApp;
      case 'verified':
        return AppTheme.greenApp;
      case 'reopened':
        return AppTheme.redApp;
      case 'closed':
        return const Color.fromARGB(255, 86, 182, 67);
      default:
        return Colors.grey;
    }
  }

  static List<String> getAvailableStatuses(String role, String currentStatus) {
    switch (role) {
      case 'Подрядчик':
        switch (currentStatus) {
          case 'new':
            return ['in_progress'];
          case 'in_progress':
            return ['fixed'];
          case 'reopened':
            return ['in_progress'];
          default:
            return [];
        }
      case 'Генеральный подрядчик':
        switch (currentStatus) {
          case 'fixed':
            return ['verified', 'reopened'];
          default:
            return [];
        }
      case 'Заказчик':
        switch (currentStatus) {
          case 'verified':
            return ['closed'];
          default:
            return [];
        }
      default:
        return [];
    }
  }

  static bool canChangeStatus(String role, String currentStatus) {
    return getAvailableStatuses(role, currentStatus).isNotEmpty;
  }

  static Future<void> _saveToHistory({
    required String defectId,
    required String oldStatus,
    required String newStatus,
    required String userId,
  }) async {
    try {
      final history = DefectHistoryModel(
        id: '',
        defectId: defectId,
        oldStatus: oldStatus,
        newStatus: newStatus,
        whoChanged: userId,
        dateOfChange: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('defect_history')
          .add(history.toFirestore());
    } catch (e) {}
  }

  static Future<void> _sendStatusNotifications({
    required String defectId,
    required String oldStatus,
    required String newStatus,
    required String changedByUserId,
  }) async {
    try {
      final defectDoc = await FirebaseFirestore.instance
          .collection('defects')
          .doc(defectId)
          .get();

      if (!defectDoc.exists) return;

      final defectData = defectDoc.data() as Map<String, dynamic>;
      final defectName = defectData['name'] ?? 'Замечание';
      final contractorId = defectData['contractorId'];
      final customerId = defectData['customerId'];

      final objectDoc = await FirebaseFirestore.instance
          .collection('objects')
          .doc(defectData['objectId'])
          .get();
      final objectName = objectDoc.exists
          ? (objectDoc.data()?['name'] ?? 'объекте')
          : 'объекте';

      final notificationService = NotificationService();

      if (newStatus == 'reopened' &&
          contractorId != null &&
          contractorId.isNotEmpty) {
        await notificationService.sendNotification(
          userId: contractorId,
          title: 'Замечание переоткрыто',
          message:
              'Замечание "$defectName" на $objectName было переоткрыто и требует доработки',
          type: 'status_changed',
          data: {
            'defectId': defectId,
            'defectName': defectName,
            'objectId': defectData['objectId'],
            'objectName': objectName,
            'newStatus': newStatus,
            'oldStatus': oldStatus,
          },
        );
      }

      if (newStatus == 'verified' &&
          customerId != null &&
          customerId.isNotEmpty) {
        await notificationService.sendNotification(
          userId: customerId,
          title: 'Замечание принято',
          message:
              'Замечание "$defectName" на $objectName успешно проверено и принято',
          type: 'status_changed',
          data: {
            'defectId': defectId,
            'defectName': defectName,
            'objectId': defectData['objectId'],
            'objectName': objectName,
            'newStatus': newStatus,
          },
        );
      }

      if (newStatus == 'fixed') {
        final objectDocForGC = await FirebaseFirestore.instance
            .collection('objects')
            .doc(defectData['objectId'])
            .get();
        final generalContractorId = objectDocForGC
            .data()?['generalContractorId'];

        if (generalContractorId != null && generalContractorId.isNotEmpty) {
          await notificationService.sendNotification(
            userId: generalContractorId,
            title: 'Замечание на проверке',
            message:
                'Подрядчик отметил замечание "$defectName" на $objectName как исправленное. Требуется проверка.',
            type: 'status_changed',
            data: {
              'defectId': defectId,
              'defectName': defectName,
              'objectId': defectData['objectId'],
              'objectName': objectName,
              'newStatus': newStatus,
              'oldStatus': oldStatus,
            },
          );
        }
      }

      if (newStatus == 'closed') {
        final objectDocForGC = await FirebaseFirestore.instance
            .collection('objects')
            .doc(defectData['objectId'])
            .get();
        final generalContractorId = objectDocForGC
            .data()?['generalContractorId'];

        if (generalContractorId != null && generalContractorId.isNotEmpty) {
          await notificationService.sendNotification(
            userId: generalContractorId,
            title: 'Замечание закрыто',
            message: 'Замечание "$defectName" на $objectName полностью закрыто',
            type: 'status_changed',
            data: {
              'defectId': defectId,
              'defectName': defectName,
              'objectId': defectData['objectId'],
              'objectName': objectName,
              'newStatus': newStatus,
            },
          );
        }
      }
    } catch (e) {}
  }

  static Future<void> updateStatus({
    required String defectId,
    required String newStatus,
    required String userId,
    DateTime? dateTime,
    ContrReviewModel? feedback,
  }) async {
    final defectDoc = await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .get();

    final oldStatus = defectDoc.data()?['status'] ?? 'new';
    final currentIterCount = defectDoc.data()?['iterCount'] ?? 1;

    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'in_progress' && dateTime != null) {
      final currentDatesOfStart = _getDateList(defectDoc, 'datesOfStart');
      final updatedDates = List<DateTime>.from(currentDatesOfStart);
      updatedDates.add(dateTime);
      updateData['datesOfStart'] = updatedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else if (newStatus == 'fixed' && dateTime != null) {
      final currentDatesOfCorrect = _getDateList(defectDoc, 'datesOfCorrect');
      final updatedDates = List<DateTime>.from(currentDatesOfCorrect);
      updatedDates.add(dateTime);
      updateData['datesOfCorrect'] = updatedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else if (newStatus == 'verified') {
      updateData['dateOfCheck'] = Timestamp.fromDate(DateTime.now());
    } else if (newStatus == 'reopened') {
      updateData['iterCount'] = currentIterCount + 1;

      final currentDatesOfReopened = _getDateList(defectDoc, 'datesOfReopened');
      final updatedReopenedDates = List<DateTime>.from(currentDatesOfReopened);
      updatedReopenedDates.add(DateTime.now());
      updateData['datesOfReopened'] = updatedReopenedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else if (newStatus == 'closed') {
      if (feedback != null) {
        await FirebaseFirestore.instance
            .collection('feedbacks')
            .add(feedback.toFirestore());
      }
    }

    await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .update(updateData);

    await _saveToHistory(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      userId: userId,
    );

    await _sendStatusNotifications(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedByUserId: userId,
    );
  }

  static List<DateTime> _getDateList(DocumentSnapshot doc, String fieldName) {
    final data = doc.data() as Map<String, dynamic>;
    final fieldValue = data[fieldName];

    if (fieldValue == null) return [];

    if (fieldValue is List) {
      return fieldValue
          .whereType<Timestamp>()
          .map((timestamp) => timestamp.toDate())
          .toList();
    }

    return [];
  }

  static Future<void> updateStatusWithPhotos({
    required String defectId,
    required String newStatus,
    required String userId,
    DateTime? dateTime,
    List<String>? photosAfter,
  }) async {
    final defectDoc = await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .get();

    final oldStatus = defectDoc.data()?['status'] ?? 'new';
    final currentIterCount = defectDoc.data()?['iterCount'] ?? 1;

    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'in_progress' && dateTime != null) {
      final currentDatesOfStart = _getDateList(defectDoc, 'datesOfStart');
      final updatedDates = List<DateTime>.from(currentDatesOfStart);
      updatedDates.add(dateTime);
      updateData['datesOfStart'] = updatedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else if (newStatus == 'fixed' && dateTime != null) {
      final currentDatesOfCorrect = _getDateList(defectDoc, 'datesOfCorrect');
      final updatedDates = List<DateTime>.from(currentDatesOfCorrect);
      updatedDates.add(dateTime);
      updateData['datesOfCorrect'] = updatedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();

      if (photosAfter != null && photosAfter.isNotEmpty) {
        final existingPhotos = defectDoc.data()?['photoAfter'];
        List<String> allPhotos = [];

        if (existingPhotos is List) {
          allPhotos = List<String>.from(existingPhotos);
        } else if (existingPhotos is String && existingPhotos.isNotEmpty) {
          allPhotos = [existingPhotos];
        }

        allPhotos.addAll(photosAfter);
        updateData['photoAfter'] = allPhotos;
      }
    } else if (newStatus == 'verified') {
      updateData['dateOfCheck'] = Timestamp.fromDate(DateTime.now());
    } else if (newStatus == 'reopened') {
      updateData['iterCount'] = currentIterCount + 1;

      final currentDatesOfReopened = _getDateList(defectDoc, 'datesOfReopened');
      final updatedReopenedDates = List<DateTime>.from(currentDatesOfReopened);
      updatedReopenedDates.add(DateTime.now());
      updateData['datesOfReopened'] = updatedReopenedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else if (newStatus == 'closed') {}

    await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .update(updateData);

    await _saveToHistory(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      userId: userId,
    );

    await _sendStatusNotifications(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedByUserId: userId,
    );
  }

  // services/status_service.dart

  static Future<void> updateStatusWithReason({
    required String defectId,
    required String newStatus,
    required String userId,
    required String reopenReason,
    DateTime? dateTime,
    ContrReviewModel? feedback,
  }) async {
    final defectDoc = await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .get();

    final oldStatus = defectDoc.data()?['status'] ?? 'new';
    final currentIterCount = defectDoc.data()?['iterCount'] ?? 1;

    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'reopened') {
      updateData['iterCount'] = currentIterCount + 1;

      final currentReasons = defectDoc.data()?['reopenReasons'] as List? ?? [];
      final updatedReasons = List<String>.from(currentReasons);
      updatedReasons.add(reopenReason);
      updateData['reopenReasons'] = updatedReasons;

      final currentDatesOfReopened = _getDateList(defectDoc, 'datesOfReopened');
      final updatedReopenedDates = List<DateTime>.from(currentDatesOfReopened);
      updatedReopenedDates.add(DateTime.now());
      updateData['datesOfReopened'] = updatedReopenedDates
          .map((d) => Timestamp.fromDate(d))
          .toList();
    } else {
      await updateStatus(
        defectId: defectId,
        newStatus: newStatus,
        userId: userId,
        dateTime: dateTime,
        feedback: feedback,
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('defects')
        .doc(defectId)
        .update(updateData);

    await _saveToHistory(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      userId: userId,
    );

    await _sendStatusNotifications(
      defectId: defectId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedByUserId: userId,
    );
  }
}
