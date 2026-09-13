import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'contractor_detail_screen.dart';
import '../services/rating_service.dart';
import '../theme/app_theme.dart';

class ContractorTopScreen extends StatefulWidget {
  const ContractorTopScreen({super.key});

  @override
  State<ContractorTopScreen> createState() => _ContractorTopScreenState();
}

class _ContractorTopScreenState extends State<ContractorTopScreen> {
  List<Map<String, dynamic>> _contractors = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContractors();
  }

  Future<void> _loadContractors() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Подрядчик')
          .get();

      if (usersSnapshot.docs.isEmpty) {
        setState(() {
          _contractors = [];
          _errorMessage = 'Нет подрядчиков в системе';
          _isLoading = false;
        });
        return;
      }

      final contractorsList = <Map<String, dynamic>>[];

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final contractorId = userDoc.id;
        final surname = userData['surname'] ?? '';
        final name = userData['name'] ?? '';
        final companyName = userData['companyName'] ?? '';

        final defects = await RatingService.getContractorDefects(contractorId);
        final totalDefects = defects.length;
        final fixedDefects = defects
            .where((d) => d.status == 'verified' || d.status == 'closed')
            .length;

        double rating = 0.0;
        if (fixedDefects > 0) {
          rating = await RatingService.calculateRatingWithFeedback(
            contractorId,
          );
        }

        contractorsList.add({
          'id': contractorId,
          'name': '$surname $name',
          'company': companyName,
          'rating': rating,
          'totalDefects': totalDefects,
          'fixedDefects': fixedDefects,
        });
      }

      contractorsList.sort((a, b) {
        final fixedA = a['fixedDefects'] as int;
        final fixedB = b['fixedDefects'] as int;
        final ratingA = a['rating'] as double;
        final ratingB = b['rating'] as double;

        if (fixedA == 0 && fixedB == 0) return 0;
        if (fixedA == 0) return 1;
        if (fixedB == 0) return -1;
        return ratingB.compareTo(ratingA);
      });

      if (mounted) {
        setState(() {
          _contractors = contractorsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getRatingColor(double rating, int fixedDefects) {
    if (fixedDefects == 0) return Colors.grey;
    if (rating >= 4.5) return AppTheme.greenApp;
    if (rating >= 3.5) return AppTheme.blueApp;
    if (rating >= 2.5) return AppTheme.orangeApp;
    if (rating >= 1.5) return const Color.fromARGB(255, 255, 106, 61);
    return AppTheme.redApp;
  }

  Widget _buildStars(double rating, Color color) {
    // Округляем до 0.5 для корректного отображения половинок
    final roundedRating = (rating * 2).round() / 2;
    final fullStars = roundedRating.floor();
    final hasHalfStar = (roundedRating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, size: 12, color: color);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, size: 12, color: color);
        } else {
          return Icon(Icons.star_border, size: 12, color: color);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Рейтинг подрядчиков',
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContractors,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.redApp),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContractors,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_contractors.isEmpty) {
      return const Center(child: Text('Нет подрядчиков в системе'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contractors.length,
      itemBuilder: (context, index) {
        final contractor = _contractors[index];
        final rating = contractor['rating'] as double;
        final fixedDefects = contractor['fixedDefects'] as int;
        final ratingColor = _getRatingColor(rating, fixedDefects);

        final hasCompletedDefects = fixedDefects > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContractorDetailScreen(
                    contractorId: contractor['id'],
                    contractorName: contractor['name'],
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: hasCompletedDefects && index < 3
                  ? AppTheme.greenApp
                  : AppTheme.blueApp,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasCompletedDefects && index < 3
                      ? Colors.white
                      : Colors.black54,
                ),
              ),
            ),
            title: Text(
              contractor['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: contractor['company'].toString().isNotEmpty
                ? Text(contractor['company'])
                : null,
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasCompletedDefects ? rating.toStringAsFixed(1) : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ratingColor,
                    ),
                  ),
                  if (hasCompletedDefects) _buildStars(rating, ratingColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
