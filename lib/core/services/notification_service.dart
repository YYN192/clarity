import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Firebase Cloud Messaging integration: permission, this device's registration
/// token, per-device storage in Firestore (so a backend can target specific
/// devices), and surfacing foreground messages as in-app SnackBars. The system
/// tray shows notification-payload messages automatically when backgrounded.
abstract class NotificationService {
  /// Wire up foreground + token-refresh listeners. Call once at startup.
  Future<void> initialize();

  /// Requests notification permission and registers this device's token in
  /// Firestore. Returns true if notifications are now enabled (permission granted).
  Future<bool> enable();

  /// Removes this device's token registration.
  Future<void> disable();

  /// Records where this **device** is, for alert targeting.
  ///
  /// Must only be called with GPS-derived coordinates. The city being browsed
  /// is irrelevant here — searching for Tokyo must not redirect this phone's
  /// storm alerts to Tokyo.
  ///
  /// [city] is written together with the coordinates so the two can never drift
  /// apart; pass `null` when only a position is known and let the backend
  /// resolve the name from the coordinates.
  ///
  /// Cached until the device is registered, then flushed to its token document.
  Future<void> updateAlertLocation({
    required double lat,
    required double lon,
    String? city,
  });

  /// Records display preferences so the backend can format the message text.
  /// Independent of [updateAlertLocation] — changing units must not move where
  /// alerts are sent.
  Future<void> updateDisplayPreferences({
    required String units,
    required String language,
  });

  /// Global messenger used to show foreground alerts as in-app SnackBars.
  GlobalKey<ScaffoldMessengerState> get messengerKey;
}

class NotificationServiceImpl implements NotificationService {
  final FirebaseMessaging messaging;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  NotificationServiceImpl({
    required this.messaging,
    required this.firestore,
    required this.auth,
  });

  /// Firestore collection of device tokens, keyed by the token itself.
  static const String _collection = 'fcm_tokens';

  bool _registered = false;

  // Last known alert location/prefs, cached until the device is registered.
  double? _lat;
  double? _lon;
  String? _city;
  String _units = 'metric';
  String _language = 'en';

  @override
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Future<void> initialize() async {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages → in-app SnackBar (background/terminated are shown by
    // the OS tray automatically for notification-payload messages).
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final text = [notification.title, notification.body]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' — ');
      if (text.isEmpty) return;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });

    // Keep the stored token fresh while registered.
    messaging.onTokenRefresh.listen((token) {
      if (_registered) _storeToken(token);
    });
  }

  @override
  Future<bool> enable() async {
    try {
      final settings = await messaging.requestPermission();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        _registered = false;
        return false;
      }

      // On iOS this throws unless APNs is configured (paid Apple Developer
      // account + Push capability). Treat that as "not available" rather than
      // letting it crash the settings flow.
      final token = await messaging.getToken();
      if (token == null) {
        _registered = false;
        return false;
      }

      _registered = true;
      debugPrint('FCM registration token (paste into Firebase Console test send): $token');
      await _storeToken(token);
      // Flush anything captured before registration completed.
      await _writeAlertLocation();
      await _writeDisplayPreferences();
      return true;
    } catch (e) {
      debugPrint('Could not enable push notifications: $e');
      _registered = false;
      return false;
    }
  }

  @override
  Future<void> disable() async {
    _registered = false;
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await firestore.collection(_collection).doc(token).delete();
      }
    } catch (e) {
      debugPrint('Failed to remove FCM token: $e');
    }
  }

  @override
  Future<void> updateAlertLocation({
    required double lat,
    required double lon,
    String? city,
  }) async {
    _lat = lat;
    _lon = lon;
    _city = city;
    if (!_registered) return; // flushed by enable() once registered
    await _writeAlertLocation();
  }

  @override
  Future<void> updateDisplayPreferences({
    required String units,
    required String language,
  }) async {
    _units = units;
    _language = language;
    if (!_registered) return; // flushed by enable() once registered
    await _writeDisplayPreferences();
  }

  Future<void> _writeAlertLocation() async {
    if (_lat == null || _lon == null) return;
    try {
      final token = await messaging.getToken();
      if (token == null) return;
      await firestore.collection(_collection).doc(token).set({
        'token': token, // required by the Firestore security rule
        'lat': _lat,
        'lon': _lon,
        // Always written alongside lat/lon — a null here clears a previously
        // stored name rather than leaving one that no longer matches.
        'city': _city,
        // Distinct from `updatedAt`: the dispatcher uses this to skip devices
        // whose position is too old to trust.
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to store alert location: $e');
    }
  }

  Future<void> _writeDisplayPreferences() async {
    try {
      final token = await messaging.getToken();
      if (token == null) return;
      await firestore.collection(_collection).doc(token).set({
        'token': token,
        'units': _units,
        'lang': _language,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to store display preferences: $e');
    }
  }

  Future<void> _storeToken(String token) async {
    try {
      await firestore.collection(_collection).doc(token).set({
        'token': token,
        'uid': auth.currentUser?.uid,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'severeWeatherAlerts': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Firestore may not be enabled yet — don't crash the app over it.
      debugPrint('Failed to store FCM token: $e');
    }
  }
}
