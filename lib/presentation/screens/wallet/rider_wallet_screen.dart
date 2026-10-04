import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_state.dart';

class RiderWalletScreen extends StatefulWidget {
  const RiderWalletScreen({super.key});

  @override
  State<RiderWalletScreen> createState() => _RiderWalletScreenState();
}

class _RiderWalletScreenState extends State<RiderWalletScreen> {
  bool _isLoading = true;
  double _availableBalance = 0.0;
  double _cashInHand = 0.0;
  double _cashLimit = 2000.0;
  bool _isFrozen = false;
  double _totalEarnings = 0.0;
  List<dynamic> _transactions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getWalletSummary();
      if (res['success'] == true && res['wallet'] != null) {
        final wallet = res['wallet'];
        setState(() {
          _availableBalance = (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
          _cashInHand = (wallet['cashInHand'] as num?)?.toDouble() ?? 0.0;
          _cashLimit = (wallet['cashLimit'] as num?)?.toDouble() ?? 2000.0;
          _isFrozen = wallet['isFrozen'] == true;
          _totalEarnings = (wallet['totalEarnings'] as num?)?.toDouble() ?? 0.0;
          _transactions = wallet['transactions'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load wallet';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cashRatio = (_cashLimit > 0) ? (_cashInHand / _cashLimit).clamp(0.0, 1.0) : 0.0;
    final bool isNearLimit = cashRatio >= 0.8;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Wallet & COD', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF248C70),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
            tooltip: 'Refresh Wallet',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF248C70)))
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              color: const Color(0xFF248C70),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),

                    // Account Frozen Alert Banner
                    if (_isFrozen)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Account Frozen! ðŸš«',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'COD cash limit reached. Deposit cash to Admin to unfreeze and accept new orders.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Near Limit Warning Banner
                    if (!_isFrozen && isNearLimit)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF248C70).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF248C70), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'COD Warning: Cash in hand is near limit (₹${_cashInHand.toStringAsFixed(0)} / ₹${_cashLimit.toStringAsFixed(0)}). Deposit cash soon to avoid account freeze.',
                                style: const TextStyle(color: Color(0xFF248C70), fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Main Balance Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF248C70), Color(0xFF248C70)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.green.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Weekly Payout Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Available', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white30),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Delivered Earnings: ₹${_totalEarnings.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                              const Chip(
                                label: Text('Paid Weekly', style: TextStyle(color: Color(0xFF248C70), fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, authState) {
                                final isVerified = authState is Authenticated && authState.user.isVerified;

                                return ElevatedButton.icon(
                                  onPressed: () {
                                    if (!isVerified) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.lock_clock_rounded, color: Colors.white),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Cannot request payout. Your profile is under review by Admin.',
                                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF248C70),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                      return;
                                    }
                                    if (_availableBalance >= 200) {
                                      _showRequestPayoutSheet(context);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Minimum balance to request payout is ₹200'),
                                          backgroundColor: const Color(0xFF248C70),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    isVerified ? Icons.payments_rounded : Icons.lock_clock_rounded,
                                    color: const Color(0xFF248C70),
                                    size: 18,
                                  ),
                                  label: Text(
                                    isVerified ? 'Request Payout Now' : 'Payout Locked (Pending Approval)',
                                    style: TextStyle(
                                      color: const Color(0xFF248C70),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Cash In Hand & COD Limit Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cash In Hand (COD Collected)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  '₹${_cashInHand.toStringAsFixed(0)} / ₹${_cashLimit.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isFrozen ? Colors.red : (isNearLimit ? Colors.orange : Colors.green),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: cashRatio,
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isFrozen ? Colors.red : (isNearLimit ? Colors.orange : Colors.green),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isFrozen
                                  ? 'Account frozen. Please submit ₹${_cashInHand.toStringAsFixed(0)} cash to admin.'
                                  : 'Limit: ₹${_cashLimit.toStringAsFixed(0)}. Account freezes automatically if limit is exceeded.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Transaction History Section
                    const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _transactions.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: const [
                                Icon(Icons.receipt_long, color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text('No wallet transactions yet', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final String type = tx['type'] ?? 'transaction';
                              final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                              final String status = tx['status'] ?? 'completed';

                              IconData icon = Icons.payments;
                              Color iconColor = Colors.green;
                              if (type.contains('cod')) {
                                icon = Icons.account_balance_wallet;
                                iconColor = Colors.orange;
                              } else if (type.contains('payout')) {
                                icon = Icons.send_to_mobile;
                                iconColor = Colors.blue;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: iconColor.withValues(alpha: 0.1),
                                    child: Icon(icon, color: iconColor, size: 20),
                                  ),
                                  title: Text(
                                    type.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    tx['createdAt'] != null ? tx['createdAt'].toString().substring(0, 10) : '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: type.contains('cod') ? Colors.orange : Colors.green,
                                        ),
                                      ),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: status == 'completed' ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showRequestPayoutSheet(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated || !authState.user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cannot request payout. Your profile is under review by Admin.',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF248C70),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    String selectedMethod = 'upi'; // 'upi' | 'bank'
    bool isSubmitting = false;

    // Retrieve initial profile details from AuthBloc
    final defaultName = authState.user.name ?? 'Rider Partner';
    final defaultUpi = authState.user.upi ?? '';
    final defaultPhone = authState.user.phone;

    final accountHolderController = TextEditingController(text: defaultName);
    final bankNameController = TextEditingController(text: 'HDFC Bank');
    final accountNumberController = TextEditingController(text: '50100234567890');
    final ifscController = TextEditingController(text: 'HDFC0001234');
    final upiController = TextEditingController(text: defaultUpi.isNotEmpty ? defaultUpi : 'rider@okhdfcbank');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF248C70).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF248C70), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Request Payout',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Available balance notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF248C70).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance:',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                        ),
                        Text(
                          '₹${_availableBalance.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF248C70)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount input
                  Text('Withdrawal Amount', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF248C70), size: 22),
                      hintText: 'Enter amount (min ₹200)',
                      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF248C70), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quick chips
                  Row(
                    children: [
                      _buildQuickChip('₹200', 200, amountController, setModalState),
                      const SizedBox(width: 8),
                      _buildQuickChip('₹500', 500, amountController, setModalState),
                      const SizedBox(width: 8),
                      _buildQuickChip('₹1000', 1000, amountController, setModalState),
                      const SizedBox(width: 8),
                      _buildQuickChip('All Balance', _availableBalance, amountController, setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Preferred Payout Mode Selection
                  Text('Preferred Payout Mode', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'upi'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'upi' ? const Color(0xFFF0FDF4) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMethod == 'upi' ? const Color(0xFF248C70) : Colors.grey[300]!,
                                width: selectedMethod == 'upi' ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, color: selectedMethod == 'upi' ? const Color(0xFF248C70) : Colors.grey[600], size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'UPI ID',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: selectedMethod == 'upi' ? FontWeight.bold : FontWeight.w500,
                                    color: selectedMethod == 'upi' ? const Color(0xFF248C70) : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'bank'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'bank' ? const Color(0xFFF0FDF4) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMethod == 'bank' ? const Color(0xFF248C70) : Colors.grey[300]!,
                                width: selectedMethod == 'bank' ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_outlined, color: selectedMethod == 'bank' ? const Color(0xFF248C70) : Colors.grey[600], size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Bank Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: selectedMethod == 'bank' ? FontWeight.bold : FontWeight.w500,
                                    color: selectedMethod == 'bank' ? const Color(0xFF248C70) : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bank & UPI Details Fields
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Payout Account Details (Sent to Admin):',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
                        _buildInputField('UPI ID', upiController, Icons.payments_outlined, 'e.g. rider@okhdfcbank'),
                        const SizedBox(height: 10),
                        _buildInputField('Account Holder Name', accountHolderController, Icons.person_outline, 'Name as per bank'),
                        const SizedBox(height: 10),
                        _buildInputField('Bank Name', bankNameController, Icons.account_balance_outlined, 'e.g. HDFC Bank'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildInputField('Account Number', accountNumberController, Icons.credit_card, 'Account No', isNumber: true),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildInputField('IFSC Code', ifscController, Icons.pin_outlined, 'IFSC Code'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final text = amountController.text.trim();
                              final numAmount = double.tryParse(text);
                              if (numAmount == null || numAmount <= 0) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid positive amount')),
                                );
                                return;
                              }
                              if (numAmount < 200) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(content: Text('Minimum withdrawal amount is ₹200')),
                                );
                                return;
                              }
                              if (numAmount > _availableBalance) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(content: Text('Amount exceeds available wallet balance')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final bankPayload = {
                                'accountHolder': accountHolderController.text.trim(),
                                'bankName': bankNameController.text.trim(),
                                'accountNumber': accountNumberController.text.trim(),
                                'ifsc': ifscController.text.trim(),
                                'upiId': upiController.text.trim(),
                                'phone': defaultPhone,
                              };

                              try {
                                final res = await ApiService.requestWithdrawal(
                                  numAmount,
                                  method: selectedMethod,
                                  bankDetails: bankPayload,
                                );

                                if (res['success'] == true) {
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Payout request of ₹${numAmount.toStringAsFixed(0)} submitted to Admin successfully!',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                      ),
                                      backgroundColor: const Color(0xFF248C70),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  await _loadWalletData();
                                  await NotificationService.syncWithdrawalNotifications();
                                } else {
                                  setModalState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Failed to submit payout request'),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF248C70),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Submit Payout Request',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickChip(
    String label,
    double amount,
    TextEditingController controller,
    StateSetter setModalState,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() {
            controller.text = amount.toStringAsFixed(0);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(icon, color: const Color(0xFF248C70), size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
