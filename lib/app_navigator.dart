import 'package:flutter/material.dart';

// The app has no router package — navigation is imperative Navigator.push
// everywhere (see screens/). Two things still need to navigate from outside
// a widget's BuildContext: an expired session (api_client.dart) and a tapped
// push notification (data/push_notification_service.dart). This key is how
// they reach the navigator. Same pattern as citycalls-customer-mobile.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;

// Bottom-tab indices in MainShell, named so callers outside that file don't
// have to hardcode positions.
abstract final class ShellTab {
  static const dashboard = 0;
  static const myJobs = 1;
  static const history = 2;
  static const profile = 3;
}

// A request to switch MainShell's tab from outside its widget tree — set by
// the push-notification tap handler. MainShell listens and reacts, and
// ignores it when it isn't mounted (e.g. logged out).
final ValueNotifier<int?> pendingShellTab = ValueNotifier<int?>(null);
