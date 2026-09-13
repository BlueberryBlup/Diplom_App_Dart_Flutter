import 'package:diplomgrinenko/screens/object_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/object_model.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final isLoggedIn = authSnapshot.hasData && authSnapshot.data != null;

        if (!isLoggedIn) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Войдите в аккаунт',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Для просмотра объектов требуется авторизация',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildContent(authSnapshot.data!);
      },
    );
  }

  Widget _buildContent(User user) {
    return FutureBuilder<String?>(
      future: _auth.getCurrUserRole(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userRole = userSnapshot.data;
        final currentUserId = user.uid;

        return RefreshIndicator(
          onRefresh: () async {},
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(25, 16, 30, 16),
                child: const Text(
                  'Ваши объекты:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(child: _buildObjectsList(userRole, currentUserId)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildObjectsList(String? userRole, String currentUserId) {
    if (userRole == 'Подрядчик') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('defects')
            .where('contractorId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final defects = snapshot.data!.docs;

          if (defects.isEmpty) {
            return const Center(
              child: Text('Нет объектов', style: TextStyle(color: Colors.grey)),
            );
          }

          final Set<String> objectIds = {};
          for (final defect in defects) {
            final defectData = defect.data() as Map<String, dynamic>;
            final objectId = defectData['objectId'];
            if (objectId != null) {
              objectIds.add(objectId);
            }
          }

          if (objectIds.isEmpty) {
            return const Center(
              child: Text('Нет объектов', style: TextStyle(color: Colors.grey)),
            );
          }

          return FutureBuilder<List<ObjectModel>>(
            future: _getObjectsByIds(objectIds.toList()),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Нет объектов',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final objects = futureSnapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: objects.length,
                itemBuilder: (context, index) {
                  final object = objects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
        },
      );
    }

    String fieldName;
    if (userRole == 'Заказчик') {
      fieldName = 'customerId';
    } else if (userRole == 'Генеральный подрядчик') {
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
          .where(fieldName, isEqualTo: currentUserId)
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
              margin: const EdgeInsets.only(bottom: 12),
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

  Future<List<ObjectModel>> _getObjectsByIds(List<String> objectIds) async {
    if (objectIds.isEmpty) return [];

    final List<ObjectModel> objects = [];

    for (final id in objectIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('objects')
            .doc(id)
            .get();

        if (doc.exists) {
          objects.add(ObjectModel.fromFirestore(doc));
        }
        // ignore: empty_catches
      } catch (e) {}
    }

    return objects;
  }
}
