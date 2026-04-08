import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

const _iosSteps = [
  ('open this page in Safari', 'not Chrome or other browsers'),
  (
    'tap the share button at the bottom of the screen',
    'it looks like a square with an arrow pointing up',
  ),
  ('scroll down and tap "add to home screen"', ''),
  ('tap "add" in the top right', ''),
  ('that\'s it — PDA will appear on your home screen 🌱', ''),
];

const _androidSteps = [
  ('open this page in Chrome', 'not Firefox or other browsers'),
  ('tap the three dots menu (⋮) in the top right', ''),
  ('tap "add to home screen" or "install app"', ''),
  ('tap "add" to confirm', ''),
  ('you\'re all set — PDA will appear on your home screen 🌱', ''),
];

class InstallAppScreen extends StatelessWidget {
  const InstallAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final isIos = platform == TargetPlatform.iOS;
    final isAndroid = platform == TargetPlatform.android;

    return AppScaffold(
      maxWidth: 600,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Text(
            'install the app',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'add PDA to your home screen for a faster, app-like experience — '
            'no app store required',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (isIos) ...[
            const _InstructionCard(
              title: 'iPhone / iPad (Safari)',
              icon: Icons.phone_iphone_outlined,
              steps: _iosSteps,
              initiallyExpanded: true,
            ),
            const SizedBox(height: 12),
            const _InstructionCard(
              title: 'Android (Chrome)',
              icon: Icons.android_outlined,
              steps: _androidSteps,
              initiallyExpanded: false,
            ),
          ] else if (isAndroid) ...[
            const _InstructionCard(
              title: 'Android (Chrome)',
              icon: Icons.android_outlined,
              steps: _androidSteps,
              initiallyExpanded: true,
            ),
            const SizedBox(height: 12),
            const _InstructionCard(
              title: 'iPhone / iPad (Safari)',
              icon: Icons.phone_iphone_outlined,
              steps: _iosSteps,
              initiallyExpanded: false,
            ),
          ] else ...[
            const _InstructionCard(
              title: 'iPhone / iPad (Safari)',
              icon: Icons.phone_iphone_outlined,
              steps: _iosSteps,
              initiallyExpanded: true,
            ),
            const SizedBox(height: 12),
            const _InstructionCard(
              title: 'Android (Chrome)',
              icon: Icons.android_outlined,
              steps: _androidSteps,
              initiallyExpanded: true,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'once installed, PDA opens full-screen — just like a native app',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> steps;
  final bool initiallyExpanded;

  const _InstructionCard({
    required this.title,
    required this.icon,
    required this.steps,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var i = 0; i < steps.length; i++)
            _Step(number: i + 1, label: steps[i].$1, hint: steps[i].$2),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String label;
  final String hint;

  const _Step({required this.number, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (hint.isNotEmpty)
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
