import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diplomgrinenko/models/user_model.dart';
import 'package:diplomgrinenko/services/notification_service.dart';
import 'package:diplomgrinenko/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'analyt_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';
import 'add_report_screen.dart';
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _screenIndex = 0;
  final AuthService _auth = AuthService();
  final GlobalKey<ReportScreenState> _reportScreenKey = GlobalKey();

  Set<String> _selectedStatuses = {};
  String? _selectedObjectId;
  String? _selectedLocationId;
  bool _showClosed = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.hasData && snapshot.data != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _getTitle(_screenIndex),
              style: const TextStyle(fontSize: 18),
            ),
            centerTitle: true,
            actions: isLoggedIn ? _getActions(_screenIndex, context) : [],
          ),
          body: IndexedStack(
            index: _screenIndex,
            children: [
              const HomeScreen(),
              ReportScreen(key: _reportScreenKey),
              const AnalyticsScreen(),
              const ProfileScreen(),
            ],
          ),
          floatingActionButton: isLoggedIn && _screenIndex == 0
              ? _getFloatingActionButton(_screenIndex, context)
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _screenIndex,
            onTap: (index) {
              setState(() {
                _screenIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.cottage_sharp),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_sharp),
                label: 'Замечания',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.area_chart_sharp),
                label: 'Аналитика',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTitle(int k) {
    switch (k) {
      case 0:
        return 'Главная';
      case 1:
        return 'Замечания';
      case 2:
        return 'Аналитика';
      case 3:
        return 'Профиль';
      default:
        return 'Главная';
    }
  }

  List<Widget> _getActions(int k, BuildContext context) {
    switch (k) {
      case 0:
        return [
          StreamBuilder<int>(
            stream: NotificationService().getUnreadCount(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'Уведомления',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.redApp,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ];
      case 1:
        return [
          IconButton(
            onPressed: () {
              _showFilter(context);
            },
            icon: const Icon(Icons.filter_list),
            tooltip: 'Фильтр',
          ),
        ];
      case 2:
        return [];
      case 3:
        return [
          IconButton(
            onPressed: () {
              _showSettings(context);
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
          ),
        ];
      default:
        return [];
    }
  }

  Widget? _getFloatingActionButton(int k, BuildContext context) {
    if (k == 0) {
      return FutureBuilder<UserModel?>(
        future: _auth.getCurrUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          final userData = snapshot.data;
          if (userData?.role == 'Заказчик') {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddReportScreen(),
                  ),
                );
              },
              tooltip: 'Добавить отчёт',
              backgroundColor: const Color.fromARGB(255, 37, 126, 129),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }
    return null;
  }

  void _showFilter(BuildContext context) {
    Set<String> tempStatuses = Set.from(_selectedStatuses);
    String? tempObjectId = _selectedObjectId;
    String? tempLocationId = _selectedLocationId;
    bool tempShowClosed = _showClosed;

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
                    'Фильтры',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  '    Статусы замечаний',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Новое'),
                        value: tempStatuses.contains('new'),
                        onChanged: (checked) {
                          setBottomSheetState(() {
                            if (checked == true) {
                              tempStatuses.add('new');
                            } else {
                              tempStatuses.remove('new');
                            }
                          });
                        },
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('В работе'),
                        value: tempStatuses.contains('in_progress'),
                        onChanged: (checked) {
                          setBottomSheetState(() {
                            if (checked == true) {
                              tempStatuses.add('in_progress');
                            } else {
                              tempStatuses.remove('in_progress');
                            }
                          });
                        },
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('На проверке'),
                        value: tempStatuses.contains('fixed'),
                        onChanged: (checked) {
                          setBottomSheetState(() {
                            if (checked == true) {
                              tempStatuses.add('fixed');
                            } else {
                              tempStatuses.remove('fixed');
                            }
                          });
                        },
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('Принято'),
                        value: tempStatuses.contains('verified'),
                        onChanged: (checked) {
                          setBottomSheetState(() {
                            if (checked == true) {
                              tempStatuses.add('verified');
                            } else {
                              tempStatuses.remove('verified');
                            }
                          });
                        },
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text('Переоткрыто'),
                        value: tempStatuses.contains('reopened'),
                        onChanged: (checked) {
                          setBottomSheetState(() {
                            if (checked == true) {
                              tempStatuses.add('reopened');
                            } else {
                              tempStatuses.remove('reopened');
                            }
                          });
                        },
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('objects')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final objects = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: tempObjectId,
                      hint: const Text(
                        'Все объекты',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Все объекты',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ...objects.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              data['name'] ?? 'Без названия',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setBottomSheetState(() {
                          tempObjectId = value;
                          tempLocationId = null;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                if (tempObjectId != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('locations')
                        .where('objectId', isEqualTo: tempObjectId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final locations = snapshot.data!.docs;
                      final locationItems = locations.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        String name = '';
                        if (data['floor'] != null && data['number'] != null) {
                          name = '${data['floor']} эт. пом.${data['number']}';
                        } else {
                          name = data['number'] ?? 'Помещение';
                        }
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(name),
                        );
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: tempLocationId,
                        hint: const Text('Все помещения'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Все помещения'),
                          ),
                          ...locationItems,
                        ],
                        onChanged: (value) {
                          setBottomSheetState(() {
                            tempLocationId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                SwitchListTile(
                  title: const Text(
                    'Показывать закрытые замечания',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  value: tempShowClosed,
                  onChanged: (value) {
                    setBottomSheetState(() {
                      tempShowClosed = value;
                    });
                  },
                ),

                const Divider(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setBottomSheetState(() {
                            tempStatuses.clear();
                            tempObjectId = null;
                            tempLocationId = null;
                            tempShowClosed = true;
                          });
                        },
                        child: const Text('Сбросить все'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatuses = tempStatuses;
                            _selectedObjectId = tempObjectId;
                            _selectedLocationId = tempLocationId;
                            _showClosed = tempShowClosed;
                          });

                          _reportScreenKey.currentState?.applyFilters(
                            _selectedStatuses,
                            _selectedObjectId,
                            _selectedLocationId,
                            _showClosed,
                          );

                          Navigator.pop(context);
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
                          'Применить',
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

  void _showSettings(BuildContext context) async {
    final shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    if (shouldRefresh == true && mounted) {
      _reportScreenKey.currentState?.applyFilters(
        _selectedStatuses,
        _selectedObjectId,
        _selectedLocationId,
        _showClosed,
      );
    }
  }
}
