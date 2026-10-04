import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("Handling background FCM message in Rider app: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _cachedToken;
  static const String _notificationsKey = 'rider_notifications_list';

  // ValueNotifier to trigger UI updates for badge on Notification Bell icon
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  // Stream controller for in-app approval/notification events
  static final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onNotificationReceived =>
      _notificationStreamController.stream;

  /// Initialize Firebase Cloud Messaging for the Rider App
  static Future<void> initialize() async {
    await refreshUnreadCount();
    if (_initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // 1. Request Notification Permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      log("FCM Notification Permission status: ${settings.authorizationStatus}");

      // 2. Configure Foreground Presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Register device token with backend
      await registerToken();

      // 4. Listen for Token Refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        log("FCM Token refreshed: $newToken");
        _cachedToken = newToken;
        ApiService.saveFcmToken(newToken);
      });

      // 5. Foreground Message Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log("Foreground FCM received: ${message.notification?.title} - ${message.notification?.body}");
        final title = message.notification?.title ?? 'Notification';
        final body = message.notification?.body ?? '';
        final payload = {
          'title': title,
          'body': body,
          'data': message.data,
          'type': message.data['type'] ?? '',
        };
        addNotification(
          title: title,
          body: body,
          type: message.data['type'] ?? 'GENERAL',
        );
        _notificationStreamController.add(payload);
      });

      // 6. When app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log("Notification clicked/opened app: ${message.data}");
        final title = message.notification?.title ?? 'Notification';
        final body = message.notification?.body ?? '';
        addNotification(
          title: title,
          body: body,
          type: message.data['type'] ?? 'GENERAL',
        );
        _notificationStreamController.add({
          'title': title,
          'body': body,
          'data': message.data,
          'type': message.data['type'] ?? '',
          'clicked': true,
        });
      });

      _initialized = true;
    } catch (e) {
      log("NotificationService initialization error: $e");
    }
  }

  /// Add a notification to the local list & update badge
  static Future<void> addNotification({
    required String title,
    required String body,
    String type = 'GENERAL',
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> currentList = await getNotifications();

      // Prevent duplicate exact title + body or same withdrawalId in short succession
      final withdrawalId = data?['withdrawalId']?.toString();
      final isDuplicate = currentList.any((n) {
        if (withdrawalId != null && withdrawalId.isNotEmpty) {
          if (n['data'] != null && n['data']['withdrawalId'] == withdrawalId && n['type'] == type) {
            return true;
          }
        }
        return n['title'] == title &&
            n['body'] == body &&
            DateTime.now().difference(DateTime.tryParse(n['timestamp'] ?? '') ?? DateTime.now()).inMinutes < 5;
      });

      if (isDuplicate) return;

      final newNotification = {
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };

      currentList.insert(0, newNotification);
      await prefs.setString(_notificationsKey, jsonEncode(currentList));
      await refreshUnreadCount();
    } catch (e) {
      log("Error saving notification: $e");
    }
  }

  /// Sync withdrawal requests from backend and generate payout notifications
  static Future<void> syncWithdrawalNotifications() async {
    try {
      final withdrawals = await ApiService.getWithdrawals();
      if (withdrawals.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> currentList = await getNotifications();
      bool modified = false;

      for (var w in withdrawals) {
        final status = (w['status'] ?? '').toString().toLowerCase();
        final id = w['_id']?.toString() ?? '';
        final amount = w['amount'] ?? 0;
        final approvedBy = w['approvedBy'] ?? 'Admin';
        final rejectedBy = w['rejectedBy'] ?? 'Admin';
        final utr = w['utrNumber'] ?? '';
        final adminNote = w['adminNote'] ?? '';
        final processedAt = w['processedAt'] ?? w['updatedAt'] ?? w['createdAt'] ?? DateTime.now().toIso8601String();

        if (status == 'approved') {
          final notifId = 'payout_appr_$id';
          final alreadyExists = currentList.any((n) => n['id'] == notifId || (n['data'] != null && n['data']['withdrawalId'] == id));
          if (!alreadyExists) {
            final title = 'Payment Successful! 💰';
            final paidVia = (w['paidVia'] ?? w['method'] ?? 'upi').toString().toLowerCase();
            final details = (w['paidToDetails'] is Map ? w['paidToDetails'] : (w['bankDetails'] is Map ? w['bankDetails'] : {})) as Map;
            final upiId = (details['upiId'] ?? details['upi'] ?? '').toString();
            final accNum = (details['accountNumber'] ?? '').toString();
            final accLast4 = accNum.length >= 4 ? accNum.substring(accNum.length - 4) : accNum;
            final ifsc = (details['ifsc'] ?? details['ifscCode'] ?? '').toString();
            final bankName = (details['bankName'] ?? 'Bank').toString();

            String body = '';
            if (paidVia == 'upi' && upiId.isNotEmpty) {
              body = '₹$amount has been successfully sent to your UPI ID ($upiId).${utr.toString().isNotEmpty ? ' Ref/UTR: $utr.' : ''} Paid by $approvedBy.';
            } else if (paidVia == 'bank' || accNum.isNotEmpty) {
              body = '₹$amount has been successfully transferred to your $bankName A/C ending in ${accLast4.isNotEmpty ? accLast4 : '****'}${ifsc.isNotEmpty ? ' (IFSC: $ifsc)' : ''}.${utr.toString().isNotEmpty ? ' Ref/UTR: $utr.' : ''} Paid by $approvedBy.';
            } else {
              body = 'Your payout request of ₹$amount has been approved and paid by $approvedBy.${utr.toString().isNotEmpty ? ' Ref/UTR: $utr.' : ''}';
            }

            currentList.insert(0, {
              'id': notifId,
              'title': title,
              'body': body,
              'type': 'PAYOUT_APPROVED',
              'isRead': false,
              'timestamp': processedAt,
              'data': {
                'withdrawalId': id,
                'amount': amount,
                'status': 'approved',
                'paidVia': paidVia,
                'upiId': upiId,
                'accountNumber': accNum,
                'ifsc': ifsc,
                'bankName': bankName,
                'approvedBy': approvedBy,
                'utrNumber': utr,
                'adminNote': adminNote,
              },
            });
            modified = true;
          }
        } else if (status == 'rejected') {
          final notifId = 'payout_rej_$id';
          final alreadyExists = currentList.any((n) => n['id'] == notifId || (n['data'] != null && n['data']['withdrawalId'] == id));
          if (!alreadyExists) {
            final title = 'Payout Request Rejected ⚠️';
            final body = 'Your payout request of ₹$amount was rejected by $rejectedBy. Reason: ${adminNote.isNotEmpty ? adminNote : 'Rejected by admin'}';
            currentList.insert(0, {
              'id': notifId,
              'title': title,
              'body': body,
              'type': 'PAYOUT_REJECTED',
              'isRead': false,
              'timestamp': processedAt,
              'data': {
                'withdrawalId': id,
                'amount': amount,
                'status': 'rejected',
                'rejectedBy': rejectedBy,
                'reason': adminNote,
              },
            });
            modified = true;
          }
        }
      }

      if (modified) {
        currentList.sort((a, b) {
          final timeA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2020);
          final timeB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2020);
          return timeB.compareTo(timeA);
        });
        await prefs.setString(_notificationsKey, jsonEncode(currentList));
        await refreshUnreadCount();
      }
    } catch (e) {
      log("Error syncing withdrawal notifications: $e");
    }
  }

  /// Retrieve all stored notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      if (raw == null || raw.isEmpty) {
        return [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      log("Error reading notifications: $e");
    }
    return [];
  }

  /// Refresh unread count and notify listeners
  static Future<int> refreshUnreadCount() async {
    try {
      final list = await getNotifications();
      final unreadCount = list.where((n) => n['isRead'] != true).length;
      unreadCountNotifier.value = unreadCount;
      return unreadCount;
    } catch (_) {
      return 0;
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getNotifications();
      for (var item in list) {
        item['isRead'] = true;
      }
      await prefs.setString(_notificationsKey, jsonEncode(list));
      unreadCountNotifier.value = 0;
    } catch (e) {
      log("Error marking notifications as read: $e");
    }
  }

  /// Clear all notifications
  static Future<void> clearNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      unreadCountNotifier.value = 0;
    } catch (e) {
      log("Error clearing notifications: $e");
    }
  }

  /// Get device token and upload to backend
  static Future<String?> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        log("Got FCM Device Token: ${token.substring(0, 15)}...");
        _cachedToken = token;
        await ApiService.saveFcmToken(token);
        return token;
      }
    } catch (e) {
      log("Error fetching FCM token: $e");
    }
    return _cachedToken;
  }

  static String? get cachedToken => _cachedToken;
}
