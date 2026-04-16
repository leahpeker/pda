import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/config/constants.dart';
import 'package:pda/providers/event_flag_provider.dart';
import 'package:pda/services/api_error.dart';
import 'package:pda/utils/snackbar.dart';
import 'package:pda/utils/validators.dart' as v;

class FlagEventDialog extends ConsumerStatefulWidget {
  final String eventId;

  const FlagEventDialog({super.key, required this.eventId});

  @override
  ConsumerState<FlagEventDialog> createState() => _FlagEventDialogState();
}

class _FlagEventDialogState extends ConsumerState<FlagEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await flagEvent(ref, widget.eventId, _reasonController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnackBar(context, 'flag sent — thanks for flagging 🌿');
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      if (statusCode == 409) {
        Navigator.of(context).pop();
        showSnackBar(context, 'you already flagged this event');
      } else {
        final msg = ApiError.from(e).message;
        showErrorSnackBar(
          context,
          msg.isNotEmpty ? msg : "couldn't send flag — try again",
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('flag this event'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _reasonController,
          maxLength: FieldLimit.bio,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'reason',
            hintText: "what's the issue?",
            helperText:
                "let admins know if this event isn't following community guidelines",
            helperMaxLines: 2,
          ),
          validator: v.all([v.required(), v.maxLength(FieldLimit.bio)]),
          textInputAction: TextInputAction.newline,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('flag'),
        ),
      ],
    );
  }
}
