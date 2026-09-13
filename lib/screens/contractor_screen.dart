// screens/contractor_screen.dart
import 'package:diplomgrinenko/functions.dart';
import 'package:diplomgrinenko/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/rating_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContractorScreen extends StatefulWidget {
  final String? selectedCategory;

  const ContractorScreen({super.key, this.selectedCategory});

  @override
  State<ContractorScreen> createState() => _ChooseContractor();
}

class _ChooseContractor extends State<ContractorScreen> {
  // Кэш для рейтингов подрядчиков
  final Map<String, double> _ratingCache = {};
  final Map<String, bool> _ratingLoadingCache = {};
  final Map<String, bool> _ratingErrorCache = {};

  // Загружаем рейтинги после того, как виджет построен
  void _loadRatingAfterBuild(String contractorId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContractorRating(contractorId);
    });
  }

  Future<void> _loadContractorRating(String contractorId) async {
    // Если уже загружено, загружается или была ошибка - выходим
    if (_ratingCache.containsKey(contractorId)) return;
    if (_ratingLoadingCache[contractorId] == true) return;
    if (_ratingErrorCache[contractorId] == true) return;
    if (!mounted) return;

    setState(() {
      _ratingLoadingCache[contractorId] = true;
    });

    try {
      final rating = await RatingService.getRatingWithMinimumDefects(
        contractorId,
        minClosedDefects: 1,
      );

      if (!mounted) return;

      setState(() {
        if (rating != null && rating > 0) {
          _ratingCache[contractorId] = rating;
        } else {
          // Нет рейтинга - помечаем как "нет данных", чтобы не пытаться загружать снова
          _ratingErrorCache[contractorId] = true;
        }
        _ratingLoadingCache[contractorId] = false;
      });
    } catch (e) {
      print('Ошибка загрузки рейтинга для $contractorId: $e');
      if (!mounted) return;
      setState(() {
        _ratingErrorCache[contractorId] = true;
        _ratingLoadingCache[contractorId] = false;
      });
    }
  }

  Widget _buildRatingWidget(double rating) {
    // Защита от некорректного рейтинга
    if (rating.isNaN || rating.isInfinite || rating < 0) {
      return Text(
        'Нет данных',
        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      );
    }

    final ratingColor = RatingService.getRatingColor(rating);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: ratingColor),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ratingColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Выберите подрядчика',
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Подрядчик')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Нет подрядчиков'));
          }

          final allContractors = snapshot.data!.docs;

          final filteredContractors =
              widget.selectedCategory != null &&
                  widget.selectedCategory!.isNotEmpty
              ? allContractors.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final contractorCategory = data['category'];
                  return contractorCategory == widget.selectedCategory;
                }).toList()
              : allContractors;

          if (filteredContractors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Нет подрядчиков по категории "${widget.selectedCategory ?? '?'}"',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Вернуться'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: filteredContractors.length,
            itemBuilder: (context, index) {
              final doc = filteredContractors[index];
              final data = doc.data() as Map<String, dynamic>;
              final contractorId = doc.id;

              // Загружаем рейтинг
              _loadRatingAfterBuild(contractorId);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context, {
                      'id': doc.id,
                      'surname': data['surname'] ?? '',
                      'name': data['name'] ?? '',
                      'patronymic': data['patronymic'] ?? '',
                      'companyName': data['companyName'] ?? '',
                      'email': data['email'] ?? '',
                      'phone': data['phone'] ?? '',
                      'category': data['category'] ?? '',
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Верхняя строка: аватар, имя, компания, категория
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.darkBlueApp,
                              child: Text(
                                (data['surname']?.isNotEmpty == true
                                    ? data['surname'][0]
                                    : 'П')[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data['surname']} ${data['name']} ${data['patronymic']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (data['companyName'] != null &&
                                      data['companyName'] != '')
                                    Text(
                                      data['companyName'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (data['category'] != null &&
                                data['category'] != '')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  data['category'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color.fromARGB(
                                      255,
                                      65,
                                      128,
                                      53,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Строка с контактами и рейтингом
                        Row(
                          children: [
                            // Контакты (почта и телефон)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.email,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          data['email'] ?? 'Email не указан',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (data['phone'] != null &&
                                      data['phone'] != '')
                                    const SizedBox(height: 4),
                                  if (data['phone'] != null &&
                                      data['phone'] != '')
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatPhoneForDisplay(data['phone']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),

                            // Рейтинг
                            if (_ratingLoadingCache[contractorId] == true)
                              const SizedBox(
                                width: 40,
                                height: 16,
                                child: Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else if (_ratingCache.containsKey(contractorId))
                              _buildRatingWidget(_ratingCache[contractorId]!)
                            else
                              Text(
                                'Нет данных',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
