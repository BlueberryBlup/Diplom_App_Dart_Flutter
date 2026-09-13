import 'package:diplomgrinenko/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //регистрация
  Future<User?> regWithEmail({
    
    required String email, 
    required String password,
    required String surname,
    required String name,
    required String patronymic,
    required String role,
    required String category,
    String? phone,
    String? companyName,
  }) async {
    try {
      final UserCredential userCredential =
          await _auth 
              .createUserWithEmailAndPassword(email: email, password: password);
      final String uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'surname': surname,
        'name': name,
        'patronymic': patronymic,
        'role': role,
        'phone': phone ?? '',
        'companyName': companyName ?? '',
        'category': category,
      });
      return userCredential.user;
    } catch (e) {
      throw Exception('Ошибка регистрации: $e');
    }
  }

  //вход
  Future<User?> signinWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }

  //выход
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Ошибка выхода: $e');
    }
  }

  //получение юзера
  User? getCurrUser() {
    return _auth.currentUser;
  }

  //информация о пользователе
  Future<UserModel?> getCurrUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  //проверка на авторизацию
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  //получение роли пользователя
  Future<String?> getCurrUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'];
  }

  Future<void> updateUserProfile({
    required String surname,
    required String name,
    required String patronymic,
    required String phone,
    String? avatarPath,
    String? companyName,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      final Map<String, dynamic> updateData = {
        'surname': surname,
        'name': name,
        'patronymic': patronymic,
        'phone': phone,
      };

      if (companyName != null) {
        updateData['companyName'] = companyName;
      }
      if (avatarPath != null) {
        updateData['avatarPath'] == avatarPath;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);
    } catch (e) {
      throw Exception('Ошибка обновления данных: $e');
    }
  }

  Future<void> updateAvatarPath(String avatarPath) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      await _firestore.collection('users').doc(user.uid).update({
        'avatarPath': avatarPath,
      });
    } catch (e) {
      throw Exception('Ошибка обновления аватара: $e');
    }
  }
}
