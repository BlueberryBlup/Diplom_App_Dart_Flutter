import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diplomgrinenko/widgets/contractor_stats_widget.dart';
import '../theme/app_theme.dart';
import 'package:diplomgrinenko/screens/contractors_top_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../models/analytics_model.dart';
import '../models/defect_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AuthService _auth = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();

  String? _userRole;
  String? _userId;
  List<Map<String, dynamic>> _objects = [];
  String? _selectedObjectId;
  AnalyticsModel? _analytics;
  bool _isLoading = true;
  bool _isLoadingAnalytics = false;

  List<Map<String, dynamic>> _expiringDefects = [];
  bool _isLoadingExpiring = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
                  'Для просмотра аналитики требуется авторизация',
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
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userRole = roleSnapshot.data;
        final userId = user.uid;

        if (_userRole != userRole || _userId != userId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _userRole = userRole;
              _userId = userId;
              _objects = [];
              _selectedObjectId = null;
              _analytics = null;
              _expiringDefects = [];
              _isLoading = true;
            });
            _loadObjects();
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (_userRole == null || _userId == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildAnalyticsContent();
      },
    );
  }

  Future<void> _loadObjects() async {
    if (!mounted) return;
    if (_userId == null || _userRole == null) return;

    final objects = await _analyticsService.getUserObjects(
      _userId!,
      _userRole!,
    );

    if (!mounted) return;

    setState(() {
      _objects = objects;
      _isLoading = false;
      if (objects.isNotEmpty) {
        _selectedObjectId = objects.first['id'];
        _loadAnalytics();
        _loadExpiringDefects();
      }
    });
  }

  Future<void> _loadAnalytics() async {
    if (_selectedObjectId == null) return;
    if (!mounted) return;

    setState(() {
      _isLoadingAnalytics = true;
    });

    final analytics = await _analyticsService.getAnalytics(_selectedObjectId!);

    if (!mounted) return;

    setState(() {
      _analytics = analytics;
      _isLoadingAnalytics = false;
    });
  }

  Future<void> _loadExpiringDefects() async {
    if (_selectedObjectId == null) return;
    if (!mounted) return;

    setState(() {
      _isLoadingExpiring = true;
    });

    try {
      final today = DateTime.now();
      final threeDaysLater = today.add(const Duration(days: 3));

      final snapshot = await FirebaseFirestore.instance
          .collection('defects')
          .where('objectId', isEqualTo: _selectedObjectId)
          .get();

      final expiringDefectsRaw = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final defect = DefectModel.fromFirestore(doc);

        if (defect.status == 'verified' || defect.status == 'closed') {
          continue;
        }

        final deadline = defect.deadline;
        if (deadline == null) continue;

        if (deadline.isBefore(threeDaysLater)) {
          expiringDefectsRaw.add({
            'id': defect.id,
            'name': defect.name,
            'deadline': deadline,
            'status': defect.status,
            'contractorId': defect.contractorId,
          });
        }
      }

      expiringDefectsRaw.sort((a, b) {
        final aDate = a['deadline'] as DateTime;
        final bDate = b['deadline'] as DateTime;
        return aDate.compareTo(bDate);
      });

      final expiringDefects = expiringDefectsRaw.take(5).toList();

      for (var defect in expiringDefects) {
        final contractorId = defect['contractorId'];
        if (contractorId != null && contractorId.toString().isNotEmpty) {
          final contractorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(contractorId.toString())
              .get();
          if (contractorDoc.exists) {
            final contractorData = contractorDoc.data();
            defect['contractorName'] =
                '${contractorData?['surname']} ${contractorData?['name']}';
          } else {
            defect['contractorName'] = 'Не назначен';
          }
        } else {
          defect['contractorName'] = 'Не назначен';
        }
      }

      if (mounted) {
        setState(() {
          _expiringDefects = expiringDefects;
          _isLoadingExpiring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExpiring = false;
          _expiringDefects = [];
        });
      }
    }
  }

  Widget _buildAnalyticsContent() {
    if (_userRole != 'Заказчик' && _userRole != 'Генеральный подрядчик') {
      return ContractorStatsWidget(
        contractorId: _userId!,
        contractorName: 'Моя статистика',
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_objects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Нет доступных объектов',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isLoadingAnalytics || _analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAnalytics();
        await _loadExpiringDefects();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedObjectId,
                        isExpanded: true,
                        items: _objects.map<DropdownMenuItem<String>>((obj) {
                          return DropdownMenuItem<String>(
                            value: obj['id'] as String,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(obj['name']),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (!mounted) return;
                          setState(() {
                            _selectedObjectId = value;
                            _loadAnalytics();
                            _loadExpiringDefects();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedObjectId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContractorTopScreen(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text('Рейтинг'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildStatsGrid(),
            const SizedBox(height: 24),

            _buildDefectsSection(),
            const SizedBox(height: 24),

            const Text(
              'Аналитика по замечаниям',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'По видам',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 300, child: _buildCategoryChart()),
              ],
            ),

            const SizedBox(height: 24),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'По статусам',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 300, child: _buildStatusChart()),
              ],
            ),

            const SizedBox(height: 24),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'По приоритетам',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 300, child: _buildSeverityChart()),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Замечания по помещениям',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            SizedBox(height: 300, child: _buildBarChart()),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectsSection() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.orangeApp),
                SizedBox(width: 8),
                Text(
                  'Замечания, требующие внимания',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Замечания, срок которых истекает или уже истёк',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            if (_isLoadingExpiring)
              const Center(child: CircularProgressIndicator())
            else if (_expiringDefects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Нет замечаний с истекающим сроком',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _expiringDefects.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final defect = _expiringDefects[index];
                  final deadline = defect['deadline'] as DateTime?;
                  if (deadline == null) return const SizedBox.shrink();

                  final daysLeft = _getDaysLeft(deadline);
                  final isOverdue = _isOverdue(deadline);

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isOverdue
                          ? AppTheme.redApp.withOpacity(0.2)
                          : AppTheme.orangeApp.withOpacity(0.2),
                      child: Icon(
                        Icons.warning,
                        color: isOverdue ? AppTheme.redApp : AppTheme.orangeApp,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      defect['name'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Подрядчик: ${defect['contractorName']}\nСрок: ${_formatDate(deadline)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isOverdue
                        ? const Chip(
                            label: Text('Просрочено'),
                            backgroundColor: AppTheme.redApp,
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          )
                        : daysLeft == 0
                        ? const Chip(
                            label: Text('Сегодня'),
                            backgroundColor: AppTheme.orangeApp,
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          )
                        : Chip(
                            label: Text('$daysLeft дн.'),
                            backgroundColor: AppTheme.blueApp,
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                    dense: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  int _getDaysLeft(DateTime deadline) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    return deadlineDate.difference(todayDate).inDays;
  }

  bool _isOverdue(DateTime deadline) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    return deadlineDate.isBefore(todayDate);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не указан';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Widget _buildStatsGrid() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Общая статистика',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildStatRow(
              'Всего замечаний',
              _analytics!.totalDefects,
              AppTheme.darkBlueApp,
            ),
            _buildStatRow('Новых', _analytics!.newDefects, AppTheme.orangeApp),
            _buildStatRow(
              'В работе',
              _analytics!.inProgressDefects,
              AppTheme.purpleApp,
            ),
            _buildStatRow(
              'Закрытых',
              _analytics!.closedDefects,
              AppTheme.greenApp,
            ),
            _buildStatRow(
              'Критических',
              _analytics!.criticalDefects,
              AppTheme.redApp,
            ),
            _buildStatRow('Помещений', _analytics!.totalLocations, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String title, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              ),
            ],
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    final data = _analytics!.defectsByCategory;
    if (data.isEmpty) {
      return const Center(child: Text('Нет данных по категориям'));
    }

    final colors = [
      const Color.fromARGB(255, 81, 138, 212),
      const Color.fromARGB(255, 125, 173, 235),
      const Color.fromARGB(255, 55, 118, 199),
      const Color.fromARGB(255, 113, 189, 233),
      const Color.fromARGB(255, 67, 179, 231),
      const Color.fromARGB(255, 72, 69, 231),
      const Color.fromARGB(255, 55, 57, 172),
      const Color.fromARGB(255, 135, 124, 233),
    ];
    int colorIndex = 0;

    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.key}\n${entry.value}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            color: color,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildStatusChart() {
    final statusMap = {
      'new': 'Новые',
      'in_progress': 'В работе',
      'fixed': 'На проверке',
      'verified': 'Принято',
      'closed': 'Закрыто',
    };

    final data = <String, int>{};
    for (final entry in _analytics!.defectsByStatus.entries) {
      final key = statusMap[entry.key] ?? entry.key;
      data[key] = entry.value;
    }

    if (data.isEmpty) {
      return const Center(child: Text('Нет данных по статусам'));
    }

    final colors = [
      const Color.fromARGB(255, 171, 217, 255),
      const Color.fromARGB(255, 91, 181, 233),
      AppTheme.purpleApp,
      AppTheme.pinkApp,
      const Color.fromARGB(255, 106, 139, 230),
    ];
    int colorIndex = 0;

    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.key}\n${entry.value}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            color: color,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildSeverityChart() {
    final severityMap = {
      'minor': 'Незначительные',
      'major': 'Значительные',
      'critical': 'Критические',
    };

    final data = <String, int>{};
    for (final entry in _analytics!.defectsBySeverity.entries) {
      final key = severityMap[entry.key] ?? entry.key;
      data[key] = entry.value;
    }

    if (data.isEmpty) {
      return const Center(child: Text('Нет данных по приоритетам'));
    }

    final colors = [AppTheme.greenApp, AppTheme.orangeApp, AppTheme.redApp];
    int colorIndex = 0;

    return PieChart(
      PieChartData(
        sections: data.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.key}\n${entry.value}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            color: color,
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildBarChart() {
    final data = _analytics!.defectsByLocation;
    if (data.isEmpty) {
      return const Center(child: Text('Нет данных по помещениям'));
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(8).toList();

    return FutureBuilder<Map<String, String>>(
      future: _loadLocationNames(topEntries),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox(
            height: 300,
            child: Center(child: Text('Нет данных о помещениях')),
          );
        }

        final locationNames = snapshot.data!;
        final maxValue = topEntries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

        final List<Color> barColors = [
          AppTheme.blueApp,
          AppTheme.greenApp,
          AppTheme.orangeApp,
          AppTheme.purpleApp,
          AppTheme.redApp,
          Colors.teal,
          Colors.indigo,
          AppTheme.pinkApp,
        ];

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue + 1,
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: true,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: 1,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    if (value == value.toInt().toDouble()) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < topEntries.length) {
                      final locationId = topEntries[index].key;
                      final name = locationNames[locationId] ?? '?';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                  reservedSize: 70,
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
            barGroups: topEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final dataEntry = entry.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: dataEntry.value.toDouble(),
                    color: barColors[index % barColors.length],
                    width: 30,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue,
                      color: Colors.grey.shade100,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _loadLocationNames(
    List<MapEntry<String, int>> locations,
  ) async {
    final Map<String, String> names = {};
    for (final entry in locations) {
      final locationId = entry.key;
      try {
        final locationDoc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locationId)
            .get();
        if (locationDoc.exists) {
          final data = locationDoc.data();
          if (data != null) {
            final number = data['number'];
            if (number != null) {
              names[locationId] = 'пом.$number';
            } else {
              names[locationId] = 'Помещение ${locationId.substring(0, 6)}';
            }
          } else {
            names[locationId] = 'Помещение ${locationId.substring(0, 6)}';
          }
        } else {
          names[locationId] = 'Помещение ${locationId.substring(0, 6)}';
        }
      } catch (e) {
        names[locationId] = 'Помещение ${locationId.substring(0, 6)}';
      }
    }
    return names;
  }
}
