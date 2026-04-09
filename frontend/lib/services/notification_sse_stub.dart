class NotificationSseClient {
  NotificationSseClient({
    required Future<String?> Function() tokenProvider,
    required void Function() onNotification,
  });

  bool get isConnected => false;

  void close() {}
}
