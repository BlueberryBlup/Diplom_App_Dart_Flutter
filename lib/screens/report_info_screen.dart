import 'dart:io';
import 'package:diplomgrinenko/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/defect_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../services/status_service.dart';

class ReportInfoScreen extends StatefulWidget {
  final DefectModel defect;

  const ReportInfoScreen({super.key, required this.defect});

  @override
  State<ReportInfoScreen> createState() => _ReportInfoScreenState();
}

class _ReportInfoScreenState extends State<ReportInfoScreen> {
  final AuthService _auth = AuthService();
  String? _objectName;
  String? _locationName;
  String? _contractorName;
  String? _customerName;
  String? _userRole;
  bool _isLoading = true;
  List<File> _photosAfter = [];
  bool _isLoadingPhotosAfter = true;

  List<File> _photos = [];
  bool _isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    _loadAdditionalInfo();
    _loadPhotosBefore();
    _loadPhotosAfter();
  }

  Future<void> _loadPhotosBefore() async {
    setState(() {
      _isLoadingPhotos = true;
    });

    try {
      final localStorage = LocalStorageService();
      final List<File> loadedPhotos = [];

      if (widget.defect.photoBefore.isNotEmpty) {
        for (final photoPath in widget.defect.photoBefore) {
          if (photoPath.isNotEmpty) {
            final photoFile = await localStorage.getPhoto(photoPath);
            if (photoFile != null) {
              loadedPhotos.add(photoFile);
            }
          }
        }
      }

      setState(() {
        _photos = loadedPhotos;
        _isLoadingPhotos = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPhotos = false;
      });
    }
  }

  Future<void> _loadPhotosAfter() async {
    setState(() {
      _isLoadingPhotosAfter = true;
    });

    try {
      final localStorage = LocalStorageService();
      final List<File> loadedPhotos = [];

      final photoAfterList = widget.defect.photoAfter;
      if (photoAfterList.isNotEmpty) {
        for (final photoPath in photoAfterList) {
          if (photoPath.isNotEmpty) {
            final photoFile = await localStorage.getPhoto(photoPath);
            if (photoFile != null) {
              loadedPhotos.add(photoFile);
            }
          }
        }
      }

      setState(() {
        _photosAfter = loadedPhotos;
        _isLoadingPhotosAfter = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPhotosAfter = false;
      });
    }
  }

  Future<void> _loadAdditionalInfo() async {
    try {
      final role = await _auth.getCurrUserRole();
      _userRole = role;

      final objectDoc = await FirebaseFirestore.instance
          .collection('objects')
          .doc(widget.defect.objectId)
          .get();
      _objectName = objectDoc.data()?['name'] ?? 'Не найдено';

      final locationDoc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.defect.locationId)
          .get();
      final locationData = locationDoc.data();
      if (locationData != null) {
        _locationName =
            '${locationData['floor']} этаж, пом. ${locationData['number']}';
      } else {
        _locationName = 'Не найдено';
      }

      if (widget.defect.contractorId != null &&
          widget.defect.contractorId!.isNotEmpty) {
        final contractorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.defect.contractorId)
            .get();
        final contractorData = contractorDoc.data();
        if (contractorData != null) {
          _contractorName =
              '${contractorData['surname']} ${contractorData['name']}';
        }
      }

      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.defect.customerId)
          .get();
      final customerData = customerDoc.data();
      if (customerData != null) {
        _customerName = '${customerData['surname']} ${customerData['name']}';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditScreen() {
    final titleController = TextEditingController(text: widget.defect.name);
    final descriptionController = TextEditingController(
      text: widget.defect.description,
    );
    DateTime? selectedDeadline = widget.defect.deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
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
                const Center(
                  child: Text(
                    'Редактирование замечания',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Название'),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Введите название',
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Описание'),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Введите описание',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                const Text('Срок устранения'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setBottomSheetState(() {
                        selectedDeadline = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          selectedDeadline != null
                              ? _formatFullDate(selectedDeadline!)
                              : 'Выберите дату',
                          style: TextStyle(
                            color: selectedDeadline != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _saveChanges(
                            titleController.text,
                            descriptionController.text,
                            selectedDeadline,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            37,
                            126,
                            129,
                          ),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(color: Colors.white),
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
  }

  Future<void> _saveChanges(
    String newTitle,
    String newDescription,
    DateTime? newDeadline,
  ) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (newTitle != widget.defect.name) {
        updateData['name'] = newTitle;
      }
      if (newDescription != widget.defect.description) {
        updateData['description'] = newDescription;
      }
      if (newDeadline != widget.defect.deadline) {
        updateData['deadline'] = newDeadline != null
            ? Timestamp.fromDate(newDeadline)
            : null;
      }

      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('defects')
            .doc(widget.defect.id)
            .update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Изменения сохранены'),
              backgroundColor: AppTheme.greenApp,
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.redApp,
          ),
        );
      }
    }
  }

  Widget _buildPhotoSection() {
    if (_isLoadingPhotos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фотоматериалы',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  _showFullScreenImage(index);
                },
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _photos[index],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(thickness: 0.5),
      ],
    );
  }

  Widget _buildPhotoAfterSection() {
    if (_isLoadingPhotosAfter) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photosAfter.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фото после исправления',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _photosAfter.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullScreenImageAfter(index),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _photosAfter[index],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(thickness: 0.5),
      ],
    );
  }

  void _showFullScreenImage(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(_photos[index], fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 30, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImageAfter(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(_photosAfter[index], fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 30, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClient = _userRole == 'Заказчик';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Информация о замечании',
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (isClient)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditScreen,
              tooltip: 'Редактировать',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          widget.defect.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),
                        const Divider(thickness: 2),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (widget.defect.description.isNotEmpty)
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Описание',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.defect.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(thickness: 0.5),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  if (widget.defect.status == 'reopened' &&
                      widget.defect.reopenReasons.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.redApp.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.redApp.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppTheme.redApp,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Причина переоткрытия:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.redApp,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.defect.reopenReasons.last,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  _buildPhotoSection(),

                  const SizedBox(height: 16),
                  _buildPhotoAfterSection(),
                  const SizedBox(height: 16),

                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Местоположение',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.business,
                          'Объект',
                          _objectName ?? 'Загрузка...',
                          color: Colors.grey[800],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.meeting_room,
                          'Помещение',
                          _locationName ?? 'Загрузка...',
                          color: Colors.grey[800],
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 0.5),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ответственные лица',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.person,
                          'Создал',
                          _customerName ?? 'Загрузка...',
                          color: Colors.grey[800],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.engineering,
                          'Подрядчик',
                          _contractorName ?? 'Не назначен',
                          color: Colors.grey[800],
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 0.5),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Детали',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.warning,
                          'Критичность',
                          _getSeverityText(widget.defect.severity),
                          color: _getSeverityColor(widget.defect.severity),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.flag,
                          'Статус',
                          StatusService.getStatusText(widget.defect.status),
                          color: StatusService.getStatusColor(
                            widget.defect.status,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 0.5),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Даты и сроки',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Дата создания',
                          _formatFullDate(widget.defect.dateOfCreation),
                          color: Colors.grey[800],
                        ),
                        if (widget.defect.dateOfStart != null)
                          _buildInfoRow(
                            Icons.play_arrow,
                            'Начало работ',
                            _formatFullDate(widget.defect.dateOfStart!),
                            color: Colors.grey[800],
                          ),
                        if (widget.defect.dateOfCorrect != null)
                          _buildInfoRow(
                            Icons.check_circle,
                            'Дата исправления',
                            _formatFullDate(widget.defect.dateOfCorrect!),
                            color: Colors.grey[800],
                          ),
                        _buildInfoRow(
                          Icons.event,
                          'Срок устранения',
                          widget.defect.deadline != null
                              ? _formatFullDate(widget.defect.deadline!)
                              : 'Не указан',
                          color: widget.defect.isOverdue
                              ? AppTheme.redApp
                              : null,
                        ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 0.5),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Статистика',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.loop,
                          'Количество исправлений',
                          '${widget.defect.iterCount}',
                        ),

                        _buildInfoRow(
                          Icons.speed,
                          'Ср. время реакции',
                          widget.defect.datesOfStart.isNotEmpty
                              ? '${widget.defect.averageReactionTimeInDays.toStringAsFixed(1)} дней'
                              : 'Нет данных',
                        ),

                        _buildInfoRow(
                          Icons.timer,
                          'Ср. время устранения',
                          widget.defect.datesOfCorrect.isNotEmpty
                              ? '${widget.defect.averageFixTimeInDays.toStringAsFixed(1)} дней'
                              : 'Нет данных',
                        ),

                        if (widget.defect.datesOfCorrect.length > 1)
                          _buildInfoRow(
                            Icons.history,
                            'Всего исправлений',
                            '${widget.defect.datesOfCorrect.length}',
                          ),
                        const SizedBox(height: 10),
                        const Divider(thickness: 0.5),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[800]),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[800], fontSize: 15),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: color ?? Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  String _getSeverityText(String severity) {
    switch (severity) {
      case 'critical':
        return 'Критичное';
      case 'major':
        return 'Значительное';
      case 'minor':
        return 'Незначительное';
      default:
        return severity;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppTheme.redApp;
      case 'major':
        return AppTheme.orangeApp;
      case 'minor':
        return AppTheme.greenApp;
      default:
        return Colors.grey;
    }
  }

  String _formatFullDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year} $hour:$minute';
  }
}
