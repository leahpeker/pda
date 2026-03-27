import 'package:flutter/material.dart';
import 'loading_button.dart';

/// A row of Cancel + Save buttons, with the Save button showing a spinner
/// while [saving] is true.
///
/// Typically used inside an edit toolbar:
/// ```dart
/// SaveCancelButtonRow(
///   saving: _saving,
///   onSave: _save,
///   onCancel: _cancel,
/// )
/// ```
class SaveCancelButtonRow extends StatelessWidget {
  const SaveCancelButtonRow({
    super.key,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    this.saveLabel = 'Save',
    this.cancelLabel = 'Cancel',
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: saving ? null : onCancel,
          child: Text(cancelLabel),
        ),
        const SizedBox(width: 8),
        LoadingButton(label: saveLabel, onPressed: onSave, loading: saving),
      ],
    );
  }
}
