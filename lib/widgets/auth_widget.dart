import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/defect_model.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signinWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        _emailController.clear();
        _passwordController.clear();
      }
    } catch (e) {
      _showError('Неверная почта или пароль');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.redApp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Color.fromARGB(255, 28, 90, 92),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Почта',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 28, 90, 92),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Войти',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Нет аккаунта?'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    } catch (e, stackTrace) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка навигации: $e')),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color.fromARGB(255, 28, 90, 92),
                    ),
                  ),
                  child: const Text(
                    'Зарегистрироваться',
                    style: TextStyle(color: Color.fromARGB(255, 28, 90, 92)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patronymicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();

  String _selectedRole = 'Подрядчик';
  String _selectedCategory = 'Сантехника';
  bool _isLoading = false;

  bool _validateName(String name) {
    if (name.isEmpty) return false;
    final RegExp nameRegex = RegExp(r'^[a-zA-Zа-яА-ЯёЁ\s\-]+$');
    return nameRegex.hasMatch(name);
  }

  bool _validatePhone(String phone) {
    if (phone.isEmpty) return true;
    final RegExp phoneRegex = RegExp(r'^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$');
    return phoneRegex.hasMatch(phone);
  }

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

  Future<void> _register() async {
    if (_passwordController.text != _confirmController.text) {
      _showError('Пароли не совпадают');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Пароль должен содержать минимум 6 символов');
      return;
    }

    if (!_validateName(_surnameController.text)) {
      _showError('Фамилия может содержать только буквы, пробелы и дефис');
      return;
    }

    if (!_validateName(_nameController.text)) {
      _showError('Имя может содержать только буквы, пробелы и дефис');
      return;
    }

    if (_patronymicController.text.isNotEmpty &&
        !_validateName(_patronymicController.text)) {
      _showError('Отчество может содержать только буквы, пробелы и дефис');
      return;
    }

    if (_phoneController.text.isNotEmpty &&
        !_validatePhone(_phoneController.text)) {
      _showError('Телефон должен быть в формате +7 (999) 999-99-99');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showError('Введите email');
      return;
    }

    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _showError('Введите корректный email');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final category = _selectedRole == 'Подрядчик' ? _selectedCategory : '';

      String cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('8')) {
        cleanPhone = '7' + cleanPhone.substring(1);
      }

      await _auth.regWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        surname: _surnameController.text.trim(),
        name: _nameController.text.trim(),
        patronymic: _patronymicController.text.trim(),
        role: _selectedRole,
        category: category,
        phone: cleanPhone,
        companyName: _companyController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError(
        'Ошибка регистрации: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.redApp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            //фамилия
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.person, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Фамилия *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _surnameController,
              maxLength: 30,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Введите вашу фамилию...',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 20),

            //имя
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.person, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Имя *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 20,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Введите ваше имя...',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            //отчество
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.person, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Отчество*',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _patronymicController,
              maxLength: 30,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Введите ваше отчество...',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Email
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.email, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Почта *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              maxLength: 40,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'example@mail.ru',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Пароль
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.lock, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Пароль *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              maxLength: 30,
              obscureText: true,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Придумайте пароль (мин. 6 символов)',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            //подтверждение
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Подтверждение пароля *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Повторите пароль',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            //телефон
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.phone, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Телефон',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: _formatPhone,
              decoration: InputDecoration(
                hintText: '+7 (***) ***-**-**',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            //роль
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.badge, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Роль *',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Заказчик',
                  child: Text(
                    'Заказчик',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Генеральный подрядчик',
                  child: Text(
                    'Генеральный подрядчик',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Подрядчик',
                  child: Text(
                    'Подрядчик',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
            const SizedBox(height: 20),

            if (_selectedRole == "Подрядчик") ...[
              Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.work, size: 20, color: Colors.grey[700]),
                  const SizedBox(width: 12),
                  Text(
                    'Вид работ *',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: BorderSide(
                      width: 0.8,
                      color: const Color.fromARGB(255, 83, 116, 79),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: const BorderSide(
                      width: 1.2,
                      color: Color.fromARGB(255, 37, 126, 129),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: DefectModel.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      style: TextStyle(fontWeight: FontWeight.w400),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
            ],

            //компания
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.business, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Название компании',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _companyController,
              maxLength: 30,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Введите название компании...',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: BorderSide(
                    width: 0.8,
                    color: const Color.fromARGB(255, 83, 116, 79),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                  borderSide: const BorderSide(
                    width: 1.2,
                    color: Color.fromARGB(255, 37, 126, 129),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Кнопка регистрации
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 28, 90, 92),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Зарегистрироваться',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _surnameController.dispose();
    _nameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }
}
