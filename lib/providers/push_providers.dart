import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/push_notification_service.dart';
import 'employee_providers.dart';

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(employeeRepositoryProvider));
});

// Foreground messages don't show a system notification banner on their own
// (that's an OS behavior for background/terminated apps only) — MainShell
// listens to this and shows an in-app SnackBar instead, since the technician
// is already looking at the app when these arrive (e.g. a new job assigned
// while they're on the Dashboard). Empty when Firebase isn't configured.
final foregroundPushMessageProvider = StreamProvider<RemoteMessage>((ref) {
  if (Firebase.apps.isEmpty) return const Stream.empty();
  return FirebaseMessaging.onMessage;
});
