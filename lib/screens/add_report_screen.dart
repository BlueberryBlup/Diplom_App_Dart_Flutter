import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:diplomgrinenko/services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/defect_model.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/defect_marker_editor.dart';
import 'package:flutter/services.dart' show rootBundle;

class PhotoWithMarker {
  final String path;
  final Offset? markerPosition;

  PhotoWithMarker({required this.path, this.markerPosition});
}

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedObjectId;
  String? _selectedCategory;
  String? _selectedLocationId;
  String _selectedSeverity = 'minor';
  DateTime? _selectedDeadline;

  final String _status = 'new';

  // Фото замечаний (обычные фото, без редактора)
  final List<String> _photoPaths = [];

  bool _isLoading = false;
  bool _isUploading = false;

  final AuthService _auth = AuthService();
  late final LocalStorageService _storageService;
  late String _currentUserId;

  // Для планировки помещения
  File? _layoutImage;
  bool _isLoadingLayout = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.getCurrUser()?.uid ?? '';
    _storageService = LocalStorageService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  //загрузка планеровки
  Future<void> _loadLayoutImage() async {
    if (_selectedLocationId == null) return;

    setState(() {
      _isLoadingLayout = true;
      _layoutImage = null;
    });

    try {
      final assetPath = 'assets/locations/$_selectedLocationId.png';
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/layout_$_selectedLocationId.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        _layoutImage = tempFile;
        _isLoadingLayout = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLayout = false;
      });
    }
  }

  Future<void> _addDefectLocation() async {
    if (_layoutImage == null) return;

    final markedImagePath = await Navigator.push(
      context,
      MaterialPageRoute<String>(
        builder: (context) => DefectMarkerEditor(imagePath: _layoutImage!.path),
      ),
    );

    if (markedImagePath != null && mounted) {
      final savedPath = await _storageService.savePhoto(File(markedImagePath));
      if (savedPath != null) {
        setState(() {
          _photoPaths.add(savedPath);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Местоположение дефекта добавлено'),
            backgroundColor: AppTheme.greenApp,
          ),
        );
      }
    }
  }

  // Показать выбор источника для своих фото (БЕЗ РЕДАКТОРА)
  void _showImageSource() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Добавить фото',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.grey[700]),
              title: const Text('Сделать фото'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.grey[700]),
              title: const Text('Выбрать из галереи'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  //добавление фото
  Future<void> _pickImage(ImageSource source) async {
    try {
      File? imageFile;

      if (source == ImageSource.camera) {
        imageFile = await _storageService.pickImageFromCamera();
      } else {
        imageFile = await _storageService.pickImageFromGallery();
      }

      if (imageFile != null && mounted) {
        final savedPath = await _storageService.savePhoto(imageFile);
        if (savedPath != null) {
          setState(() {
            _photoPaths.add(savedPath);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фото добавлено'),
              backgroundColor: AppTheme.greenApp,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.redApp),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
  }

  Future<void> _saveReport() async {
    if (_nameController.text.isEmpty) {
      _showError('Введите название замечания');
      return;
    }
    if (_selectedObjectId == null) {
      _showError('Выберите объект');
      return;
    }
    if (_selectedLocationId == null) {
      _showError('Выберите помещение');
      return;
    }
    if (_selectedDeadline == null) {
      _showError('Выберите срок устранения');
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    final defect = DefectModel(
      id: '', // Пустой ID, Firebase сам сгенерирует при add()
      name: _nameController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      severity: _selectedSeverity,
      objectId: _selectedObjectId!,
      locationId: _selectedLocationId!,
      customerId: _currentUserId,
      contractorId: null,
      photoBefore: _photoPaths,
      photoAfter: [],
      status: _status,
      dateOfCreation: DateTime.now(),
      datesOfStart: [],
      datesOfCorrect: [],
      datesOfReopened: [],
      dateOfCheck: null,
      deadline: _selectedDeadline,
      iterCount: 1,
      verificationStatus: null,
    );

    FirebaseFirestore.instance
        .collection('defects')
        .add(defect.toFirestore())
        .then((docRef) {})
        .catchError((e) {});

    // Сразу закрываем экран
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Замечание сохранено'),
        backgroundColor: AppTheme.greenApp,
        duration: Duration(seconds: 3),
      ),
    );

    setState(() {
      _isLoading = false;
      _isUploading = false;
    });

    Navigator.pop(context);
  }

  Widget _buildPhotoPreview() {
    if (_photoPaths.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _photoPaths.length,
            itemBuilder: (context, index) {
              return FutureBuilder<File?>(
                future: _storageService.getPhoto(_photoPaths[index]),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              snapshot.data!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppTheme.redApp,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новое замечание', style: TextStyle(fontSize: 18)),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: (_isLoading || _isUploading) ? null : _saveReport,
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Выберите объект *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildObjectDrop(),
                        const SizedBox(height: 24),

                        if (_selectedObjectId != null) ...[
                          const Text(
                            'Выберите помещение *',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLocationDrop(),
                          const SizedBox(height: 16),
                        ],

                        // Показываем планировку помещения
                        if (_selectedLocationId != null) ...[
                          const Text(
                            'Планировка помещения',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_isLoadingLayout)
                            const Center(child: CircularProgressIndicator())
                          else if (_layoutImage != null)
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _layoutImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: const Center(
                                child: Text(
                                  'Нет планировки для этого помещения',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Кнопка добавления местоположения дефекта
                          ElevatedButton.icon(
                            onPressed: _layoutImage == null
                                ? null
                                : _addDefectLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text(
                              'Добавить местоположение дефекта',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.blue[50],
                              foregroundColor: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Нажмите, чтобы отметить на планировке место дефекта',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        const Text(
                          'Введите название *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Название замечания..',
                            border: OutlineInputBorder(),
                          ),
                          maxLength: 100,
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'Категория *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCategoryDrop(),
                        const SizedBox(height: 16),

                        const Text(
                          'Описание',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                            hintText: 'Опишите проблему...',
                          ),
                          maxLines: 5,
                          maxLength: 500,
                        ),
                        const SizedBox(height: 16),

                        const Divider(),
                        const SizedBox(height: 16),

                        const Text(
                          'Критичность нарушения *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSeveritySelector(),
                        const SizedBox(height: 16),

                        const Text(
                          'Срок устранения *',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDeadline(),
                        const SizedBox(height: 16),

                        const Divider(),
                        const SizedBox(height: 16),

                        Center(
                          child: const Text(
                            'Добавить свои фото',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _showImageSource,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Добавить фото'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Вы можете добавить свои фото',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),

                        _buildPhotoPreview(),

                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Статус замечания автоматически установлен как "Новое"',
                                  style: TextStyle(color: Colors.blue[700]),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _isUploading)
                                ? null
                                : _saveReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                37,
                                126,
                                129,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'СОЗДАТЬ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Сохранение...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryDrop() {
    final categories = DefectModel.categories;
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Выберите категорию',
      ),
      items: categories.map((category) {
        return DropdownMenuItem(value: category, child: Text(category));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) {
        if (value == null) return 'Выберите категорию';
        return null;
      },
    );
  }

  Widget _buildObjectDrop() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('objects')
          .where('customerId', isEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final objects = snapshot.data!.docs;

        if (objects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.warning, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Нет доступных объектов'),
              ],
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: _selectedObjectId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
          hint: const Text('Выберите объект'),
          items: objects.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name'] ?? 'Без названия'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedObjectId = value;
              _selectedLocationId = null;
              _layoutImage = null;
            });
          },
          validator: (value) {
            if (value == null) return 'Выберите объект';
            return null;
          },
        );
      },
    );
  }

  Widget _buildLocationDrop() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('locations')
          .where('objectId', isEqualTo: _selectedObjectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final locations = snapshot.data!.docs;

        if (locations.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.bug_report_sharp, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'В этом объекте пока нет помещений',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: _selectedLocationId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.meeting_room),
          ),
          hint: const Text('Выберите помещение'),
          items: locations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            String displayText = '';
            if (data['floor'] != null && data['number'] != null) {
              displayText = '${data['floor']} этаж, ${data['number']}';
            } else {
              displayText = data['number'] ?? 'Без номера';
            }
            return DropdownMenuItem(value: doc.id, child: Text(displayText));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLocationId = value;
            });
            if (value != null) {
              _loadLayoutImage();
            }
          },
          validator: (value) {
            if (value == null) return 'Выберите помещение';
            return null;
          },
        );
      },
    );
  }

  Widget _buildSeveritySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSeverityOption(
            value: 'minor',
            title: 'Незначительное',
            description: 'Косметические дефекты, не влияющие на безопасность',
            color: AppTheme.greenApp,
          ),
          const Divider(height: 0),
          _buildSeverityOption(
            value: 'major',
            title: 'Значительное',
            description: 'Влияет на функциональность, требует внимания',
            color: AppTheme.orangeApp,
          ),
          const Divider(height: 0),
          _buildSeverityOption(
            value: 'critical',
            title: 'Критичное',
            description: 'Угрожает безопасности, требует немедленного решения',
            color: AppTheme.redApp,
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityOption({
    required String value,
    required String title,
    required String description,
    required Color color,
  }) {
    final isSelected = _selectedSeverity == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSeverity = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(isSelected ? 8 : 0),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedSeverity,
              onChanged: (v) {
                setState(() {
                  _selectedSeverity = v!;
                });
              },
              activeColor: color,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadline() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null && mounted) {
          setState(() {
            _selectedDeadline = date;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDeadline != null
                    ? '${_selectedDeadline!.day.toString().padLeft(2, '0')}.${_selectedDeadline!.month.toString().padLeft(2, '0')}.${_selectedDeadline!.year}'
                    : 'Выберите дату устранения',
                style: TextStyle(
                  color: _selectedDeadline != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.redApp),
    );
  }
}
