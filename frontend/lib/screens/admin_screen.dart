import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/widgets/app_scaffold.dart';
import 'package:pda/config/constants.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final cards = _visibleCards(context, user);

    return AppScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('admin', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(children: cards);
                }
                return Wrap(spacing: 16, runSpacing: 16, children: cards);
              },
            ),
          ],
        ),
      ),
    );
  }
}

typedef _CardDef = ({
  String permission,
  IconData icon,
  String title,
  String subtitle,
  String route,
});

const _cardDefs = <_CardDef>[
  (
    permission: Permission.manageEvents,
    icon: Icons.event_available_outlined,
    title: 'manage events',
    subtitle: 'create, edit, and manage events',
    route: '/events/manage',
  ),
  (
    permission: Permission.manageEvents,
    icon: Icons.flag_outlined,
    title: 'flagged events',
    subtitle: 'review events flagged by members',
    route: '/admin/flagged-events',
  ),
  (
    permission: Permission.manageUsers,
    icon: Icons.groups_outlined,
    title: 'members',
    subtitle: 'view and manage member accounts',
    route: '/members',
  ),
  (
    permission: Permission.approveJoinRequests,
    icon: Icons.person_search_outlined,
    title: 'join requests',
    subtitle: 'review pending membership requests',
    route: '/join-requests',
  ),
  (
    permission: Permission.editJoinQuestions,
    icon: Icons.dynamic_form_outlined,
    title: 'join form',
    subtitle: 'configure join request form questions',
    route: '/admin/join-form',
  ),
  (
    permission: Permission.manageSurveys,
    icon: Icons.poll_outlined,
    title: 'surveys',
    subtitle: 'create and manage feedback surveys',
    route: '/admin/surveys',
  ),
  (
    permission: Permission.manageDocs,
    icon: Icons.library_books_outlined,
    title: 'documents',
    subtitle: 'create and manage shared docs',
    route: '/docs',
  ),
  (
    permission: Permission.manageWhatsapp,
    icon: Icons.chat_outlined,
    title: 'whatsapp bot',
    subtitle: 'configure bot connection and group',
    route: '/admin/whatsapp',
  ),
];

List<Widget> _visibleCards(BuildContext context, dynamic user) {
  return [
    for (final def in _cardDefs)
      if (user?.hasPermission(def.permission) ?? false)
        _AdminCard(
          icon: def.icon,
          title: def.title,
          subtitle: def.subtitle,
          onTap: () => context.go(def.route),
        ),
  ];
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
