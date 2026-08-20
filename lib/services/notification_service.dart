import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Lazy, not a field initializer. These `.instance` calls throw
  // synchronously when Firebase.initializeApp() has not run or has failed,
  // and a throw from a field initializer escapes the *constructor* — before
  // any method's try/catch can see it. Behind a getter the same throw lands
  // inside the guarded block of whichever method touched it.
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  FirebaseFirestore get _db  => FirebaseFirestore.instance;

  // No Firebase dependency, so this one stays a plain field.
  final _local = FlutterLocalNotificationsPlugin();

  // ── INIT — call once in main() ───────────────────────────────────────────
  //
  // Returns false instead of throwing when push cannot be set up. Push is
  // an enhancement: a device with notifications denied, no Play Services,
  // or no Firebase app must still get a working app.
  Future<bool> init() async {
    try {
      // Request permissions
      await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
      );

      // Save FCM token to Firestore so server can target this user
      final token = await _fcm.getToken();
      if (token != null) await _saveFcmToken(token);

      // Token refresh
      _fcm.onTokenRefresh.listen(_saveFcmToken);

      // Init local notifications (for foreground display)
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotifTap,
      );

      // Foreground message handling
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      // Background / terminated tap handling
      FirebaseMessaging.onMessageOpenedApp.listen(_handleDeepLink);
      return true;
    } catch (error, stack) {
      debugPrint('NotificationService.init failed: $error\n$stack');
      return false;
    }
  }

  // ── SEND Vibe Check notifications via Cloud Function trigger ─────────────
  // The Cloud Function reads selectedFriendIds and sends FCM automatically.
  // See Cloud Functions section below.
  // No client-side send needed — Firestore write triggers the function.

  Future<void> _saveFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      // set+merge, not update: update throws 'not-found' for a user whose
      // document has not been created yet, which is every fresh install.
      await _db
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (error) {
      debugPrint('NotificationService: could not save FCM token — $error');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const channel = AndroidNotificationChannel(
      'vibe_check', 'Vibe Checks',
      importance: Importance.high,
    );
    await _local.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, channel.name,
          importance: Importance.high,
          // Quick-action buttons for YES/MAYBE/NO
          actions: [
            const AndroidNotificationAction('YES', 'YES 🔥'),
            const AndroidNotificationAction('MAYBE', 'MAYBE 🤔'),
            const AndroidNotificationAction('NO', 'NO ❌'),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'VIBE_CHECK',
        ),
      ),
      payload: message.data['vibeCheckId'],
    );
  }

  void _onNotifTap(NotificationResponse response) {
    // Navigate to vibe check reaction screen
    // Use your Navigator/GoRouter to open ReactionScreen(vibeCheckId: ...)
    final vibeCheckId = response.payload;
    if (vibeCheckId != null) {
      // navigatorKey.currentState?.pushNamed('/react', arguments: vibeCheckId);
    }
  }

  void _handleDeepLink(RemoteMessage message) {
    final vibeCheckId = message.data['vibeCheckId'];
    if (vibeCheckId != null) {
      // Navigate to reaction screen
    }
  }
}