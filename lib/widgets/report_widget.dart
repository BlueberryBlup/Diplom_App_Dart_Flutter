// widgets/remark_card.dart
import 'dart:async';
import 'dart:io';

import 'package:diplomgrinenko/models/review_model.dart';
import 'package:diplomgrinenko/services/auth_service.dart';
import 'package:diplomgrinenko/services/local_storage_service.dart';
import 'package:diplomgrinenko/services/notification_service.dart';
import 'package:diplomgrinenko/services/status_service.dart';
import 'package:diplomgrinenko/widgets/reopen_widget.dart';
import 'package:flutter/material.dart';
import '../models/defect_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/contractor_screen.dart';
import '../screens/report_info_screen.dart';
import '../theme/app_theme.dart';

class ReportCard extends StatelessWidget {
  final DefectModel defect;
  final AuthService _auth = AuthService();
  final VoidCallback? onContractorAssigned;

  ReportCard({super.key, required this.defect, this.onContractorAssigned});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportInfoScreen(defect: defect),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 1.5, color: Colors.grey[400]!),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    defect.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildSeverityBadge(),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _getObjectName(defect.objectId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Загрузка...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Ответственный:  ',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<String?>(
                  future: _auth.getCurrUserRole(),
                  builder: (context, roleSnapshot) {
                    final userRole = roleSnapshot.data;

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getContractorData(),
                      builder: (context, contractorSnapshot) {
                        final hasContractor =
                            contractorSnapshot.hasData &&
                            contractorSnapshot.data != null;
                        final contractorName = hasContractor
                            ? '${contractorSnapshot.data!['surname']} ${contractorSnapshot.data!['name']}'
                            : 'Не назначен';

                        if (userRole == 'Генеральный подрядчик') {
                          final canAssignContractor = defect.status == 'new';

                          final buttonColor = hasContractor
                              ? AppTheme.greenApp
                              : AppTheme.orangeApp;
                          if (!canAssignContractor) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                contractorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: hasContractor
                                      ? const Color.fromARGB(255, 108, 165, 137)
                                      : Colors.grey[600],
                                ),
                              ),
                            );
                          }

                          return TextButton(
                            onPressed: () async {
                              final selectedContractor = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContractorScreen(
                                    selectedCategory: defect.category,
                                  ),
                                ),
                              );

                              if (selectedContractor != null &&
                                  context.mounted) {
                                try {
                                  await _assignContractor(
                                    selectedContractor['id'],
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          hasContractor
                                              ? 'Подрядчик изменен на: ${selectedContractor['surname']} ${selectedContractor['name']}'
                                              : 'Назначен подрядчик: ${selectedContractor['surname']} ${selectedContractor['name']}',
                                        ),
                                        backgroundColor: AppTheme.greenApp,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    onContractorAssigned?.call();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Ошибка: $e'),
                                        backgroundColor: AppTheme.redApp,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: const Size(0, 10),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              contractorName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            contractorName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: hasContractor
                                  ? const Color.fromARGB(255, 108, 165, 137)
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Интерактивный статус
                  FutureBuilder<String?>(
                    future: _auth.getCurrUserRole(),
                    builder: (context, snapshot) {
                      final userRole = snapshot.data;
                      if (userRole == null) {
                        return _buildStatusBadge();
                      }
                      return _buildStatusButton(context, userRole);
                    },
                  ),
                  Row(
                    children: [
                      if (defect.isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 10,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${defect.overdueDays} дн.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (defect.isOverdue) const SizedBox(width: 8),
                      Text(
                        _formatDate(defect.dateOfCreation),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (defect.iterCount > 1) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.loop, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Исправлений: ${defect.iterCount}',
                      style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _assignContractor(String contractorId) async {
    try {
      final objectDoc = await FirebaseFirestore.instance
          .collection('objects')
          .doc(defect.objectId)
          .get();
      final objectName = objectDoc.exists
          ? (objectDoc.data()?['name'] ?? 'объекте')
          : 'объекте';

      await FirebaseFirestore.instance
          .collection('defects')
          .doc(defect.id)
          .update({
            'contractorId': contractorId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: contractorId,
        title: 'Новое назначение',
        message:
            'Вы назначены ответственным за замечание "${defect.name}" на $objectName',
        type: 'contractor_assigned',
        data: {
          'defectId': defect.id,
          'defectName': defect.name,
          'objectId': defect.objectId,
          'objectName': objectName,
          'assignedBy': _auth.getCurrUser()?.uid,
          'assignedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getObjectName(String objectId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('objects')
          .doc(objectId)
          .get();
      if (doc.exists) {
        return doc.data()?['name'] ?? 'Объект не найден';
      }
      return 'Объект не найден';
    } catch (e) {
      return 'Ошибка загрузки';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Сегодня, ${_formatTime(date)}';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Вчера, ${_formatTime(date)}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSeverityBadge() {
    Color color;
    String text;

    switch (defect.severity) {
      case 'critical':
        color = const Color.fromARGB(255, 226, 88, 78);
        text = 'Критичное';
        break;
      case 'major':
        color = const Color.fromARGB(255, 240, 161, 43);
        text = 'Значительное';
        break;
      case 'minor':
        color = const Color.fromARGB(255, 86, 182, 67);
        text = 'Незначительное';
        break;
      default:
        color = Colors.grey;
        text = 'Не указано';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getContractorData() async {
    if (defect.contractorId == null || defect.contractorId == '') {
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(defect.contractorId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildStatusBadge() {
    final color = StatusService.getStatusColor(defect.status);
    final text = StatusService.getStatusText(defect.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, String userRole) {
    final canChange = StatusService.canChangeStatus(userRole, defect.status);

    if (!canChange) {
      return _buildStatusBadge();
    }

    return GestureDetector(
      onTap: () => _showChangeStatus(context, userRole),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: StatusService.getStatusColor(defect.status),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              StatusService.getStatusText(defect.status),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  void _showChangeStatus(BuildContext context, String userRole) {
    final availableStatuses = StatusService.getAvailableStatuses(
      userRole,
      defect.status,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Изменить статус',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...availableStatuses.map(
              (status) => ListTile(
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: StatusService.getStatusColor(status),
                ),
                title: Text(StatusService.getStatusText(status)),
                onTap: () async {
                  Navigator.pop(context);
                  if (status == 'reopened') {
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (context) => const ReopenDialog(),
                    );

                    if (reason != null && reason.isNotEmpty) {
                      await _updateStatusWithReason(context, status, reason);
                    }
                  } else {
                    await _updateStatus(context, status);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatusWithReason(
    BuildContext context,
    String newStatus,
    String reason,
  ) async {
    try {
      final user = _auth.getCurrUser();
      if (user == null) return;

      await StatusService.updateStatusWithReason(
        defectId: defect.id,
        newStatus: newStatus,
        userId: user.uid,
        reopenReason: reason,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Замечание переоткрыто с указанием причины'),
            backgroundColor: AppTheme.orangeApp,
          ),
        );
        onContractorAssigned?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.redApp,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final user = _auth.getCurrUser();
      if (user == null) return;

      if (newStatus == 'fixed') {
        final photosAfter = await _showAddPhotosDialog(context);

        await StatusService.updateStatusWithPhotos(
          defectId: defect.id,
          newStatus: newStatus,
          userId: user.uid,
          dateTime: DateTime.now(),
          photosAfter: photosAfter.isNotEmpty ? photosAfter : null,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                photosAfter.isNotEmpty
                    ? 'Статус изменён на "На проверке", фото сохранены'
                    : 'Статус изменён на "На проверке"',
              ),
              backgroundColor: AppTheme.greenApp,
            ),
          );
          onContractorAssigned?.call();
        }
      } else if (newStatus == 'closed') {
        final contractorId = defect.contractorId;
        if (contractorId != null && contractorId.isNotEmpty) {
          await _showFeedbackDialog(context, defect.id, contractorId);
        } else {
          await StatusService.updateStatus(
            defectId: defect.id,
            newStatus: newStatus,
            userId: user.uid,
            dateTime: null,
          );
        }
      } else {
        DateTime? dateTime;
        if (newStatus == 'in_progress') {
          dateTime = DateTime.now();
        }

        await StatusService.updateStatus(
          defectId: defect.id,
          newStatus: newStatus,
          userId: user.uid,
          dateTime: dateTime,
        );

        if (context.mounted) {
          onContractorAssigned?.call();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.redApp,
          ),
        );
      }
    }
  }

  Future<List<String>> _showAddPhotosDialog(BuildContext context) async {
    final List<String> savedPaths = [];
    final localStorage = LocalStorageService();

    final completer = Completer<List<String>>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавить фото после исправления',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 16),

                if (savedPaths.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: savedPaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            FutureBuilder<File?>(
                              future: localStorage.getPhoto(savedPaths[index]),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(snapshot.data!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  await localStorage.deletePhoto(
                                    savedPaths[index],
                                  );
                                  setState(() {
                                    savedPaths.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppTheme.redApp,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                if (savedPaths.isEmpty)
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Добавьте хотя бы одно фото',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final photo = await localStorage
                              .pickImageFromGallery();
                          if (photo != null) {
                            final savedPath = await localStorage.savePhoto(
                              photo,
                            );
                            if (savedPath != null) {
                              setState(() {
                                savedPaths.add(savedPath);
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Выбрать фото'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final photo = await localStorage
                              .pickImageFromCamera();
                          if (photo != null) {
                            final savedPath = await localStorage.savePhoto(
                              photo,
                            );
                            if (savedPath != null) {
                              setState(() {
                                savedPaths.add(savedPath);
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Снять фото'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (savedPaths.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Необходимо добавить хотя бы одно фото',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          completer.complete(savedPaths);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primaryColor),
                        ),
                        child: Text(
                          'Подтвердить',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );

    return completer.future;
  }

  Future<void> _showFeedbackDialog(
    BuildContext context,
    String defectId,
    String contractorId,
  ) async {
    int communication = 3;
    int materials = 3;
    int workQuality = 3;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Оцените работу подрядчика',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),

                  _buildRatingRow(
                    label: 'Взаимодействие с подрядчиком',
                    value: communication,
                    onChanged: (value) {
                      setState(() {
                        communication = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildRatingRow(
                    label: 'Качество материалов',
                    value: materials,
                    onChanged: (value) {
                      setState(() {
                        materials = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildRatingRow(
                    label: 'Качество работы',
                    value: workQuality,
                    onChanged: (value) {
                      setState(() {
                        workQuality = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final feedback = ContrReviewModel(
                    id: '',
                    defectId: defectId,
                    contractorId: contractorId,
                    communication: communication,
                    materials: materials,
                    workQuality: workQuality,
                    createdAt: DateTime.now(),
                  );

                  final user = _auth.getCurrUser();
                  if (user != null) {
                    await StatusService.updateStatus(
                      defectId: defectId,
                      newStatus: 'closed',
                      userId: user.uid,
                      feedback: feedback,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Замечание закрыто. Спасибо за отзыв!'),
                          backgroundColor: AppTheme.greenApp,
                        ),
                      );
                      onContractorAssigned?.call();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text(
                  'Закрыть замечание',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingRow({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return IconButton(
              icon: Icon(
                starValue <= value ? Icons.star : Icons.star_border,
                color: starValue <= value ? AppTheme.orangeApp : Colors.grey,
                size: 32,
              ),
              onPressed: () => onChanged(starValue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            );
          }),
        ),
      ],
    );
  }
}
