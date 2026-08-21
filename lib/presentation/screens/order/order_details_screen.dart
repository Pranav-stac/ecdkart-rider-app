import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../logic/blocs/driver/driver_bloc.dart';
import '../../../logic/blocs/driver/driver_event.dart';
import '../../../logic/blocs/driver/driver_state.dart';
import '../../../data/services/api_service.dart';
import 'order_tracking_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color lightGreen = Color(0xFFE8F5E9);
  bool _isLoading = false;
  late Map<String, dynamic> _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final customer = _currentOrder['customer'] ?? {};
    final address = _currentOrder['address'] ?? _currentOrder['deliveryAddress'] ?? {};
    final items = _currentOrder['items'] as List? ?? [];
    final restaurant = _currentOrder['restaurant'] ?? {};
    final deliveryStatus = _currentOrder['deliveryStatus'] ?? 'Unknown';

    // Dynamic buttons depending on status
    String actionBtnText = '';
    Color actionBtnColor = primaryGreen;
    bool showActionButton = true;

    if (deliveryStatus == 'driver_notified') {
      showActionButton = false;
    } else if (deliveryStatus == 'accepted' || deliveryStatus == 'assigned') {
      actionBtnText = 'Mark Reached Store';
      actionBtnColor = Colors.orange[700]!;
    } else if (deliveryStatus == 'reached_store') {
      actionBtnText = 'Waiting for Restaurant';
      actionBtnColor = Colors.orange[300]!;
    } else if (deliveryStatus == 'picked_up') {
      actionBtnText = 'Complete Delivery';
      actionBtnColor = primaryGreen;
    } else {
      showActionButton = false;
    }

    return BlocListener<DriverBloc, DriverState>(
      listener: (context, state) {
        if (state is OrderStatusUpdated) {
          setState(() {
            _isLoading = false;
            final matched = state.orders.firstWhere(
              (o) => o['_id'] == widget.order['_id'],
              orElse: () => null,
            );
            if (matched != null) {
              _currentOrder = matched;
            } else {
              _currentOrder['deliveryStatus'] = state.status;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: primaryGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (state.status == 'delivered') {
            Navigator.pop(context);
          }
        } else if (state is DriverError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is ActiveOrdersLoaded) {
          final matched = state.orders.firstWhere(
            (o) => o['_id'] == widget.order['_id'],
            orElse: () => null,
          );
          if (matched != null && mounted) {
            setState(() {
              _currentOrder = matched;
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('Order #${_currentOrder['orderNumber'] ?? 'N/A'}'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DELIVERY STATUS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (deliveryStatus == 'out_for_delivery' || deliveryStatus == 'delivered'
                                        ? primaryGreen
                                        : Colors.orange[700]!)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                deliveryStatus.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  color: deliveryStatus == 'out_for_delivery' || deliveryStatus == 'delivered'
                                      ? primaryGreen
                                      : Colors.orange[700]!,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (deliveryStatus != 'driver_notified' && deliveryStatus != 'delivered' && deliveryStatus != 'cancelled')
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderTrackingScreen(
                                order: _currentOrder,
                                isToRestaurant: ['accepted', 'assigned', 'reached_store'].contains(deliveryStatus),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Track Location / Route on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),

                  if (restaurant['name'] != null) ...[
                    _buildSection(
                      title: 'MERCHANT PARTNER',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.storefront, 'Restaurant/Store', restaurant['name']),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.pin_drop_outlined, 'Store Location', restaurant['address'] ?? 'N/A'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],



                  // Customer Details
                  _buildSection(
                    title: 'DELIVERY DETAILS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(Icons.person_outline, 'Customer Name', customer['name'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.phone_outlined, 'Customer Contact', _currentOrder['deliveryPhone'] ?? customer['phone'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.location_on_outlined,
                          'Delivery Address',
                          (address is String) ? address : (address?['fullAddress'] ?? '${address?['addressLine'] ?? ''}, ${address?['city'] ?? ''}'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Items List
                  _buildSection(
                    title: 'ORDER ITEMS',
                    child: Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final qty = item['qty'] ?? item['quantity'] ?? 1;
                            final price = item['price'] ?? 0;
                            final name = item['name'] ?? 'Item';
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${qty}x $name',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text(
                                  '₹${(price * qty).toStringAsFixed(1)}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price Breakdown
                  _buildSection(
                    title: 'BILL DETAILS',
                    child: Column(
                      children: [
                        _buildPriceRow('Items Subtotal', '₹${(_currentOrder['totalAmount'] ?? 0).toStringAsFixed(1)}'),
                        const SizedBox(height: 8),
                        _buildPriceRow('Delivery Fee', '₹${(_currentOrder['deliveryCharge'] ?? 0).toStringAsFixed(1)}'),
                        const SizedBox(height: 8),
                        _buildPriceRow('Taxes & GST', '₹${(_currentOrder['gst'] ?? 0).toStringAsFixed(1)}'),
                        if ((_currentOrder['totalDiscount'] ?? 0) > 0) ...[
                          const SizedBox(height: 8),
                          _buildPriceRow(
                            'Coupon Discount',
                            '- ₹${(_currentOrder['totalDiscount'] ?? 0).toStringAsFixed(1)}',
                            isDiscount: true,
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payable Amount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '₹${(_currentOrder['payableAmount'] ?? _currentOrder['totalAmount'] ?? 0).toStringAsFixed(1)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryGreen),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (showActionButton) const SizedBox(height: 80), // Padding for floating action button space
                ],
              ),
            ),

            // Driver notify Accept/Decline action buttons
            if (deliveryStatus == 'driver_notified')
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<DriverBloc>().add(DeclineOrder(orderId: _currentOrder['_id'] ?? ''));
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Decline', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<DriverBloc>().add(AcceptOrder(orderId: _currentOrder['_id'] ?? ''));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Live status updates floating action button
            if (showActionButton)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
                  ),
                  child: Row(
                    children: [
                      if (deliveryStatus == 'picked_up' || deliveryStatus == 'out_for_delivery')
                        Expanded(
                          child: InlineDeliveryOtpForm(order: _currentOrder),
                        )
                      else
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                final orderId = _currentOrder['_id'] ?? '';
                                if (deliveryStatus == 'accepted' || deliveryStatus == 'assigned') {
                                  setState(() => _isLoading = true);
                                  context.read<DriverBloc>().add(
                                        UpdateOrderStatus(orderId: orderId, status: 'reached_store'),
                                      );
                                } else if (deliveryStatus == 'reached_store') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please show your OTP to the restaurant so they can verify the pickup.')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: actionBtnColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                actionBtnText,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            if (deliveryStatus == 'reached_store')
              Positioned(
                bottom: 85,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SHOW THIS OTP TO RESTAURANT',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentOrder['pickupOtp'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryGreen)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDiscount ? primaryGreen : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class InlineDeliveryOtpForm extends StatefulWidget {
  final Map<String, dynamic> order;
  const InlineDeliveryOtpForm({Key? key, required this.order}) : super(key: key);

  @override
  _InlineDeliveryOtpFormState createState() => _InlineDeliveryOtpFormState();
}

class _InlineDeliveryOtpFormState extends State<InlineDeliveryOtpForm> {
  static const Color primaryGreen = Color(0xFF22C55E);

  final TextEditingController _otpController = TextEditingController();
  bool _isSendingOtp = false;

  void _sendOtp() async {
    setState(() => _isSendingOtp = true);
    try {
      final response = await ApiService.sendDeliveryOtp(widget.order['_id'] ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'OTP sent successfully'), backgroundColor: primaryGreen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _verifyOtp() {
    final code = _otpController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 4-digit OTP')),
      );
      return;
    }
    context.read<DriverBloc>().add(
      UpdateOrderStatus(
        orderId: widget.order['_id'] ?? '',
        status: 'delivered',
        otp: code,
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Complete Delivery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryGreen),
              ),
              ElevatedButton.icon(
                onPressed: _isSendingOtp ? null : _sendOtp,
                icon: _isSendingOtp ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 14),
                label: const Text('Send OTP', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter 4-digit OTP',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryGreen, width: 2)),
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
