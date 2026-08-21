import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegbox_driver_app/core/constants/api_constansts.dart';

class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userPhoneKey = 'user_phone';
  static const String _hasPinKey = 'has_pin';

  // Save tokens after login
  static Future<void> saveTokens(
    String token,
    String refreshToken,
    String phone, {
    bool hasPin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_userPhoneKey, phone);
    await prefs.setBool(_hasPinKey, hasPin);

    print("💾 Tokens saved successfully:");
    print("   Phone: $phone");
    print("   Has PIN: $hasPin");
  }

  // Get current token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get saved user phone number
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  // Check if user has PIN set
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPinKey) ?? false;
  }

  // Refresh access token
  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"refreshToken": refreshToken}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'] ?? data['accessToken'];
        final newRefreshToken = data['refreshToken'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, newToken);
        if (newRefreshToken != null) {
          await prefs.setString(_refreshTokenKey, newRefreshToken);
        }
        return true;
      }
    } catch (e) {
      print("Refresh token failed: $e");
    }
    return false;
  }

  // Logout (clear tokens but keep phone & PIN info for quick re-login)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Save phone and PIN status before clearing
    final savedPhone = prefs.getString(_userPhoneKey);
    final savedHasPin = prefs.getBool(_hasPinKey) ?? false;

    print("🚪 Logging out...");
    print("   Preserving phone: $savedPhone");
    print("   Preserving hasPin: $savedHasPin");

    // Clear all data
    await prefs.clear();

    // Restore phone and PIN status for quick re-login
    if (savedPhone != null) {
      await prefs.setString(_userPhoneKey, savedPhone);
    }
    await prefs.setBool(_hasPinKey, savedHasPin);

    print("✅ Logout complete - Phone & PIN status preserved");
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
