import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String surname;
  final String name;
  final String patronymic;
  final String role;
  final String? companyName;
  final String? phone;
  final String category;

  UserModel({
    required this.id,
    required this.email,
    required this.surname,
    required this.name,
    required this.patronymic,
    required this.role,
    this.companyName,
    this.phone,
    required this.category,
  });

  //Firebase -> Dart
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      surname: data['surname'] ?? '',
      name: data['name'] ?? '',
      patronymic: data['patronymic'] ?? '',
      role: data['role'] ?? '',
      companyName: data['companyName'],
      phone: data['phone'] ?? '',
      category: data['category'] ?? '',
    );
  }

  //Dart -> Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'surname': surname,
      'name': name,
      'patronymic': patronymic,
      'role': role,
      'companyName': companyName,
      'phone': phone,
      'category': category,
    };
  }
}
