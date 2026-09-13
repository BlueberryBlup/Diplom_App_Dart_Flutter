// screens/contractor_detail_screen.dart
import 'package:flutter/material.dart';
import '../widgets/contractor_stats_widget.dart';

class ContractorDetailScreen extends StatelessWidget {
  final String contractorId;
  final String contractorName;

  const ContractorDetailScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contractorName, style: const TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: ContractorStatsWidget(
        contractorId: contractorId,
        contractorName: contractorName,
      ),
    );
  }
}
