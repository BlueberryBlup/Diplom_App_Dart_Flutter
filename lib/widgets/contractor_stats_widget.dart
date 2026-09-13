// widgets/contractor_stats_widget.dart
import 'package:diplomgrinenko/functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/rating_service.dart';
import '../models/review_model.dart';
import '../models/defect_model.dart';
import '../theme/app_theme.dart';

class ContractorStatsWidget extends StatefulWidget {
  final String contractorId;
  final String contractorName;

  const ContractorStatsWidget({
    super.key,
    required this.contractorId,
    required this.contractorName,
  });

  @override
  State<ContractorStatsWidget> createState() => _ContractorStatsWidgetState();
}

class _ContractorStatsWidgetState extends State<ContractorStatsWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String? _companyName;
  String? _phoneNumber;
  String? _emailStr;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final contractorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.contractorId)
          .get();
      if (!mounted) return;
      _companyName = contractorDoc.data()?['companyName'];
      _phoneNumber = contractorDoc.data()?['phone'];
      _emailStr = contractorDoc.data()?['email'];

      final defects = await RatingService.getContractorDefects(
        widget.contractorId,
      );
      if (!mounted) return;
      final feedbacks = await RatingService.getContractorFeedbacks(
        widget.contractorId,
      );
      if (!mounted) return;
      final rating = await RatingService.calculateRatingWithFeedback(
        widget.contractorId,
      );
      if (!mounted) return;

      final stats = _calculateStats(defects, feedbacks, rating);

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _calculateStats(
    List<DefectModel> defects,
    List<ContrReviewModel> feedbacks,
    double rating,
  ) {
    final totalDefects = defects.length;

    if (totalDefects == 0) {
      return {
        'totalDefects': 0,
        'fixedDefects': 0,
        'openDefects': 0,
        'inProgressDefects': 0,
        'reopenedDefects': 0,
        'avgIterations': 0.0,
        'avgFixTime': 0.0,
        'avgReactionTime': 0.0,
        'successRate': 0.0,
        'overdueDaysTotal': 0,
        'criticalPercentage': 0.0,
        'rating': rating,
        'feedbackCount': feedbacks.length,
        'avgCommunication': 0.0,
        'avgMaterials': 0.0,
        'avgWorkQuality': 0.0,
      };
    }

    int fixedDefects = 0;
    int openDefects = 0;
    int inProgressDefects = 0;
    int reopenedDefects = 0;

    int totalIterations = 0;
    int criticalCount = 0;
    int overdueDaysTotal = 0;
    double totalFixHours = 0;
    double totalReactionHours = 0;
    int fixCount = 0;
    int reactionCount = 0;

    for (final defect in defects) {
      // Статистика по статусам
      if (defect.status == 'verified' || defect.status == 'closed') {
        fixedDefects++;
      } else if (defect.status == 'new') {
        openDefects++;
      } else if (defect.status == 'in_progress') {
        inProgressDefects++;
      }

      // Переоткрытые замечания
      if (defect.iterCount > 1 &&
          defect.status != 'verified' &&
          defect.status != 'closed') {
        reopenedDefects++;
      }

      totalIterations += defect.iterCount;
      if (defect.severity == 'critical') criticalCount++;

      if (defect.deadline != null) {
        final deadline = defect.deadline!;

        // 1. Просрочка по датам исправления
        for (final correctDate in defect.datesOfCorrect) {
          if (correctDate.isAfter(deadline)) {
            overdueDaysTotal += correctDate.difference(deadline).inDays;
          }
        }

        // 2. Если замечание НЕ закрыто и текущая дата после дедлайна
        if (defect.status != 'verified' && defect.status != 'closed') {
          final now = DateTime.now();
          if (now.isAfter(deadline)) {
            overdueDaysTotal += now.difference(deadline).inDays;
          }
        }
      }
      
      // Время реакции
      if (defect.datesOfStart.isNotEmpty) {
        for (int i = 0; i < defect.datesOfStart.length; i++) {
          final startDate = defect.datesOfStart[i];

          DateTime previousDate;
          if (i == 0) {
            previousDate = defect.dateOfCreation;
          } else if (i - 1 < defect.datesOfReopened.length) {
            previousDate = defect.datesOfReopened[i - 1];
          } else {
            previousDate = defect.dateOfCreation;
          }

          final reactionHours = startDate
              .difference(previousDate)
              .inHours
              .toDouble();

          if (reactionHours >= 0) {
            totalReactionHours += reactionHours;
            reactionCount++;
          }
        }
      } else {}

      // Время исправления
      if (defect.datesOfCorrect.isNotEmpty && defect.datesOfStart.isNotEmpty) {
        final minLength =
            defect.datesOfCorrect.length < defect.datesOfStart.length
            ? defect.datesOfCorrect.length
            : defect.datesOfStart.length;

        for (int i = 0; i < minLength; i++) {
          final fixHours = defect.datesOfCorrect[i]
              .difference(defect.datesOfStart[i])
              .inHours
              .toDouble();

          if (fixHours >= 0) {
            totalFixHours += fixHours;
            fixCount++;
          }
        }
      } else {}
    }

    double avgCommunication = 0;
    double avgMaterials = 0;
    double avgWorkQuality = 0;

    if (feedbacks.isNotEmpty) {
      double totalCommunication = 0;
      double totalMaterials = 0;
      double totalWorkQuality = 0;

      for (final f in feedbacks) {
        totalCommunication += f.communication;
        totalMaterials += f.materials;
        totalWorkQuality += f.workQuality;
      }
      avgCommunication = totalCommunication / feedbacks.length;
      avgMaterials = totalMaterials / feedbacks.length;
      avgWorkQuality = totalWorkQuality / feedbacks.length;
    }

    return {
      'totalDefects': totalDefects,
      'fixedDefects': fixedDefects,
      'openDefects': openDefects,
      'inProgressDefects': inProgressDefects,
      'reopenedDefects': reopenedDefects,
      'avgIterations': totalIterations / totalDefects,
      'avgFixTime': fixCount > 0 ? totalFixHours / fixCount : 0.0,
      'avgReactionTime': reactionCount > 0
          ? totalReactionHours / reactionCount
          : 0.0,
      'successRate': (fixedDefects / totalDefects) * 100,
      'overdueDaysTotal': overdueDaysTotal,
      'criticalPercentage': (criticalCount / totalDefects) * 100,
      'rating': rating,
      'feedbackCount': feedbacks.length,
      'avgCommunication': avgCommunication,
      'avgMaterials': avgMaterials,
      'avgWorkQuality': avgWorkQuality,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return const Center(child: Text('Нет данных'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_companyName != null && _companyName!.isNotEmpty)
            _buildCompanyCard(),
          _buildRatingCard(),
          const SizedBox(height: 4),
          _buildFeedbackCard(),
          const SizedBox(height: 16),
          _buildStatsCard(),
          const SizedBox(height: 16),
          _buildTimeStatsCard(),
        ],
      ),
    );
  }

  Widget _buildCompanyCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.business, size: 26),
            ),
            Padding(
              padding: const EdgeInsets.all(9.0),
              child: Text(
                _companyName ?? 'Компания не указана',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Телефон
        if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  formatPhoneForDisplay(_phoneNumber!),
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
        // Email
        if (_emailStr != null && _emailStr!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
            child: Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _emailStr!,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRatingCard() {
    if (_stats == null) return const SizedBox.shrink();

    final fixedDefects = _stats!['fixedDefects'] as int? ?? 0;
    final rating = _stats!['rating'] as double? ?? 0.0;
    final ratingColor = RatingService.getRatingColor(rating);

    final hasRating = fixedDefects > 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            hasRating ? rating.toStringAsFixed(1) : '—',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: hasRating ? ratingColor : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (hasRating) ...[
            _buildStars(rating, 28, ratingColor),
            const SizedBox(height: 8),
            Text(
              RatingService.getRatingText(rating),
              style: TextStyle(
                fontSize: 14,
                color: ratingColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            const Text(
              'Нет завершенных замечаний',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    if (_stats == null) return const SizedBox.shrink();
    final feedbackCount = _stats!['feedbackCount'] as int? ?? 0;
    final avgCommunication = _stats!['avgCommunication'] as double? ?? 0.0;
    final avgMaterials = _stats!['avgMaterials'] as double? ?? 0.0;
    final avgWorkQuality = _stats!['avgWorkQuality'] as double? ?? 0.0;
    final avgOverall = (avgCommunication + avgMaterials + avgWorkQuality) / 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Отзывы заказчиков',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(),
            if (feedbackCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Нет отзывов о работе подрядчика',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              _buildFeedbackRow('Общая оценка', avgOverall, isMain: true),
              const SizedBox(height: 12),
              _buildFeedbackRow(
                'Взаимодействие с подрядчиком',
                avgCommunication,
              ),
              _buildFeedbackRow('Качество материалов', avgMaterials),
              _buildFeedbackRow('Качество работы', avgWorkQuality),
              const SizedBox(height: 8),
              Text(
                'На основе $feedbackCount отзывов',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackRow(String title, double rating, {bool isMain = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: isMain ? 120 : 140,
            child: Text(title, style: TextStyle(fontSize: isMain ? 14 : 13)),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildStars(rating, 16, AppTheme.orangeApp)),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontSize: isMain ? 14 : 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox.shrink();

    final totalDefects = _stats!['totalDefects'] as int? ?? 0;
    final fixedDefects = _stats!['fixedDefects'] as int? ?? 0;
    final inProgressDefects = _stats!['inProgressDefects'] as int? ?? 0;
    final openDefects = _stats!['openDefects'] as int? ?? 0;
    final reopenedDefects = _stats!['reopenedDefects'] as int? ?? 0;
    final successRate = _stats!['successRate'] as double? ?? 0.0;
    final criticalPercentage = _stats!['criticalPercentage'] as double? ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Статистика замечаний',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(),
            _buildStatRow(
              'Всего замечаний',
              totalDefects.toString(),
              Icons.assignment,
            ),
            _buildStatRow(
              'Закрыто',
              fixedDefects == 0
                  ? '—'
                  : '$fixedDefects (${successRate.toStringAsFixed(1)}%)',
              Icons.check_circle,
              color: fixedDefects > 0 ? AppTheme.greenApp : Colors.grey,
            ),
            _buildStatRow(
              'В работе',
              inProgressDefects.toString(),
              Icons.build,
              color: inProgressDefects > 0 ? AppTheme.orangeApp : Colors.grey,
            ),
            _buildStatRow(
              'Открыто',
              openDefects.toString(),
              Icons.warning,
              color: openDefects > 0 ? AppTheme.redApp : Colors.grey,
            ),
            _buildStatRow(
              'Переоткрыто',
              reopenedDefects.toString(),
              Icons.refresh,
              color: reopenedDefects > 0 ? Colors.purple : Colors.grey,
            ),
            _buildStatRow(
              'Критические',
              totalDefects == 0
                  ? '—'
                  : '${criticalPercentage.toStringAsFixed(1)}%',
              Icons.warning_amber,
              color: criticalPercentage > 0 ? AppTheme.redApp : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStatsCard() {
    final avgFixTime = _stats?['avgFixTime'] as double? ?? 0.0;
    final avgReactionTime = _stats?['avgReactionTime'] as double? ?? 0.0;
    final avgIterations = _stats?['avgIterations'] as double? ?? 0.0;
    final overdueDaysTotal = _stats?['overdueDaysTotal'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Временные показатели',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(),
            _buildStatRow(
              'Среднее время реакции',
              avgReactionTime > 0
                  ? '${avgReactionTime.toStringAsFixed(1)} ч. (${(avgReactionTime / 24).toStringAsFixed(1)} дн.)'
                  : 'Нет данных',
              Icons.speed,
            ),
            _buildStatRow(
              'Среднее время устранения',
              avgFixTime > 0
                  ? '${avgFixTime.toStringAsFixed(1)} ч. (${(avgFixTime / 24).toStringAsFixed(1)} дн.)'
                  : 'Нет данных',
              Icons.timer,
            ),
            _buildStatRow(
              'Среднее количество повторных исправлений',
              avgIterations > 0
                  ? avgIterations.toStringAsFixed(1)
                  : 'Нет данных',
              Icons.loop,
            ),
            _buildStatRow(
              'Всего дней просрочки',
              overdueDaysTotal > 0 ? '$overdueDaysTotal дн.' : 'Нет просрочек',
              Icons.access_time,
              color: overdueDaysTotal > 0 ? AppTheme.redApp : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, double size, Color color) {
    // Округляем до 0.5 для корректного отображения половинок
    final roundedRating = (rating * 2).round() / 2;
    final fullStars = roundedRating.floor();
    final hasHalfStar = (roundedRating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, size: size, color: color);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, size: size, color: color);
        } else {
          return Icon(Icons.star_border, size: size, color: color);
        }
      }),
    );
  }

  Widget _buildStatRow(
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color ?? Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
