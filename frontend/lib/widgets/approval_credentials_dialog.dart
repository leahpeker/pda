import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pda/utils/snackbar.dart';

/// Displays a magic login link after a user account is created or a join
/// request is approved.
class ApprovalCredentialsDialog extends StatelessWidget {
  const ApprovalCredentialsDialog({
    super.key,
    required this.title,
    required this.body,
    required this.magicLinkToken,
    this.phoneNumber,
  });

  final String title;
  final String body;
  final String magicLinkToken;

  /// If provided, a phone row is shown above the link field.
  final String? phoneNumber;

  String get _loginUrl {
    final origin = Uri.base.origin;
    return '$origin/magic-login/$magicLinkToken';
  }

  @override
  Widget build(BuildContext context) {
    final url = _loginUrl;
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 12),
          if (phoneNumber != null) ...[
            _LabeledRow(label: 'phone', value: phoneNumber!),
            const SizedBox(height: 12),
          ],
          const Text(
            'login link',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          _MagicLinkField(url: url),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final message =
                  'hey! you\'ve been added to PDA 🌱\n\n'
                  'click here to log in: $url\n\n'
                  'the link works once and expires in 7 days — '
                  'you\'ll set your password on first login';
              Clipboard.setData(ClipboardData(text: message));
              showSnackBar(context, 'welcome message copied ✓');
            },
            icon: const Icon(Icons.content_copy_outlined, size: 16),
            label: const Text('copy welcome message'),
          ),
          const SizedBox(height: 8),
          Text(
            'includes login link — expires in 7 days',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('done'),
        ),
      ],
    );
  }
}

class _MagicLinkField extends StatelessWidget {
  final String url;

  const _MagicLinkField({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.content_copy_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
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
