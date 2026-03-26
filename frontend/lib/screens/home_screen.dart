import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_toolbar/markdown_toolbar.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/home_provider.dart';
import 'package:pda/widgets/app_scaffold.dart';

const _defaultContent = '''
# Protein Deficients Anonymous

A collective liberation community.

## Who we are

Protein Deficients Anonymous (PDA) is a vegan community grounded in collective liberation. We believe that the liberation of animals, humans, and the earth are deeply interconnected. We organize, share resources, and build solidarity across movements.

## Our values

- 🌱 **Collective liberation** — Animal liberation and human liberation are inseparable.
- 🤝 **Mutual aid** — We support each other materially, not just ideologically.
- 🌍 **Intersectionality** — We center those most impacted by systems of oppression.
- ✊ **Direct action** — We take action in the world, not just in conversation.

## Want to join us?

PDA is a vetted community. We review join requests to ensure alignment with our values and capacity to welcome new members.
''';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final canEdit = user?.hasPermission('manage_guidelines') ?? false;
    final homeAsync = ref.watch(homePageNotifierProvider);

    return AppScaffold(
      child: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _HomeBody(content: _defaultContent, canEdit: canEdit),
        data:
            (home) => _HomeBody(
              content:
                  home.content.trim().isEmpty ? _defaultContent : home.content,
              canEdit: canEdit,
            ),
      ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  final String content;
  final bool canEdit;

  const _HomeBody({required this.content, required this.canEdit});

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(homePageNotifierProvider.notifier)
          .saveContent(_controller.text);
      if (mounted) setState(() => _editing = false);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data as Map?)?['detail'] ?? 'Failed to save.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detail.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    _controller.text =
        ref.read(homePageNotifierProvider).valueOrNull?.content ??
        widget.content;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        if (_editing) _buildToolbar(),
        Expanded(child: _editing ? _buildEditor() : _buildViewer(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          const Spacer(),
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

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: MarkdownToolbar(
        useIncludedTextField: false,
        controller: _controller,
        focusNode: _focusNode,
        hideImage: true,
        hideCheckbox: true,
        hideHorizontalRule: true,
        collapsable: false,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        iconColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        inputFormatters: [LengthLimitingTextInputFormatter(50000)],
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Write home page content in Markdown…',
          alignLabelWithHint: true,
        ),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final content =
        ref.watch(homePageNotifierProvider).valueOrNull?.content ??
        widget.content;
    final displayContent = content.trim().isEmpty ? _defaultContent : content;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Markdown(
                data: displayContent,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ),
              if (!_isLoggedIn(context))
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: ElevatedButton(
                    onPressed: () => context.go('/join'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'Request to join',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLoggedIn(BuildContext context) {
    return ref.read(authProvider).valueOrNull != null;
  }
}
