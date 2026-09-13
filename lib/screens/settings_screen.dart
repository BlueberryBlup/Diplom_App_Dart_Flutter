import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();

  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patronymicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  UserModel? _userData;

  bool _hasChanges = false;

  // Валидация имени (только буквы, пробелы и дефис)
  bool _validateName(String name) {
    if (name.isEmpty) return false;
    final RegExp nameRegex = RegExp(r'^[a-zA-Zа-яА-ЯёЁ\s\-]+$');
    return nameRegex.hasMatch(name);
  }

  // Валидация телефона
  bool _validatePhone(String phone) {
    if (phone.isEmpty) return true;
    final RegExp phoneRegex = RegExp(r'^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$');
    return phoneRegex.hasMatch(phone);
  }

  // Форматирование телефона
  void _formatPhone(String value) {
    String cleaned = value.replaceAll(RegExp(r'\D'), '');

    if (cleaned.isEmpty) {
      if (_phoneController.text.isNotEmpty) {
        _phoneController.text = '';
      }
      return;
    }

    if (!cleaned.startsWith('7') && !cleaned.startsWith('8')) {
      return;
    }

    if (cleaned.startsWith('8')) {
      cleaned = '7' + cleaned.substring(1);
    }

    if (cleaned.length > 11) {
      cleaned = cleaned.substring(0, 11);
    }

    String formatted = '+7';

    if (cleaned.length > 1) {
      final operatorCode = cleaned.substring(
        1,
        cleaned.length > 4 ? 4 : cleaned.length,
      );
      formatted += ' ($operatorCode';

      if (cleaned.length >= 4) {
        formatted += ') ';

        final firstPart = cleaned.substring(
          4,
          cleaned.length > 7 ? 7 : cleaned.length,
        );
        formatted += firstPart;

        if (cleaned.length >= 7) {
          formatted += '-';

          final secondPart = cleaned.substring(
            7,
            cleaned.length > 9 ? 9 : cleaned.length,
          );
          formatted += secondPart;

          if (cleaned.length >= 9) {
            formatted += '-';

            final thirdPart = cleaned.substring(
              9,
              cleaned.length > 11 ? 11 : cleaned.length,
            );
            formatted += thirdPart;
          }
        }
      }
    }

    if (_phoneController.text != formatted) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _surnameController.addListener(_onDataChanged);
    _nameController.addListener(_onDataChanged);
    _patronymicController.addListener(_onDataChanged);
    _phoneController.addListener(_onDataChanged);
    _companyController.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _auth.getCurrUserData();

      if (userData != null) {
        _userData = userData;

        _surnameController.text = userData.surname;
        _nameController.text = userData.name;
        _patronymicController.text = userData.patronymic;
        _phoneController.text = userData.phone ?? '';
        _companyController.text = userData.companyName ?? '';
      } else {
        _error = 'Не удалось загрузить данные пользователя';
      }
    } catch (e) {
      _error = 'Ошибка загрузки: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      _showError('Нет изменений для сохранения', isError: false);
      return;
    }

    // Валидация
    if (_surnameController.text.trim().isEmpty) {
      _showError('Введите фамилию');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showError('Введите имя');
      return;
    }

    if (!_validateName(_surnameController.text.trim())) {
      _showError('Фамилия может содержать только буквы, пробелы и дефис');
      return;
    }

    if (!_validateName(_nameController.text.trim())) {
      _showError('Имя может содержать только буквы, пробелы и дефис');
      return;
    }

    if (_patronymicController.text.trim().isNotEmpty &&
        !_validateName(_patronymicController.text.trim())) {
      _showError('Отчество может содержать только буквы, пробелы и дефис');
      return;
    }

    if (_phoneController.text.trim().isNotEmpty &&
        !_validatePhone(_phoneController.text.trim())) {
      _showError('Телефон должен быть в формате +7 (999) 999-99-99');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Очищаем телефон от форматирования для сохранения
      String cleanPhone = _phoneController.text.trim().replaceAll(
        RegExp(r'\D'),
        '',
      );
      if (cleanPhone.startsWith('8')) {
        cleanPhone = '7' + cleanPhone.substring(1);
      }

      await _auth.updateUserProfile(
        surname: _surnameController.text.trim(),
        name: _nameController.text.trim(),
        patronymic: _patronymicController.text.trim(),
        phone: cleanPhone,
        companyName: _companyController.text.trim(),
      );

      _hasChanges = false;
      await _loadUserData();

      if (mounted) {
        _showError('Данные обновлены', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Ошибка сохранения: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color.fromARGB(255, 228, 134, 127)
            : const Color.fromARGB(255, 121, 197, 124),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _nameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки профиля', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _buildSettingsForm(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.redApp),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppTheme.redApp)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color.fromARGB(255, 28, 90, 92),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Личная информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _userData?.role ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Фамилия
                  TextField(
                    controller: _surnameController,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Фамилия *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Имя
                  TextField(
                    controller: _nameController,
                    maxLength: 20,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Имя *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Отчество
                  TextField(
                    controller: _patronymicController,
                    maxLength: 30,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Отчество',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Телефон
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: _formatPhone,
                    inputFormatters: [LengthLimitingTextInputFormatter(18)],
                    decoration: InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      prefixIcon: Icon(Icons.phone),
                      hintText: '+7 (***) ***-**-**',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Компания
                  TextField(
                    controller: _companyController,
                    maxLength: 50,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Компания',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      prefixIcon: Icon(Icons.business_sharp),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email (неизменяемый)
                  TextField(
                    controller: TextEditingController(
                      text: _userData?.email ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Почта',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      hintText: 'email@example.com',
                    ),
                    enabled: false,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email нельзя изменить. Для смены email обратитесь к администратору.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isSaving || !_hasChanges) ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 37, 126, 129),
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'СОХРАНИТЬ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
