import 'package:diplomgrinenko/screens/object_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/object_model.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();

  String? _userRole;
  String? _currentUserId;
  bool _isLoading = true;

  @override //переопределение метода от родительского класса
  void initState() {
    super.initState(); //обязательный вызов родительского клсасса
    _loadCurrentUser();
  }

  //получаем нашего пользователя
  Future<void> _loadCurrentUser() async {
    if (!mounted) return; //если экран закрылся, не обновляемся

    try {
      final user = _auth.getCurrUser();

      if (user == null) {
        //пользователя не существует
        if (mounted) {
          setState(() {
            _isLoading = false;
            _userRole = null;
            _currentUserId = null;
          });
        }
        return;
      }

      _currentUserId = user.uid;
      final userData = await _auth.getCurrUserData();

      if (mounted) {
        setState(() {
          _userRole = userData?.role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  //вывод последних обновлений
  Widget build(BuildContext context) {
    //final comments = MockData.getComments();
   // final int itemCount = comments.length > 3 ? 3 : comments.length;

    return RefreshIndicator(
      //потянуть, чтобы обновить инфу
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 25, 30, 16),
            child: const Text(
              'Последние обновления:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),

          //обновления
          Expanded(
            flex: 1,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              //itemCount: itemCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  //child: CommentCard(comment: comments[index]),
                );
              },
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 16, 30, 16),
            child: const Text(
              'Ваши объекты:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),

          Expanded(flex: 1, child: _buildObjectsList()),
        ],
      ),
    );
  }

  Widget _buildObjectsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    //если пользователя нет
    if (_currentUserId == null) {
      return const Center(
        child: Text(
          'Войдите в аккаунт для просмотра объектов',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    //для подрядчика
    if (_userRole == 'Подрядчик') {
      return const Center(
        child: Text(
          'У вас нет доступа к объектам',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    String fieldName;
    if (_userRole == 'Заказчик') {
      fieldName = 'customerId';
    } else if (_userRole == 'Генеральный подрядчик') {
      fieldName = 'generalContractorId';
    } else {
      return const Center(
        child: Text(
          'Неизвестная роль пользователя',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('objects')
          .where(fieldName, isEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final objects = snapshot.data!.docs;

        if (objects.isEmpty) {
          return const Center(
            child: Text('Нет объектов', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: objects.length,
          itemBuilder: (context, index) {
            final objectDoc = objects[index];
            final object = ObjectModel.fromFirestore(objectDoc);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.business,
                  color: Color.fromARGB(255, 48, 74, 92),
                ),
                title: Text(
                  object.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  object.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ObjectInfoScreen(
                        objectId: object.id,
                        objectName: object.name,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
