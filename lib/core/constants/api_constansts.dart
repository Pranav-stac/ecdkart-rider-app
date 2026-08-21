import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConstants {
  // --- Local development URLs ---
  static String get baseUrl {
    return 'https://api.ecdkart.co.in/api/v1';
    // return 'http://localhost:5000/api/v1';
  }

  // --- Production/Remote URL ---
  // static String get baseUrl => 'https://api.ecdkart.co.in/api/v1';
  static const String razorpayKeyId = 'rzp_live_TS6ODveEYGrxbk';

  // Auth endpoints (Driver specific)
  static String get sendOtp => "$baseUrl/auth/driver/send-otp";
  static String get verifyOtp => "$baseUrl/auth/driver/verify-otp";
  static String get loginWithPin => "$baseUrl/auth/driver/login-with-pin";
  static String get refreshToken => "$baseUrl/auth/driver/refresh-token";
  static String get deleteAccount => "$baseUrl/drivers/delete-account";

  // User endpoints
  static String get profile => "$baseUrl/user/me";

  // ✅ Driver endpoints
  static String get driverToggleOnline => "$baseUrl/drivers/toggle-online";
  static String get driverReachedStore => "$baseUrl/drivers/reached-store";
  static String get driverOrders => "$baseUrl/orders/driver/my-orders";
  static String get driverUpdateStatus => "$baseUrl/orders/driver/update-status";

  // ✅ Order endpoints (adjust based on your backend)
  static String get driverActiveOrders => "$baseUrl/drivers/orders/active";
  static String get driverOrderHistory => "$baseUrl/drivers/orders/history";
  static String get driverSummary => "$baseUrl/drivers/summary";
  static String get driverWallet => "$baseUrl/drivers/wallet";
  static String get orderDetails => "$baseUrl/orders"; // + /{orderId}
  static String get updateOrderStatus =>
      "$baseUrl/orders"; // + /{orderId}/status

  // 💰 COD endpoints
  static String get getCodBalance => "$baseUrl/drivers/cod-balance";
  static String get initiateCodPayment => "$baseUrl/drivers/cod-payment/initiate";
  static String get verifyCodPayment => "$baseUrl/drivers/cod-payment/verify";

  // ✅ Location endpoints (if you implement backend tracking)
  static String get updateLocation => "$baseUrl/drivers/update-location";
}
