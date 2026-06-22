import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/june_client.dart';

/// Thin wrapper around `permission_handler` + `firebase_messaging` so the rest
/// of the app can ask for a push token without caring about which platform
/// it's on or whether Firebase is wired up yet.
///
/// IMPORTANT: We deliberately DO NOT call `Firebase.initializeApp()` anywhere
/// in this pass. Without `google-services.json` (Android) and
/// `GoogleService-Info.plist` (iOS) it throws and crashes the app.
/// Every Firebase call is wrapped in try/catch so the app fails calm until
/// the user runs `flutterfire configure` and drops the config files in.
class NotificationService {
  /// Asks the OS for notification permission. Returns true if granted (or if
  /// already granted on a prior run). Safe to call repeatedly.
  static Future<bool> ensurePermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isProvisional;
    } catch (_) {
      return false;
    }
  }

  /// Returns the device-side push token: APNs token on iOS, FCM token on
  /// Android. Returns null when:
  ///   - permission isn't granted
  ///   - Firebase isn't initialized yet (the expected state today)
  ///   - the platform isn't supported (web, desktop)
  static Future<String?> getDeviceToken() async {
    try {
      if (Platform.isIOS) {
        // APNs token is what the backend needs to talk to Apple directly.
        // FirebaseMessaging.getAPNSToken() returns null until Firebase is
        // configured and APNs is set up — that's fine, we return null.
        return await FirebaseMessaging.instance.getAPNSToken();
      }
      if (Platform.isAndroid) {
        return await FirebaseMessaging.instance.getToken();
      }
      return null;
    } catch (_) {
      // Firebase not initialized, no APNs entitlement, simulator without
      // push capability, etc. All silently mean "no token" for now.
      return null;
    }
  }

  /// One-shot helper: request permission, fetch the token, send it to the
  /// backend. Silently no-ops on any failure so it's safe to call from
  /// `initState` without blocking the UI.
  ///
  /// TODO: swap stub for real Firebase when GoogleService-Info.plist +
  /// google-services.json land — until then `getDeviceToken()` will return
  /// null and this method becomes a no-op past the permission prompt.
  static Future<void> registerIfPossible(JuneClient client) async {
    try {
      if (!await ensurePermission()) return;
      final token = await getDeviceToken();
      if (token == null) return;
      final platform = Platform.isIOS ? 'ios' : 'android';
      await client.registerDevice(platform: platform, token: token);
    } catch (_) {
      // fail calm
    }
  }
}
