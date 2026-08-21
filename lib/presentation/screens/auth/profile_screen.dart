import 'package:vegbox_driver_app/widgets/safe_image.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../../../data/services/api_service.dart';
import '../../../core/services/cod_payment_service.dart';
import 'help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryGreen = Color(0xFF22C55E);
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isCodLoading = false;
  double _walletBalance = 0.0;
  String _workHours = "0.0";
  int _todayOrders = 0;
  List<dynamic> _recentRequests = [];

  double _codBalance = 0.0;
  double _codEarnings = 0.0;
  double _amountToPayAdmin = 0.0;
  late CodPaymentService _codPaymentService;

  @override
  void initState() {
    super.initState();
    _codPaymentService = CodPaymentService(context, onSuccess: () {
      _fetchWalletData();
      _fetchCodData();
    });
    _fetchWalletData();
    _fetchCodData();
  }

  @override
  void dispose() {
    _codPaymentService.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    try {
      final result = await ApiService.getWalletSummary();
      if (result['success'] == true && mounted) {
        setState(() {
          _walletBalance = (result['data']['balance'] as num?)?.toDouble() ?? 0.0;
          _workHours = result['data']['billable_hours']?.toString() ?? "0.0";
          _todayOrders = (result['data']['today_orders'] as num?)?.toInt() ?? 0;
          _recentRequests = result['data']['recent_requests'] as List? ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching wallet data: $e");
    }
  }

  Future<void> _fetchCodData() async {
    try {
      final result = await ApiService.getCodBalance();
      if (result['success'] == true && mounted) {
        setState(() {
          _codBalance = (result['data']['codBalance'] as num?)?.toDouble() ?? 0.0;
          _codEarnings = (result['data']['codEarnings'] as num?)?.toDouble() ?? 0.0;
          _amountToPayAdmin = (result['data']['amountToPay'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching COD data: $e");
    }
  }

  Future<void> _submitWithdrawalRequest(double balance) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    if (amount < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal amount is ₹200')),
      );
      return;
    }

    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance in wallet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.requestWithdrawal(amount);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal request of ₹${amount.toStringAsFixed(0)} submitted successfully!'),
            backgroundColor: primaryGreen,
          ),
        );
        _amountController.clear();
        await _fetchWalletData(); // Refresh summary
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) return const SizedBox();
          final user = state.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  child: user.avatar != null && user.avatar!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: user.avatar!.startsWith('http')
                              ? SafeImage(user.avatar!, fit: BoxFit.cover, width: 100, height: 100)
                              : kIsWeb
                                  ? SafeImage(user.avatar!, fit: BoxFit.cover, width: 100, height: 100)
                                  : Image.file(File(user.avatar!), fit: BoxFit.cover, width: 100, height: 100),
                        )
                      : const Icon(Icons.person, size: 50, color: primaryGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name ?? 'Driver',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${user.riderId ?? user.id}',
                  style: TextStyle(color: Colors.grey[600]),
                ),

                const SizedBox(height: 32),

                // Info Cards
                _buildInfoCard(Icons.phone, 'Phone Number', user.phone),
                const SizedBox(height: 12),
                _buildInfoCard(Icons.account_balance_wallet, 'Linked UPI ID', user.upi ?? 'Not Linked'),
                const SizedBox(height: 12),
                _buildInfoCard(Icons.verified_user, 'Verification Status', 'Verified'),

                const SizedBox(height: 32),
                
                // COD Settlement Card
                _buildCodSettlementCard(),
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),

                // Policies Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Policies & Support',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPolicyCard(
                  context,
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  'Learn how we protect your personal data.',
                  () => _showPolicyDialog(context, 'Privacy Policy'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  context,
                  Icons.article_outlined,
                  'Terms & Conditions',
                  'Read our rules and guidelines.',
                  () => _showPolicyDialog(context, 'Terms & Conditions'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  context,
                  Icons.payments_outlined,
                  'Payment Policy',
                  'View guidelines for earnings and payouts.',
                  () => _showPolicyDialog(context, 'Payment Policy'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  context,
                  Icons.support_agent_outlined,
                  'Help & Support',
                  'We are here for you.',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),

                // Earnings Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Earnings & Payouts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildEarningStat('Wallet Balance', '₹${_walletBalance.toStringAsFixed(0)}', const Color(0xFF22C55E)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEarningStat("Today's Orders", '$_todayOrders', Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Withdrawal Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance, color: primaryGreen, size: 22),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Request Payout',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Submit a request to withdraw your earnings to your linked UPI account. Admin approval required.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Enter Amount (e.g. 200)',
                          hintStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 15, color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.currency_rupee, color: primaryGreen),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submitWithdrawalRequest(_walletBalance),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton.icon(
                    onPressed: () {
                      context.read<AuthBloc>().add(const LogoutRequested());
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Logout Securely', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Permanent Delete Account Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton.icon(
                    onPressed: () {
                      _showDeleteAccountDialog(context);
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text('Delete Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Technology Partner: webintegratorz technologies',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Account'),
                ],
              ),
              content: const Text(
                'Are you sure you want to permanently delete your account? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() => isDeleting = true);
                          try {
                            final res = await ApiService.deleteAccount();
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.pop(dialogContext); // Close dialog
                                context.read<AuthBloc>().add(const LogoutRequested());
                                Navigator.pop(context); // Close profile screen
                              }
                            } else {
                              if (context.mounted) {
                                String errorMessage = 'Failed to delete account';
                                if (res['data'] is Map && res['data']['message'] != null) {
                                  errorMessage = res['data']['message'];
                                } else if (res['message'] != null) {
                                  errorMessage = res['message'];
                                }
                                Navigator.pop(dialogContext); // Close dialog on error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage)),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(dialogContext); // Close dialog on error
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error deleting account')),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                        )
                      : const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEarningStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  label.contains('Balance') ? Icons.account_balance_wallet : Icons.shopping_bag,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title) {
    List<Map<String, String>> items = [];
    String intro = '';

    if (title == 'Privacy Policy') {
      intro = 'Effective Date: 13 August 2026\n\nECDKART Rider App (“App”) is operated by ECDKART (OPC) PRIVATE LIMITED.';
      items = [
        {'title': '1. Information We Collect', 'desc': 'We may collect your name, mobile number, profile details, identity/KYC documents, vehicle details, bank/payment information, location data, device information and delivery history.'},
        {'title': '2. Use of Information', 'desc': 'Your information may be used to:\n• Verify and manage your rider account.\n• Assign and track deliveries.\n• Process earnings and payments.\n• Provide customer and restaurant support.\n• Maintain safety, security and prevent fraud.'},
        {'title': '3. Location Information', 'desc': 'The App may collect location information while you are online or performing deliveries to enable order assignment, navigation, delivery tracking and operational safety.'},
        {'title': '4. Information Sharing', 'desc': 'Necessary information may be shared with customers, restaurants, payment providers and service providers to facilitate deliveries and related services, or when required by law.'},
        {'title': '5. Data Security', 'desc': 'We use reasonable security measures to protect your information, but no digital system can be guaranteed to be completely secure.'},
        {'title': '6. Account & Data Deletion', 'desc': 'You may request deletion of your account or eligible personal data through ECDKART support, subject to applicable legal, financial and operational retention requirements.'},
        {'title': '7. Contact', 'desc': 'For privacy-related queries, contact ECDKART through the support channel available in the App.\n\nBy using the Rider App, you agree to this Privacy Policy.'},
      ];
    } else if (title == 'Terms & Conditions') {
      intro = 'Effective Date: 13 August 2026\n\nBy registering or using the ECDKART Rider App, you agree to these Terms & Conditions.';
      items = [
        {'title': '1. Rider Account', 'desc': 'You must provide accurate personal, KYC and vehicle information. You are responsible for maintaining your account credentials.'},
        {'title': '2. Delivery Responsibilities', 'desc': 'Riders must accept and complete assigned deliveries responsibly, follow delivery instructions and handle food/items safely.'},
        {'title': '3. Location & Availability', 'desc': 'Riders may be required to keep location services enabled while online or completing deliveries. Riders must maintain accurate online/offline status.'},
        {'title': '4. Payments & Earnings', 'desc': 'Rider earnings, incentives, deductions and settlement terms will be governed by the applicable ECDKART rider agreement and policies.'},
        {'title': '5. Customer & Restaurant Conduct', 'desc': 'Riders must behave professionally and respectfully with customers, restaurants and ECDKART staff. Harassment, abuse, threats or discrimination are prohibited.'},
        {'title': '6. Fraud & Misuse', 'desc': 'Fake deliveries, order manipulation, account sharing, fraudulent activities, misuse of customer information or any attempt to cheat the platform are strictly prohibited.'},
        {'title': '7. Legal Compliance & Safety', 'desc': 'Riders are responsible for complying with applicable traffic, vehicle, licensing and safety requirements while performing deliveries.'},
        {'title': '8. Suspension & Termination', 'desc': 'ECDKART may suspend or terminate a rider account for fraud, misconduct, repeated delivery issues, safety violations or breach of these Terms.'},
        {'title': '9. Changes', 'desc': 'ECDKART may update these Terms from time to time. Continued use of the App constitutes acceptance of updated Terms.'},
        {'title': '10. Contact', 'desc': 'For support or complaints, contact ECDKART through the support channel available in the App.\n\nBy using the ECDKART Rider App, you agree to these Terms & Conditions.'},
      ];
    } else {
      intro = 'ECDKART Payment Policy guidelines for earnings and payouts.';
      items = [
        {'title': 'Eligibility', 'desc': 'Only drivers with completed trips can request payouts.'},
        {'title': 'Minimum Withdrawal', 'desc': 'A minimum of ₹200 is required for a payout request.'},
        {'title': 'Processing Time', 'desc': 'Payouts are usually processed within 24-48 business hours.'},
        {'title': 'Bank Delays', 'desc': 'Bank transfers may take 1-3 business days to reflect in your account.'},
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(title == 'Privacy Policy' ? Icons.privacy_tip : (title == 'Terms & Conditions' ? Icons.article : Icons.payments), color: primaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(intro, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(Icons.check_circle, color: primaryGreen, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(item['desc']!, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodSettlementCard() {
    return Card(
      elevation: 0,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.money, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Text(
                  'COD Settlement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total COD Collected:'),
                Text('₹${_codBalance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Earnings (Offset):'),
                Text('- ₹${_codEarnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount to Pay Admin:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '₹${_amountToPayAdmin.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_amountToPayAdmin > 0 && !_isCodLoading) ? () async {
                  setState(() => _isCodLoading = true);
                  await _codPaymentService.initiatePayment();
                  if (mounted) setState(() => _isCodLoading = false);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isCodLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Pay COD to Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
