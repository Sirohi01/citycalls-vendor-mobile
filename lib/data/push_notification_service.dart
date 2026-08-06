import 'package:firebase_messaging/firebase_messaging.dart';
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

  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _registerSafely(token);

    // Tokens rotate (app reinstall, data clear, FCM-side refresh) — without
    // this, a device would silently stop receiving pushes after a rotation
    // until the next full app restart happened to re-register.
    messaging.onTokenRefresh.listen(_registerSafely);
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _employeeRepo.registerFcmToken(token);
    } catch (_) {
      // Best-effort — a failed registration just means this device won't
      // get pushes until the next successful attempt (app resume, token
      // refresh), not worth surfacing to the user over.
    }
  }

  // Called on logout — without this, a device keeps receiving the outgoing
  // account's pushes (or, if a different technician logs in next on this
  // same device, would receive the previous technician's job alerts too,
  // since registerFcmToken uses $addToSet without ever clearing old owners).
  Future<void> unregisterCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _employeeRepo.unregisterFcmToken(token);
    } catch (_) {
      // Best-effort on logout too — worst case the token lingers on the old
      // account until it naturally goes stale/gets replaced.
    }
  }
}
