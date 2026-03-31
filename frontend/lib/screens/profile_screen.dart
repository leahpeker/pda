import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/widgets/app_scaffold.dart';
import 'package:pda/widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final theme = Theme.of(context);

    return AppScaffold(
      maxWidth: 600,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Profile header
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  if (user.profilePhotoUrl.isNotEmpty)
                    ProfileAvatar(photoUrl: user.profilePhotoUrl, radius: 28)
                  else
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 28,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty
                              ? user.displayName
                              : user.phoneNumber,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (user.displayName.isNotEmpty)
                          Text(
                            user.phoneNumber,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
          ],

          // User nav items
          if (user != null) ...[
            const _NavTile(
              icon: Icons.tune_outlined,
              label: 'settings',
              route: '/settings',
            ),
            const _NavTile(
              icon: Icons.event_outlined,
              label: 'my events',
              route: '/events/mine',
            ),
          ],

          // Admin
          if (user != null && user.hasAnyAdminPermission)
            const _NavTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'admin',
              route: '/admin',
            ),

          const Divider(height: 24),

          if (user != null)
            _LogoutTile()
          else
            const _NavTile(
              icon: Icons.login_outlined,
              label: 'log in',
              route: '/login',
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isSelected = currentPath.startsWith(route);
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: () => context.go(route),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.logout_outlined, color: theme.colorScheme.error),
      title: Text('log out', style: TextStyle(color: theme.colorScheme.error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: () async {
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          context.go('/');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('you\'re logged out')));
        }
      },
    );
  }
}
