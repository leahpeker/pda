import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/guidelines_provider.dart';
import 'package:pda/widgets/app_scaffold.dart';
import 'package:pda/widgets/autosave_mixin.dart';
import 'package:pda/widgets/quill_content_editor.dart';

class GuidelinesScreen extends ConsumerWidget {
  const GuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final canEdit = user?.hasPermission('manage_guidelines') ?? false;
    final guidelinesAsync = ref.watch(guidelinesNotifierProvider);

    return AppScaffold(
      child: guidelinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Text(
                'Failed to load guidelines.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        data:
            (guidelines) =>
                _GuidelinesBody(content: guidelines.content, canEdit: canEdit),
      ),
    );
  }
}

class _GuidelinesBody extends ConsumerStatefulWidget {
  final String content;
  final bool canEdit;

  const _GuidelinesBody({required this.content, required this.canEdit});

  @override
  ConsumerState<_GuidelinesBody> createState() => _GuidelinesBodyState();
}

class _GuidelinesBodyState extends ConsumerState<_GuidelinesBody>
    with AutosaveMixin {
  bool _editing = false;
  late String _json;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _json = widget.content;
    if (widget.canEdit) {
      initAutosaveCallback(
        onSave:
            (text) =>
                ref.read(guidelinesNotifierProvider.notifier).saveContent(text),
      );
    }
  }

  @override
  void dispose() {
    disposeAutosave();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(guidelinesNotifierProvider.notifier).saveContent(_json);
      if (mounted) setState(() => _editing = false);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail =
          (e.response?.data as Map?)?['detail'] ?? 'Failed to save guidelines.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    final saved =
        ref.read(guidelinesNotifierProvider).valueOrNull?.content ??
        widget.content;
    setState(() {
      _json = saved;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        Expanded(
          child: QuillContentEditor(
            jsonContent: _json,
            editing: _editing,
            expands: true,
            hintText: 'Write community guidelines…',
            onChanged:
                widget.canEdit
                    ? (v) {
                      _json = v;
                      triggerAutosave(v);
                    }
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Community Guidelines',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (_editing) AutosaveIndicator(status: autosaveStatus),
          if (_editing) const SizedBox(width: 12),
          if (widget.canEdit && !_editing)
            FilledButton.tonal(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit'),
            ),
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child:
                  _saving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }
}
