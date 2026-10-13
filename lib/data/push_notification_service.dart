import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../app_navigator.dart';
import '../screens/notification_center_screen.dart';
import 'employee_repository.dart';

// Registers this device's FCM token with the backend so PUSH-channel
// notifications (citycalls-api's src/lib/pushAdapter.ts, resolved for
// employees via lib/notifications.ts's resolveContact() -> EmployeeModel)
// can actually reach it — the moment a job gets assigned
// (SERVICE_REQUEST_ASSIGNED trigger), this is what lets the technician find
// out without opening the app to pull-to-refresh. Independently implemented
// from citycalls-customer-mobile's copy — no shared code between the apps.
class PushNotificationService {
  final EmployeeRepository _employeeRepo;
  PushNotificationService(this._employeeRepo);

  bool _tapHandlersAttached = false;

  // Firebase only initializes when google-services.json (Android) /
  // GoogleService-Info.plist (iOS) is bundled — see main.dart. Without it
  // every FirebaseMessaging call throws, so the whole service is a no-op.
  bool get isAvailable => Firebase.apps.isNotEmpty;

  // [canRegisterToken]: the backend only stores FCM tokens on Employee
  // records (POST /employees/me/fcm-token). VENDOR_TECHNICIAN and vendor
  // owners have no Employee record, so for them registration would just
  // 404 — they still get in-app notifications via the Notification Center.
  Future<void> initialize({required bool canRegisterToken}) async {
    if (!isAvailable) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (canRegisterToken) {
        final token = await messaging.getToken();
        if (token != null) await _registerSafely(token);
        // Tokens rotate (reinstall, data clear, FCM-side refresh).
        messaging.onTokenRefresh.listen(_registerSafely);
      }
      _attachTapHandlers(messaging);
    } catch (_) {
      // Push is best-effort — the app works fine without it.
    }
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _employeeRepo.registerFcmToken(token);
    } catch (_) {
      // Best-effort — retried on the next token refresh / app start.
    }
  }

  // citycalls-api sends only `{triggerKey}` as push data (no entity id), so
  // a tap routes to the right SCREEN rather than the exact job: job-related
  // pushes open the My Jobs tab, everything else the Notification Center.
  void _attachTapHandlers(FirebaseMessaging messaging) {
    if (_tapHandlersAttached) return;
    _tapHandlersAttached = true;
    FirebaseMessaging.onMessageOpenedApp.listen(_openFor);
    // A push that launched the app from terminated state is only readable
    // once, here.
    messaging.getInitialMessage().then((message) {
      if (message != null) _openFor(message);
    });
  }

  void _openFor(RemoteMessage message) {
    final navigator = appNavigator;
    if (navigator == null) return;
    final triggerKey =
        (message.data['triggerKey'] ?? '').toString().toUpperCase();
    if (triggerKey.contains('SERVICE_REQUEST') ||
        triggerKey.contains('JOB') ||
        triggerKey.contains('ASSIGN')) {
      pendingShellTab.value = ShellTab.myJobs;
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
  }

  // Called on logout — without this, a device keeps receiving the outgoing
  // account's pushes (or, if a different technician logs in next on this
  // same device, would receive the previous technician's job alerts too,
  // since registerFcmToken uses $addToSet without ever clearing old owners).
  Future<void> unregisterCurrentToken() async {
    if (!isAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _employeeRepo.unregisterFcmToken(token);
    } catch (_) {
      // Best-effort on logout too.
    }
  }
}
