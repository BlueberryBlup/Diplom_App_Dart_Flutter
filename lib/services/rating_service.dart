import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diplomgrinenko/models/review_model.dart';
import 'package:diplomgrinenko/theme/app_theme.dart';
import '../models/defect_model.dart';

class RatingService {
  //рейтинг 0-100
  static double calculateRating(List<DefectModel> defects) {
    if (defects.isEmpty) return 0;

    final totalDefects = defects.length;
    int totalIterations = 0;
    int overdueDaysTotal = 0;
    int criticalCount = 0;
    double totalReactionHours = 0;
    int reactionCount = 0;

    for (final defect in defects) {
      totalIterations += defect.iterCount;

      if (defect.severity == 'critical') {
        criticalCount++;
      }

      if (defect.deadline != null) {
        final deadline = defect.deadline!;

        for (final correctDate in defect.datesOfCorrect) {
          if (correctDate.isAfter(deadline)) {
            overdueDaysTotal += correctDate.difference(deadline).inDays;
          }
        }

        if (defect.status != 'closed' &&
            defect.status != 'verified' &&
            DateTime.now().isAfter(deadline) &&
            defect.datesOfCorrect.isEmpty) {
          overdueDaysTotal += DateTime.now().difference(deadline).inDays;
        }
      }


      for (int i = 0; i < defect.datesOfStart.length; i++) {
        final startDate = defect.datesOfStart[i];
        final previousDate = i == 0
            ? defect.dateOfCreation
            : defect.datesOfReopened[i - 1];

        final reactionHours = startDate
            .difference(previousDate)
            .inHours
            .toDouble();
        totalReactionHours += reactionHours;
        reactionCount++;
      }
    }

    final double avgIterations = totalIterations / totalDefects;
    final double avgReactionHours = reactionCount > 0
        ? totalReactionHours / reactionCount
        : 0;
    final double criticalPercentage = (criticalCount / totalDefects) * 100;

    return _calculateRatingFromMetrics(
      avgIterations: avgIterations,
      avgReactionHours: avgReactionHours,
      overdueDaysTotal: overdueDaysTotal,
      criticalPercentage: criticalPercentage,
    );
  }

  static double _calculateRatingFromMetrics({
    required double avgIterations,
    required double avgReactionHours,
    required int overdueDaysTotal,
    required double criticalPercentage,
  }) {
    double rating = 100;

    //штраф за время реакции
    if (avgReactionHours > 48) {
      double reactionPenalty = (avgReactionHours - 48) * 0.05;
      reactionPenalty = reactionPenalty.clamp(0, 20);
      rating -= reactionPenalty;
    }

    //штраф за просрочку
    double overduePenalty = (overdueDaysTotal).toDouble();
    overduePenalty = overduePenalty.clamp(0, 40);
    rating -= overduePenalty;

    //штраф за итерации
    double iterationPenalty = (avgIterations - 1) * 0.2;
    iterationPenalty = iterationPenalty.clamp(0, 25);
    rating -= iterationPenalty;

    //штраф за критические
    double criticalPenalty = criticalPercentage * 1.2;
    criticalPenalty = criticalPenalty.clamp(0, 15);
    rating -= criticalPenalty;

    return rating.clamp(0, 100);
  }

  //расчет с отзывами
  static Future<double> calculateRatingWithFeedback(String contractorId) async {
    final defects = await getContractorDefects(contractorId);
    final feedbacks = await _getContractorFeedbacks(contractorId);

    final rating100 = calculateRating(defects);
    final ratingFromDefects5 = toRating5(rating100);

    if (feedbacks.isEmpty) {
      return ratingFromDefects5;
    }

    //средняя оценка
    final ratingFromFeedbacks5 = _calculateAverageFeedback(feedbacks);

    final finalRating =
        (ratingFromDefects5 * 0.4) + (ratingFromFeedbacks5 * 0.6);

    return finalRating.clamp(0, 5);
  }

  static Future<List<ContrReviewModel>> _getContractorFeedbacks(
    String contractorId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('feedbacks')
        .where('contractorId', isEqualTo: contractorId)
        .get();

    return snapshot.docs
        .map((doc) => ContrReviewModel.fromFirestore(doc))
        .toList();
  }

  static double _calculateAverageFeedback(List<ContrReviewModel> feedbacks) {
    if (feedbacks.isEmpty) return 0;
    double total = 0;
    for (final feedback in feedbacks) {
      total += feedback.averageRating;
    }
    return total / feedbacks.length;
  }

  static Future<double> calculateRatingByContractorId(
    String contractorId,
  ) async {
    final defects = await getContractorDefects(contractorId);
    final rating100 = calculateRating(defects);
    return (rating100 / 100) * 5;
  }

  static Future<double> getAverageFeedbackRating(String contractorId) async {
    final feedbacks = await _getContractorFeedbacks(contractorId);
    return _calculateAverageFeedback(feedbacks);
  }

  static Future<List<DefectModel>> getContractorDefects(
    String contractorId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('defects')
        .where('contractorId', isEqualTo: contractorId)
        .get();

    return snapshot.docs.map((doc) => DefectModel.fromFirestore(doc)).toList();
  }

  static double toRating5(double rating100) {
    return (rating100 / 100) * 5;
  }

  static double toRating100(double rating5) {
    return (rating5 / 5) * 100;
  }

  static String getRatingText(double rating5) {
    if (rating5 >= 4.5) return 'Отлично';
    if (rating5 >= 3.5) return 'Хорошо';
    if (rating5 >= 2.5) return 'Удовлетворительно';
    if (rating5 >= 1.5) return 'Плохо';
    return 'Очень плохо';
  }

  static Color getRatingColor(double rating5) {
    if (rating5 >= 4.5) return AppTheme.greenApp;
    if (rating5 >= 3.5) return AppTheme.pinkApp;
    if (rating5 >= 2.5) return AppTheme.purpleApp;
    if (rating5 >= 1.5) return AppTheme.orangeApp;
    return AppTheme.redApp;
  }

  static Future<List<ContrReviewModel>> getContractorFeedbacks(
    String contractorId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('feedbacks')
        .where('contractorId', isEqualTo: contractorId)
        .get();

    return snapshot.docs
        .map((doc) => ContrReviewModel.fromFirestore(doc))
        .toList();
  }

  static Future<double?> getRatingWithMinimumDefects(
    String contractorId, {
    int minClosedDefects = 1,
  }) async {
    try {
      final defects = await getContractorDefects(contractorId);
      final closedDefects = defects
          .where((d) => d.status == 'closed' || d.status == 'verified')
          .length;

      if (closedDefects < minClosedDefects) {
        return null;
      }

      return await calculateRatingWithFeedback(contractorId);
    } catch (e) {
      return null;
    }
  }
}
