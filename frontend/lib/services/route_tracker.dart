/// Tracks the current navigation route for use outside the widget tree.
///
/// Updated by the GoRouter redirect callback on every navigation.
/// Read by [ErrorReporter] to include the current route in error reports.
class RouteTracker {
  RouteTracker._();

  static final instance = RouteTracker._();

  String _currentRoute = '';

  String get currentRoute => _currentRoute;

  void update(String route) => _currentRoute = route;
}
