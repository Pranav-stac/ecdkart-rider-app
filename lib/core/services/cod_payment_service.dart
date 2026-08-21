import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constansts.dart';

class CodPaymentService {
  late Razorpay _razorpay;
  final BuildContext context;
  final VoidCallback onSuccess;

  CodPaymentService(this.context, {required this.onSuccess}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<void> initiatePayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please login again.')),
        );
        return;
      }

      // API call to initiate payment
      final response = await http.post(
        Uri.parse(ApiConstants.initiateCodPayment),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final options = <String, dynamic>{
          'key': ApiConstants.razorpayKeyId,
          'amount': (data['amount'] * 100).round(), // Must be integer for Razorpay
          'name': 'ECD',
          'description': 'COD Settlement',
          'order_id': data['razorpayOrderId'].toString(),
          'prefill': {
            'contact': prefs.getString('user_phone') ?? '',
            'email': 'driver@ecd.com',
          },
          'theme': {
            'color': '#0C831F'
          }
        };

        _razorpay.open(options);
      } else {
        final error = jsonDecode(response.body)['message'] ?? 'Failed to initiate payment';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final verifyResponse = await http.post(
        Uri.parse(ApiConstants.verifyCodPayment),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );

      if (verifyResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('COD Settlement Successful!'),
            backgroundColor: Colors.green,
          ),
        );
        onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed! Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet selected: ${response.walletName}')),
    );
  }
}
