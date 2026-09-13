import 'package:diplomgrinenko/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Уведомления', style: TextStyle(fontSize: 18)),
        ),
        body: const Center(
          child: Text('Войдите в аккаунт для просмотра уведомлений'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () async {
              await _notificationService.markAllAsRead(userId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Все уведомления прочитаны')),
                );
              }
            },
            child: const Text(
              'Прочитать всё',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 32, color: Colors.grey),
                  const SizedBox(height: 14),
                  Text('Ошибка: ${snapshot.error}'),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 40, color: Colors.grey),
                  SizedBox(height: 14),
                  Text(
                    'Нет уведомлений',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? null : Colors.blue[50],
      child: ListTile(
        leading: _getNotificationIcon(notification.type),
        title: Text(
          notification.title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          notification.message,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
        trailing: Text(
          _formatDate(notification.createdAt),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () async {
          if (!notification.isRead) {
            await _notificationService.markAsRead(notification.id);
          }
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'contractor_assigned':
        return const Icon(Icons.person_add, color: AppTheme.greenApp);
      case 'status_changed':
        return const Icon(Icons.update, color: AppTheme.orangeApp);
      default:
        return const Icon(Icons.notifications, color: AppTheme.blueApp);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'Только что';
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    Navigator.pop(context);
  }
}
