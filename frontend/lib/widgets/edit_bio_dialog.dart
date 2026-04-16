import 'package:flutter/material.dart';
import 'package:pda/config/constants.dart';

class EditBioDialog extends StatefulWidget {
  final String initialValue;

  const EditBioDialog({super.key, required this.initialValue});

  @override
  State<EditBioDialog> createState() => _EditBioDialogState();
}

class _EditBioDialogState extends State<EditBioDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('edit bio'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: FieldLimit.bio,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Bio',
            alignLabelWithHint: true,
          ),
          validator: (v) {
            if (v != null && v.trim().length > FieldLimit.bio) {
              return 'Max ${FieldLimit.bio} characters';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('save'),
        ),
      ],
    );
  }
}
