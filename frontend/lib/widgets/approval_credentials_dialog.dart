import 'package:flutter/material.dart';
import 'temp_password_field.dart';

/// Displays approval credentials (optional phone, temp password) after a user
/// account is created or a join request is approved.
class ApprovalCredentialsDialog extends StatelessWidget {
  const ApprovalCredentialsDialog({
    super.key,
    required this.title,
    required this.body,
    required this.tempPassword,
    this.phoneNumber,
  });

  final String title;
  final String body;
  final String tempPassword;

  /// If provided, a phone row is shown above the password field.
  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 12),
          if (phoneNumber != null) ...[
            _LabeledRow(label: 'Phone', value: phoneNumber!),
            const SizedBox(height: 12),
            const Text(
              'Temporary password',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
          ],
          TempPasswordField(password: tempPassword),
          const SizedBox(height: 8),
          const Text(
            'They should change it on first login.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
