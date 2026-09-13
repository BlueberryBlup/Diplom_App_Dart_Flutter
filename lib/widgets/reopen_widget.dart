// widgets/reopen_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReopenDialog extends StatefulWidget {
  const ReopenDialog({super.key});

  @override
  State<ReopenDialog> createState() => _ReopenDialogState();
}

class _ReopenDialogState extends State<ReopenDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Укажите причину:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Введите причину...',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Укажите причину'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
              return;
            }
            Navigator.pop(context, reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: const Text(
            'Переоткрыть',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
