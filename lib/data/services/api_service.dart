import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:vegbox_driver_app/core/constants/api_constansts.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, dynamic>> _makeRequest(
    Uri url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    headers ??= {};
    headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';

    final token = await AuthService.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    log("📤 API Request: $method $url");
    if (body != null) {
      log("📤 Request Body: ${jsonEncode(body)}");
    }

    http.Response response;
    try {
      if (method == 'GET') {
        response = await http.get(url, headers: headers).timeout(const Duration(seconds: 60));
      } else if (method == 'POST') {
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 60));
      } else if (method == 'PUT') {
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 60));
      } else if (method == 'PATCH') {
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 60));
      } else if (method == 'DELETE') {
        response = await http.delete(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 60));
      } else {
        return {"success": false, "message": "Unsupported HTTP method"};
      }
    } catch (e) {
      log("❌ Network error: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains('ClientException') || errorMsg.contains('Failed to fetch') || errorMsg.contains('SocketException')) {
        return {"success": false, "message": "Network connection failed. Please check your internet connection."};
      }
      return {"success": false, "message": "An unexpected error occurred."};
    }

    log("📥 Response Status: ${response.statusCode}");
    log("📥 Response Body: ${response.body}");

    // Auto refresh token if expired
    if (response.statusCode == 401) {
      log("Token expired → trying refresh...");
      final refreshed = await AuthService.refreshAccessToken();
      if (refreshed) {
        final newToken = await AuthService.getToken();
        headers['Authorization'] = 'Bearer $newToken';

        if (method == 'GET') {
          response = await http.get(url, headers: headers).timeout(const Duration(seconds: 60));
        } else if (method == 'POST') {
          response = await http.post(
            url,
            headers: headers,
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 60));
        } else if (method == 'PUT') {
          response = await http.put(
            url,
            headers: headers,
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 60));
        } else if (method == 'PATCH') {
          response = await http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 60));
        } else if (method == 'DELETE') {
          response = await http.delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 60));
        }
      } else {
        await AuthService.logout();
        return {"success": false, "message": "session_expired"};
      }
    }

    // Parse response
    try {
      final data = jsonDecode(response.body);
      final success = response.statusCode >= 200 && response.statusCode < 300;

      log("✅ Parsed Response - Success: $success");

      return {
        "success": success,
        "data": data,
        "statusCode": response.statusCode,
      };
    } catch (e) {
      log("❌ JSON Parse Error: $e");
      return {
        "success": response.statusCode >= 200 && response.statusCode < 300,
        "data": response.body,
        "statusCode": response.statusCode,
      };
    }
  }

  // ==================== AUTH ENDPOINTS ====================

  // SEND OTP (Driver role)
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    return _makeRequest(
      Uri.parse(ApiConstants.sendOtp),
      'POST',
      body: {"phone": "+91$phone", "role": "driver"},
    );
  }

  // VERIFY OTP (with optional PIN for first-time setup)
  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp, {
    String? pin,
  }) async {
    final body = {"phone": "+91$phone", "code": otp, "role": "driver"};

    if (pin != null && pin.isNotEmpty) {
      body['pin'] = pin;
    }

    return _makeRequest(Uri.parse(ApiConstants.verifyOtp), 'POST', body: body);
  }

  // LOGIN WITH PIN
  static Future<Map<String, dynamic>> loginWithPin(
    String phone,
    String pin,
  ) async {
    log("🔑 LOGIN WITH PIN Request:");
    log("   Phone (input): $phone");
    log("   Phone (sending): +91$phone");
    log("   PIN: $pin");

    final result = await _makeRequest(
      Uri.parse(ApiConstants.loginWithPin),
      'POST',
      body: {"phone": "+91$phone", "pin": pin},
    );

    log("🔑 LOGIN WITH PIN Response:");
    log("   Success: ${result['success']}");
    log("   Data: ${result['data']}");

    return result;
  }

  // GET PROFILE
  static Future<Map<String, dynamic>> getProfile() async {
    return _makeRequest(Uri.parse(ApiConstants.profile), 'GET');
  }

  // ==================== DRIVER ENDPOINTS ====================

  // ✅ Toggle driver online/offline status
  static Future<Map<String, dynamic>> toggleOnlineStatus(bool isOnline) async {
    log("🔄 Toggle Online Status: $isOnline");

    final result = await _makeRequest(
      Uri.parse(ApiConstants.driverToggleOnline),
      'PUT',
      body: {"isOnline": isOnline},
    );

    log("🔄 Toggle Response: $result");
    return result;
  }

  // ✅ Mark driver as reached store (reset isReturning)
  static Future<Map<String, dynamic>> markReachedStore() async {
    log("🏪 Mark Reached Store");

    final result = await _makeRequest(
      Uri.parse(ApiConstants.driverReachedStore),
      'PUT',
    );

    log("🏪 Mark Reached Store Response: $result");
    return result;
  }

  // ✅ Update driver location
  static Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    return _makeRequest(
      Uri.parse(ApiConstants.updateLocation),
      'PUT',
      body: {
        "lat": latitude,
        "lng": longitude,
        if (speed != null) "speed": speed,
        if (heading != null) "heading": heading,
      },
    );
  }

  // ==================== ORDER ENDPOINTS ====================

  // ✅ Get driver's active orders
  static Future<Map<String, dynamic>> getActiveOrders() async {
    return _makeRequest(Uri.parse(ApiConstants.driverActiveOrders), 'GET');
  }

  // ✅ Get driver's order history
  static Future<Map<String, dynamic>> getOrderHistory() async {
    return _makeRequest(Uri.parse(ApiConstants.driverOrderHistory), 'GET');
  }

  // ✅ Get order details by ID
  static Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.orderDetails}/$orderId"),
      'GET',
    );
  }

  // ✅ Update order delivery status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? otp,
  }) async {
    final body = {"status": status};
    if (otp != null) {
      body['otp'] = otp;
    }
    return _makeRequest(
      Uri.parse("${ApiConstants.driverUpdateStatus}/$orderId"),
      'PUT',
      body: body,
    );
  }

  // 🚀 Send Pickup OTP
  static Future<Map<String, dynamic>> sendPickupOtp(String orderId) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/orders/driver/send-pickup-otp/$orderId"),
      'POST',
    );
  }

  // 🚀 Send Delivery OTP
  static Future<Map<String, dynamic>> sendDeliveryOtp(String orderId) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/orders/driver/send-delivery-otp/$orderId"),
      'POST',
    );
  }

  // ✅ Complete Order with OTP
  static Future<Map<String, dynamic>> completeDeliveryWithOTP({
    required String orderId,
    required String otp,
  }) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/drivers/orders/complete"),
      'POST',
      body: {"orderId": orderId, "otp": otp},
    );
  }

  // ✅ Accept assigned order
  static Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/orders/driver/accept/$orderId"),
      'PATCH',
    );
  }

  // ✅ Decline assigned order
  static Future<Map<String, dynamic>> declineOrder(String orderId, {String? reason}) async {
    final body = reason != null ? {"reason": reason} : null;
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/orders/driver/decline/$orderId"),
      'PATCH',
      body: body,
    );
  }

  // ✅ Get driver summary (today's progress)
  static Future<Map<String, dynamic>> getDriverSummary() async {
    return _makeRequest(Uri.parse(ApiConstants.driverSummary), 'GET');
  }

  // ✅ Upload driver documents and profile details to backend
  static Future<Map<String, dynamic>> uploadDriverDocuments({
    required String name,
    required String upi,
    String? email,
    XFile? profileImage,
    XFile? aadharFront,
    XFile? aadharBack,
    XFile? license,
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse("${ApiConstants.baseUrl}/drivers/documents");
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add Headers
      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add Text Fields
      request.fields['name'] = name;
      request.fields['upi'] = upi;
      if (email != null) {
        request.fields['email'] = email;
      }

      MediaType getMediaType(String filename) {
        if (filename.toLowerCase().endsWith('.png')) {
          return MediaType('image', 'png');
        } else if (filename.toLowerCase().endsWith('.webp')) {
          return MediaType('image', 'webp');
        } else if (filename.toLowerCase().endsWith('.gif')) {
          return MediaType('image', 'gif');
        }
        return MediaType('image', 'jpeg');
      }

      // Add Files
      if (profileImage != null) {
        request.files.add(http.MultipartFile.fromBytes('profile_image', await profileImage.readAsBytes(), filename: profileImage.name, contentType: getMediaType(profileImage.name)));
      }
      if (aadharFront != null) {
        request.files.add(http.MultipartFile.fromBytes('aadhar_front', await aadharFront.readAsBytes(), filename: aadharFront.name, contentType: getMediaType(aadharFront.name)));
      }
      if (aadharBack != null) {
        request.files.add(http.MultipartFile.fromBytes('aadhar_back', await aadharBack.readAsBytes(), filename: aadharBack.name, contentType: getMediaType(aadharBack.name)));
      }
      if (license != null) {
        request.files.add(http.MultipartFile.fromBytes('license', await license.readAsBytes(), filename: license.name, contentType: getMediaType(license.name)));
      }

      log("📤 API Multipart Request to $uri");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      log("📥 Response Status: ${response.statusCode}");
      log("📥 Response Body: ${response.body}");

      final data = jsonDecode(response.body);
      final success = response.statusCode >= 200 && response.statusCode < 300;

      return {
        "success": success,
        "data": data,
        "statusCode": response.statusCode,
      };
    } catch (e) {
      log("❌ Multipart Upload Error: $e");
      return {"success": false, "message": "Upload failed: $e"};
    }
  }

  // ✅ Get driver's wallet summary (balance, billable hours, recent requests)
  static Future<Map<String, dynamic>> getWalletSummary() async {
    return _makeRequest(Uri.parse(ApiConstants.driverWallet), 'GET');
  }

  // 💰 Get driver's COD balance
  static Future<Map<String, dynamic>> getCodBalance() async {
    return _makeRequest(Uri.parse(ApiConstants.getCodBalance), 'GET');
  }

  // ✅ Request a wallet withdrawal payout
  static Future<Map<String, dynamic>> requestWithdrawal(double amount) async {
    return _makeRequest(
      Uri.parse("${ApiConstants.baseUrl}/drivers/withdraw"),
      'POST',
      body: {"amount": amount},
    );
  }

  // ✅ Permanent Account Delete
  static Future<Map<String, dynamic>> deleteAccount() async {
    return _makeRequest(Uri.parse(ApiConstants.deleteAccount), 'DELETE');
  }
}
