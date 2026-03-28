import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/providers/whatsapp_config_provider.dart';
import 'package:pda/services/api_error.dart';
import 'package:pda/utils/snackbar.dart';
import 'package:pda/widgets/app_scaffold.dart';

class WhatsAppConfigScreen extends ConsumerWidget {
  const WhatsAppConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppScaffold(child: _WhatsAppConfigBody());
  }
}

class _WhatsAppConfigBody extends ConsumerWidget {
  const _WhatsAppConfigBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(whatsAppConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => Center(
            child: Text('Failed to load config: ${ApiError.from(e).message}'),
          ),
      data: (config) => _WhatsAppConfigForm(config: config),
    );
  }
}

class _WhatsAppConfigForm extends ConsumerStatefulWidget {
  final WhatsAppConfig config;

  const _WhatsAppConfigForm({required this.config});

  @override
  ConsumerState<_WhatsAppConfigForm> createState() =>
      _WhatsAppConfigFormState();
}

class _WhatsAppConfigFormState extends ConsumerState<_WhatsAppConfigForm> {
  late final TextEditingController _botUrlCtrl;
  late final TextEditingController _secretCtrl;
  late final TextEditingController _groupIdCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _botUrlCtrl = TextEditingController(text: widget.config.botUrl);
    _secretCtrl = TextEditingController();
    _groupIdCtrl = TextEditingController(text: widget.config.groupId);
  }

  @override
  void dispose() {
    _botUrlCtrl.dispose();
    _secretCtrl.dispose();
    _groupIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(whatsAppConfigProvider.notifier)
          .save(
            botUrl: _botUrlCtrl.text.trim(),
            botSecret: _secretCtrl.text.isEmpty ? null : _secretCtrl.text,
            groupId: _groupIdCtrl.text.trim(),
          );
      _secretCtrl.clear();
      if (mounted) showSnackBar(context, 'Saved');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(whatsAppStatusProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WhatsApp configuration',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Configure the WhatsApp bot that posts event notifications to the group.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Setup instructions
            const _SetupInstructions(),
            const SizedBox(height: 32),

            // Status card
            _StatusCard(statusAsync: statusAsync),
            const SizedBox(height: 32),

            // Config form
            Text('Bot settings', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _botUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Bot URL',
                hintText: 'http://localhost:3001',
                border: OutlineInputBorder(),
                helperText: 'The URL of the WhatsApp bot microservice.',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretCtrl,
              decoration: InputDecoration(
                labelText: 'Bot secret',
                hintText:
                    widget.config.hasSecret
                        ? '••••••••  (leave blank to keep current)'
                        : 'Enter secret',
                border: const OutlineInputBorder(),
                helperText: 'The X-Bot-Secret header value.',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Group ID',
                hintText: '1234567890@g.us',
                border: OutlineInputBorder(),
                helperText:
                    'The WhatsApp group JID (shown in bot logs on startup).',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child:
                  _saving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupInstructions extends StatefulWidget {
  const _SetupInstructions();

  @override
  State<_SetupInstructions> createState() => _SetupInstructionsState();
}

class _SetupInstructionsState extends State<_SetupInstructions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Setup instructions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _SetupInstructionsBody(theme: theme),
            ),
        ],
      ),
    );
  }
}

class _SetupInstructionsBody extends StatelessWidget {
  const _SetupInstructionsBody({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _step(
            theme,
            '1',
            'Get a dedicated phone number',
            'The bot needs its own WhatsApp account — use a SIM you don\'t mind '
                'dedicating to this. A cheap prepaid SIM works fine.',
          ),
          _step(
            theme,
            '2',
            'Run the bot',
            'In the whatsapp-bot/ directory:',
            code: 'node index.js',
            codeLabel: 'start bot',
          ),
          _step(
            theme,
            '3',
            'Scan the QR code',
            'The bot prints a QR code in the terminal on first run. Open WhatsApp '
                'on the bot phone → Linked devices → Link a device, then scan it. '
                'Credentials are saved to auth_info/ so you only do this once.',
          ),
          _step(
            theme,
            '4',
            'Add the bot to your group',
            'Add the bot\'s phone number to the WhatsApp group as you would any contact.',
          ),
          _step(
            theme,
            '5',
            'Find the group ID',
            'Once connected, the bot logs all joined groups on startup:',
            code:
                'Joined groups (copy the JID you want as WHATSAPP_GROUP_ID):\n'
                '  120363XXXXXXXXXX@g.us  —  PDA members',
            codeLabel: 'copy group JID',
          ),
          _step(
            theme,
            '6',
            'Set a bot secret',
            'Pick any random string as a shared secret — this stops unauthorized '
                'callers from posting to your group. Set it as the BOT_SECRET '
                'environment variable when running the bot:',
            code: 'BOT_SECRET=your-secret node index.js',
            codeLabel: 'run with secret',
          ),
          _step(
            theme,
            '7',
            'Enter the config here',
            'Fill in the Bot URL (where the bot is reachable from the Django server), '
                'the secret, and the group ID above, then hit Save. '
                'Use the Refresh button to confirm the bot shows as connected.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _step(
    ThemeData theme,
    String number,
    String title,
    String body, {
    String? code,
    String? codeLabel,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (code != null) ...[
                  const SizedBox(height: 8),
                  _CodeBlock(code: code, label: codeLabel),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, this.label});

  final String code;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Tooltip(
            message: label ?? 'Copy',
            child: IconButton(
              icon: const Icon(Icons.copy_outlined, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.statusAsync});

  final AsyncValue<bool> statusAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final (icon, label, color) = statusAsync.when(
      loading:
          () => (
            const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                as Widget,
            'Checking…',
            theme.colorScheme.onSurfaceVariant,
          ),
      error:
          (_, __) => (
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error)
                as Widget,
            'Could not reach bot',
            theme.colorScheme.error,
          ),
      data:
          (connected) =>
              connected
                  ? (
                    Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.green.shade600,
                        )
                        as Widget,
                    'Bot connected',
                    Colors.green.shade600,
                  )
                  : (
                    Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: theme.colorScheme.error,
                        )
                        as Widget,
                    'Bot not connected',
                    theme.colorScheme.error,
                  ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => ref.invalidate(whatsAppStatusProvider),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
