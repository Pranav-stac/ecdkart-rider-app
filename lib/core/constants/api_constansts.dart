import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, kReleaseMode;

import 'dart:io' show Platform;

class ApiConstants {
  // Pass --dart-define=LOCAL_IP=192.168.x.x or --dart-define=USE_LOCAL=true for local dev testing
  static const String _customLocalIp = String.fromEnvironment('LOCAL_IP', defaultValue: '');
  static const bool _useLocal = bool.fromEnvironment('USE_LOCAL', defaultValue: false);
  static const String _prodBaseUrl = 'https://ecd-kart-backend.onrender.com/api/v1';

  static String get baseUrl {
    if (kReleaseMode) {
      return _prodBaseUrl;
    }
    if (_useLocal || _customLocalIp.isNotEmpty) {
      if (_customLocalIp.isNotEmpty) {
        return 'http://$_customLocalIp:5000/api/v1';
      }
      if (kIsWeb) return 'http://localhost:5000/api/v1';
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:5000/api/v1';
      } catch (_) {}
      return 'http://localhost:5000/api/v1';
    }
    return _prodBaseUrl;
  }

  static const String razorpayKeyId = 'rzp_test_SoUrOmQ6Rc5zI4';

  // Auth endpoints (Driver specific)
  static String get sendOtp => "$baseUrl/auth/driver/send-otp";
  static String get verifyOtp => "$baseUrl/auth/driver/verify-otp";
  static String get loginWithPin => "$baseUrl/auth/driver/login-with-pin";
  static String get refreshToken => "$baseUrl/auth/driver/refresh-token";
  static String get deleteAccount => "$baseUrl/drivers/delete-account";

  // ✅ Rider Profile & Status
  static String get riderProfile => "$baseUrl/riders/profile";
  static String get riderOnboard => "$baseUrl/riders/onboard";
  static String get riderStatus => "$baseUrl/riders/status";

  // User endpoints
  static String get profile => "$baseUrl/user/me";
  static String get saveFcmToken => "$baseUrl/user/fcm-token";
  static String get riderFcmToken => "$baseUrl/riders/fcm-token";

  // ✅ Driver endpoints
  static String get driverToggleOnline => "$baseUrl/drivers/toggle-online";
  static String get driverReachedStore => "$baseUrl/drivers/reached-store";
  static String get driverOrders => "$baseUrl/orders/driver/my-orders";
  static String get driverUpdateStatus => "$baseUrl/orders/driver/update-status";

  // ✅ Order endpoints
  static String get driverActiveOrders => "$baseUrl/drivers/orders/active";
  static String get driverOrderHistory => "$baseUrl/drivers/orders/history";
  static String get driverSummary => "$baseUrl/drivers/summary";
  static String get driverWallet => "$baseUrl/payment/rider/wallet";
  static String get orderDetails => "$baseUrl/orders"; // + /{orderId}
  static String get updateOrderStatus => "$baseUrl/orders";

  // 💰 Payment & COD endpoints (New Backend)
  static String get confirmCod => "$baseUrl/payment/cod/confirm";
  static String get getCodBalance => "$baseUrl/payment/rider/wallet";
  static String get initiateCodPayment => "$baseUrl/drivers/cod-payment/initiate";
  static String get verifyCodPayment => "$baseUrl/drivers/cod-payment/verify";

  // ✅ Location endpoints
  static String get updateLocation => "$baseUrl/drivers/update-location";
}
