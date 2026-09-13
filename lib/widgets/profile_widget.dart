import 'package:diplomgrinenko/widgets/auth_widget.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../functions.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  final AuthService _auth = AuthService();

  UserModel? _cachedUserData;
  bool _isDataLoaded = false;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    if (!mounted) return;

    final user = _auth.getCurrUser();

    if (user == null) {
      _cachedUserData = null;
      _isDataLoaded = false;
      if (mounted) {
        setState(() {}); //показываем, что нужно обновить данные
      }
      return;
    }

    if (_isDataLoaded && _cachedUserData != null) {
      return;
    }

    await _loadUserData(user.uid);
  }

  Future<void> _loadUserData(String userId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _auth.getCurrUserData();

      if (!mounted) return;

      if (userData != null) {
        _cachedUserData = userData;
        _isDataLoaded = true;

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Пользователь не найден';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _cachedUserData = null;
    _isDataLoaded = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> refreshUserData() async {
    final user = _auth.getCurrUser();
    if (user != null) {
      _cachedUserData = null;
      _isDataLoaded = false;
      await _loadUserData(user.uid);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildProfile() {
    if (_cachedUserData != null && _isDataLoaded) {
      return RefreshIndicator(
        onRefresh: refreshUserData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: _buildProfileContent(_cachedUserData!),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppTheme.redApp),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _logout, child: const Text('Повторить')),
          ],
        ),
      );
    }

    return _buildProfileContent(_cachedUserData!);
  }

  Widget _buildProfileContent(UserModel user) {
    final String name = getValue(user.name);
    final String surname = getValue(user.surname);
    final String patronymic = getValue(user.patronymic);
    final String email = getValue(user.email);
    final String role = getValue(user.role);
    final String companyName = getValue(user.companyName);
    final String phone = formatPhoneForDisplay(getValue(user.phone));

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color.fromARGB(255, 48, 74, 92),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),

            Text(
              '$surname $name $patronymic',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              softWrap: true,
            ),
            const SizedBox(height: 6),

            Text(
              role,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text(email),
                    subtitle: const Text('Почта'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: Text(phone),
                    subtitle: const Text('Телефон'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: Text(companyName),
                    subtitle: const Text('Компания'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redApp,
                foregroundColor: Colors.white,
              ),
              child: const Text('Выйти из аккаунта'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.getCurrUser();

    if (user == null) {
      if (_cachedUserData != null) {
        _cachedUserData = null;
        _isDataLoaded = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      });
      return const Center(child: CircularProgressIndicator());
    }

    return _buildProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
