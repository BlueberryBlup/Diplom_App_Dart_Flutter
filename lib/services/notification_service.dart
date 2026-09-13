import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //отправка уведомлений
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final notification = NotificationModel(
        id: _firestore.collection('notifications').doc().id,
        userId: userId,
        title: title,
        message: message,
        type: type,
        data: data,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toFirestore());
    } catch (e) {}
  }

  //получение уведомлений
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return notifications;
        });
  }

  //прочитано
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  //все прочитаны
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  //колво уведомлений (новых)
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
