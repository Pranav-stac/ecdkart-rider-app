import 'package:flutter/material.dart';

class CodPaymentService {
  final BuildContext context;
  final VoidCallback onSuccess;

  CodPaymentService(this.context, {required this.onSuccess});

  void dispose() {}

  Future<void> initiatePayment() async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('COD Settlement Processed Successfully (Offline Mock Mode)'),
        backgroundColor: Colors.green,
      ),
    );
    onSuccess();
  }
}
