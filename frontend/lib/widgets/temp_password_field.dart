import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TempPasswordField extends StatefulWidget {
  final String password;

  const TempPasswordField({super.key, required this.password});

  @override
  State<TempPasswordField> createState() => _TempPasswordFieldState();
}

class _TempPasswordFieldState extends State<TempPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _visible ? widget.password : '•' * widget.password.length,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: _visible ? 1.5 : 2,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
            iconSize: 18,
            tooltip: _visible ? 'Hide' : 'Show',
            onPressed: () => setState(() => _visible = !_visible),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            iconSize: 18,
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.password));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }
}
