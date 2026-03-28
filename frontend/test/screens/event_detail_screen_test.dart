import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/event.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/event_provider.dart';
import 'package:pda/screens/event_detail_screen.dart';

// Narrow viewport → drawer nav, avoiding wide AppBar overflow.
const _kTestSize = Size(700, 900);

final _event = Event(
  id: 'evt-1',
  title: 'Movie Night',
  description: 'Watch a great film together.',
  startDatetime: DateTime(2026, 4, 1, 19),
  endDatetime: DateTime(2026, 4, 1, 21),
  location: 'The usual spot',
  whatsappLink: 'https://chat.whatsapp.com/abc123',
  rsvpEnabled: true,
  createdById: 'u-creator',
  createdByName: 'Alice',
);

Widget _buildSubject({Event? event, AuthNotifier? authNotifier}) {
  final resolvedEvent = event ?? _event;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/events/:id',
        builder:
            (_, state) =>
                EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
    ],
    initialLocation: '/events/${resolvedEvent.id}',
  );
  return ProviderScope(
    overrides: [
      eventsProvider.overrideWith((_) async => [resolvedEvent]),
      authProvider.overrideWith(() => authNotifier ?? _GuestAuthNotifier()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows event title and location', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Movie Night'), findsOneWidget);
    expect(find.text('The usual spot'), findsOneWidget);
  });

  testWidgets('shows description', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.textContaining('Watch a great film'), findsOneWidget);
  });

  testWidgets('shows host name', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('shows WhatsApp link for authenticated member', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(authNotifier: _MemberAuthNotifier(userId: 'u-other')),
    );
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp group'), findsOneWidget);
  });

  testWidgets('does not show WhatsApp link for guest', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp group'), findsNothing);
  });

  testWidgets('event not found shows fallback text', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/events/:id',
          builder:
              (_, state) =>
                  EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
      ],
      initialLocation: '/events/nonexistent',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsProvider.overrideWith((_) async => [_event]),
          authProvider.overrideWith(() => _GuestAuthNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event not found.'), findsOneWidget);
  });
}

class _GuestAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> logout() async {}
}

class _MemberAuthNotifier extends AuthNotifier {
  final String userId;
  _MemberAuthNotifier({required this.userId});

  @override
  Future<User?> build() async =>
      User(id: userId, phoneNumber: '+12025551234', displayName: 'Member');

  @override
  Future<void> logout() async {}
}
