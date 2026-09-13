// screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/defect_model.dart';
import '../widgets/report_widget.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => ReportScreenState();
}

class ReportScreenState extends State<ReportScreen> {
  final AuthService _auth = AuthService();

  Set<String> _selectedStatuses = {};
  String? _selectedObjectId;
  String? _selectedLocationId;
  bool _showClosed = true;

  String? _userRole;
  String? _currentUserId;
  List<String> _objectIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _auth.getCurrUser()?.uid;
    final role = await _auth.getCurrUserRole();

    if (mounted) {
      setState(() {
        _currentUserId = userId;
        _userRole = role;
      });
    }

    if (role == 'Генеральный подрядчик' && userId != null) {
      await _loadObjectsForGeneralContractor(userId);
    }
  }

  Future<void> _loadObjectsForGeneralContractor(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('objects')
        .where('generalContractorId', isEqualTo: userId)
        .get();
    if (mounted) {
      setState(() {
        _objectIds = snapshot.docs.map((doc) => doc.id).toList();
      });
    }
  }

  void applyFilters(
    Set<String> statuses,
    String? objectId,
    String? locationId,
    bool showClosed,
  ) {
    if (mounted) {
      setState(() {
        _selectedStatuses = statuses;
        _selectedObjectId = objectId;
        _selectedLocationId = locationId;
        _showClosed = showClosed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final isLoggedIn = user != null;

        if (isLoggedIn && _currentUserId == null) {
          _loadUserData();
        }

        if (!isLoggedIn && _currentUserId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentUserId = null;
                _userRole = null;
                _objectIds = [];
              });
            }
          });
        }

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
                  'Для просмотра замечаний требуется авторизация',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (_userRole == null || _currentUserId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildDefectList();
      },
    );
  }

  Widget _buildDefectList() {
    Query query = FirebaseFirestore.instance.collection('defects');

    if (_userRole == 'Заказчик') {
      query = query.where('customerId', isEqualTo: _currentUserId);
    } else if (_userRole == 'Подрядчик') {
      query = query.where('contractorId', isEqualTo: _currentUserId);
    } else if (_userRole == 'Генеральный подрядчик') {
      if (_objectIds.isNotEmpty) {
        query = query.where('objectId', whereIn: _objectIds);
      } else {
        query = query.where('objectId', isEqualTo: 'none');
      }
    }

    if (_selectedStatuses.isNotEmpty) {
      query = query.where('status', whereIn: _selectedStatuses.toList());
    }

    if (_selectedObjectId != null) {
      query = query.where('objectId', isEqualTo: _selectedObjectId);
    }

    if (_selectedLocationId != null) {
      query = query.where('locationId', isEqualTo: _selectedLocationId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.redApp,
                ),
                const SizedBox(height: 16),
                Text('Ошибка: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_late, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Нет замечаний',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        List<QueryDocumentSnapshot> allDefects = snapshot.data!.docs;

        List<QueryDocumentSnapshot> filteredDefects = allDefects;
        if (!_showClosed) {
          filteredDefects = allDefects.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            return status != 'closed';
          }).toList();
        }

        if (filteredDefects.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_late, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Нет замечаний',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        filteredDefects.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['dateOfCreation'] as Timestamp?;
          final bTimestamp = bData['dateOfCreation'] as Timestamp?;
          final aDate = aTimestamp?.toDate() ?? DateTime.now();
          final bDate = bTimestamp?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDefects.length,
          itemBuilder: (context, index) {
            final defectDoc = filteredDefects[index];
            final defect = DefectModel.fromFirestore(defectDoc);
            return ReportCard(defect: defect);
          },
        );
      },
    );
  }
}
