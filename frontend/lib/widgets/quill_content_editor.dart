import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Shared rich-text content widget backed by flutter_quill.
///
/// - View mode ([editing] = false): read-only QuillEditor renders Delta JSON.
/// - Edit mode ([editing] = true): QuillSimpleToolbar + editable QuillEditor.
///
/// [jsonContent] — Delta JSON string from the API. Empty string = blank doc.
/// [editing]     — toggles between view and edit mode.
/// [onChanged]   — called with the latest Delta JSON string on each change.
/// [expands]     — if true, editor fills available space (wrap caller in Expanded).
/// [hintText]    — placeholder shown in edit mode when document is empty.
class QuillContentEditor extends StatefulWidget {
  const QuillContentEditor({
    super.key,
    required this.jsonContent,
    this.editing = false,
    this.onChanged,
    this.expands = false,
    this.hintText = 'Write something…',
  });

  final String jsonContent;
  final bool editing;
  final void Function(String)? onChanged;
  final bool expands;
  final String hintText;

  @override
  State<QuillContentEditor> createState() => _QuillContentEditorState();
}

class _QuillContentEditorState extends State<QuillContentEditor> {
  late QuillController _controller;
  StreamSubscription<DocChange>? _sub;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.jsonContent);
    _subscribeChanges();
  }

  @override
  void didUpdateWidget(QuillContentEditor old) {
    super.didUpdateWidget(old);
    // When cancelled externally (jsonContent reset while not editing), reload.
    if (!widget.editing && widget.jsonContent != old.jsonContent) {
      _sub?.cancel();
      _controller.dispose();
      _controller = _buildController(widget.jsonContent);
      _subscribeChanges();
    }
  }

  void _subscribeChanges() {
    if (widget.onChanged == null) return;
    _sub = _controller.changes.listen((_) {
      widget.onChanged!(_serialize());
    });
  }

  QuillController _buildController(String json) {
    if (json.trim().isEmpty) return QuillController.basic();
    try {
      return QuillController(
        document: Document.fromJson(jsonDecode(json) as List),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      return QuillController.basic();
    }
  }

  String _serialize() => jsonEncode(_controller.document.toDelta().toJson());

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editing) {
      _controller.readOnly = true;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: QuillEditor.basic(
          controller: _controller,
          config: const QuillEditorConfig(showCursor: false),
        ),
      );
    }

    _controller.readOnly = false;
    final editor = Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: QuillEditor.basic(
        controller: _controller,
        config: QuillEditorConfig(
          placeholder: widget.hintText,
          expands: widget.expands,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        QuillSimpleToolbar(
          controller: _controller,
          config: const QuillSimpleToolbarConfig(
            showSubscript: false,
            showSuperscript: false,
            showListCheck: false,
          ),
        ),
        widget.expands ? Expanded(child: editor) : editor,
      ],
    );
  }
}
