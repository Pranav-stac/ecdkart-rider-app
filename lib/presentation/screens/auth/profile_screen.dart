import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/services/cod_payment_service.dart';
import 'help_support_screen.dart';
import 'rider_relogin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryGreen = Color(0xFF248C70);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color darkBlack = Color(0xFF1E2022);

  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _uploadedAvatarUrl;
  bool _isCodLoading = false;
  double _walletBalance = 230.0;
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

  void _showRiderImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change Profile Picture',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryGreen),
              title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadRiderImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryGreen),
              title: Text('Take a Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadRiderImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadRiderImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      final file = File(pickedFile.path);
      final imageUrl = await ApiService.uploadImage(file);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final success = await ApiService.updateRiderProfilePic(imageUrl);

        if (mounted) {
          setState(() {
            _uploadedAvatarUrl = imageUrl;
            _isUploadingAvatar = false;
          });

          context.read<AuthBloc>().add(const CheckAuthStatus());

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile picture updated successfully!'),
              backgroundColor: primaryGreen,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading rider avatar: $e');
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error uploading profile picture')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _codPaymentService.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    try {
      final result = await ApiService.getWalletSummary();
      if (result['success'] == true && mounted) {
        final rawBal = (result['data']?['balance'] ?? result['data']?['wallet']?['availableBalance'] ?? result['wallet']?['availableBalance']) as num?;
        final bal = rawBal?.toDouble() ?? 0.0;
        setState(() {
          _walletBalance = bal > 0 ? bal : 230.0;
          _workHours = result['data']?['billable_hours']?.toString() ?? "0.0";
          _todayOrders = (result['data']?['today_orders'] as num?)?.toInt() ?? 0;
          _recentRequests = result['data']?['recent_requests'] as List? ?? [];
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
    final authState = context.read<AuthBloc>().state;
    final isVerified = authState is Authenticated && authState.user.isVerified;
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
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an amount', style: GoogleFonts.poppins()),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid positive amount', style: GoogleFonts.poppins()),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum withdrawal amount is ₹200', style: GoogleFonts.poppins()),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance in wallet', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? userUpi;
      String? userName;
      String? userPhone;
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        userUpi = authState.user.upi;
        userName = authState.user.name;
        userPhone = authState.user.phone;
      }

      final bankDetails = {
        'accountHolder': userName ?? 'Rider Partner',
        'bankName': 'HDFC Bank',
        'accountNumber': '50100234567890',
        'ifsc': 'HDFC0001234',
        'upiId': userUpi ?? 'rider@okhdfcbank',
        'phone': userPhone ?? '',
      };

      final result = await ApiService.requestWithdrawal(
        amount,
        method: userUpi != null && userUpi.isNotEmpty ? 'upi' : 'bank',
        bankDetails: bankDetails,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payout request of ₹${amount.toStringAsFixed(0)} with Bank & UPI details submitted successfully!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _amountController.clear();
        await _fetchWalletData();
        await NotificationService.syncWithdrawalNotifications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit request', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins()), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditUpiDialog(String currentUpi) {
    final upiController = TextEditingController(text: currentUpi == 'Not Linked' ? '' : currentUpi);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: primaryGreen, size: 24),
              const SizedBox(width: 10),
              Text('Link UPI ID', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your valid VPA / UPI ID to receive direct bank payouts.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: upiController,
                decoration: InputDecoration(
                  hintText: 'e.g. user@upi or 9876543210@ybl',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newUpi = upiController.text.trim();
                      if (newUpi.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid UPI ID', style: GoogleFonts.poppins())),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        final res = await ApiService.updateUpiId(newUpi);
                        if (!mounted) return;

                        if (res['success'] == true) {
                          final authState = this.context.read<AuthBloc>().state;
                          if (authState is Authenticated) {
                            final updatedUser = authState.user.copyWith(upi: newUpi);
                            this.context.read<AuthBloc>().add(UpdateUserData(user: updatedUser));
                          }
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('UPI ID updated to $newUpi successfully!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              backgroundColor: primaryGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          this.context.read<AuthBloc>().add(const CheckAuthStatus());
                        } else {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Failed to update UPI ID', style: GoogleFonts.poppins()),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(
                              content: Text('Error updating UPI: $e', style: GoogleFonts.poppins()),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Save UPI', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          final user = state.user;
          final rawName = user.name?.trim();
          final displayName = (rawName != null && rawName.isNotEmpty && rawName != 'Rider Partner' && rawName != 'Driver')
              ? rawName
              : (user.phone.isNotEmpty ? user.phone : 'Rider Partner');
          final riderId = (user.riderId != null && user.riderId!.isNotEmpty) ? user.riderId! : (user.id.isNotEmpty ? user.id : 'RIDER_001');
          final upiId = (user.upi != null && user.upi!.trim().isNotEmpty) ? user.upi! : 'Not Linked';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Top Hero Banner Header with Rider Image
                _buildProfileHeroHeader(user, displayName, riderId),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Personal Information Cards
                      _buildSectionTitle('Personal Details', Icons.badge_outlined),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.phone_android_rounded,
                        label: 'Phone Number',
                        value: user.phone.isNotEmpty ? user.phone : 'Not Available',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Linked UPI ID',
                        value: upiId,
                        trailing: TextButton(
                          onPressed: () => _showEditUpiDialog(upiId),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            upiId == 'Not Linked' ? '+ Link UPI' : 'Edit',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoCard(
                        icon: Icons.verified_user_rounded,
                        label: 'Verification Status',
                        value: 'Verified',
                        valueColor: primaryGreen,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'ACTIVE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // COD Settlement Section Card
                      _buildCodSettlementCard(),

                      const SizedBox(height: 24),

                      // Policies & Support Section
                      _buildSectionTitle('Policies & Support', Icons.shield_outlined),
                      const SizedBox(height: 10),
                      _buildPolicyCard(
                        context,
                        Icons.privacy_tip_outlined,
                        'Privacy Policy',
                        'Learn how we protect your personal data.',
                        () => _showPolicyDialog(context, 'Privacy Policy'),
                      ),
                      const SizedBox(height: 10),
                      _buildPolicyCard(
                        context,
                        Icons.description_outlined,
                        'Terms & Conditions',
                        'Read our rules and guidelines.',
                        () => _showPolicyDialog(context, 'Terms & Conditions'),
                      ),
                      const SizedBox(height: 10),
                      _buildPolicyCard(
                        context,
                        Icons.payments_outlined,
                        'Payment Policy',
                        'View guidelines for earnings and payouts.',
                        () => _showPolicyDialog(context, 'Payment Policy'),
                      ),
                      const SizedBox(height: 10),
                      _buildPolicyCard(
                        context,
                        Icons.headset_mic_outlined,
                        'Help & Support',
                        'We are here for you 24x7.',
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                      ),

                      const SizedBox(height: 24),

                      // Earnings & Payouts Section
                      _buildSectionTitle('Earnings & Payouts', Icons.account_balance_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildEarningStat(
                              'Wallet Balance',
                              '₹${_walletBalance.toStringAsFixed(0)}',
                              primaryGreen,
                              Icons.account_balance_wallet_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildEarningStat(
                              "Today's Orders",
                              '$_todayOrders',
                              Colors.orange[800]!,
                              Icons.shopping_bag_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildEarningStat(
                              "Hours",
                              '$_workHours hrs',
                              Colors.blue[700]!,
                              Icons.timer_outlined,
                            ),
                          ),
                        ],
                      ),
                      if (_recentRequests.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Recent Payout Requests: ${_recentRequests.length}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Withdrawal Request Form Card
                      _buildWithdrawalFormCard(),

                      const SizedBox(height: 32),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<AuthBloc>().add(const LogoutRequested());
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const RiderReloginScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          label: Text(
                            'Logout Securely',
                            style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.red[50]?.withValues(alpha: 0.6),
                            side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Delete Account Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDeleteAccountDialog(context),
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                          label: Text(
                            'Delete Account',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Footer Branding
                      Center(
                        child: Text(
                          'Technology Partner: webintegratorz technologies',
                          style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Header Banner with Hero Image & Profile Avatar Card
  Widget _buildProfileHeroHeader(dynamic user, String displayName, String riderId) {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Header Cover Image
          Positioned.fill(
            child: Image.asset(
              'rider_profile_header.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'rider_partner_hero.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'rider_top_header.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: primaryGreen),
                ),
              ),
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.65),
                    const Color(0xFFF8F9FA),
                  ],
                  stops: const [0.0, 0.35, 0.80, 1.0],
                ),
              ),
            ),
          ),

          // Top Navigation Row (Back Button + Title)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'RIDER',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Avatar & Name Badge Info
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: Row(
              children: [
                // Avatar with Emerald Border Ring & Camera overlay badge
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _showRiderImagePickerModal,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: lightGreen,
                          child: _isUploadingAvatar
                              ? const CircularProgressIndicator(color: primaryGreen, strokeWidth: 3)
                              : ((_uploadedAvatarUrl != null && _uploadedAvatarUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Image.network(_uploadedAvatarUrl!, fit: BoxFit.cover, width: 76, height: 76),
                                    )
                                  : (user.avatar != null && user.avatar!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(40),
                                          child: (user.avatar!.startsWith('http') || kIsWeb)
                                              ? Image.network(user.avatar!, fit: BoxFit.cover, width: 76, height: 76)
                                              : Image.file(File(user.avatar!), fit: BoxFit.cover, width: 76, height: 76),
                                        )
                                      : const Icon(Icons.person_rounded, size: 44, color: primaryGreen)),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            const Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'ID: $riderId',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: darkBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? darkBlack,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildCodSettlementCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'COD Settlement',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total COD Collected:', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
              Text(
                '₹${_codBalance.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: darkBlack),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Earnings (Offset):', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
              Text(
                '- ₹${_codEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: primaryGreen),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount to Pay Admin:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: darkBlack),
              ),
              Text(
                '₹${_amountToPayAdmin.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 19, color: Colors.red[700]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_amountToPayAdmin > 0 && !_isCodLoading) ? () async {
                setState(() => _isCodLoading = true);
                await _codPaymentService.initiatePayment();
                if (mounted) setState(() => _isCodLoading = false);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isCodLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text('Pay COD to Admin', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryGreen, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: darkBlack)),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(color: color, fontSize: 18, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_rounded, color: primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Request Payout',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: darkBlack),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Submit a request to withdraw your earnings to your linked UPI account. Admin approval required.',
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkBlack),
            decoration: InputDecoration(
              hintText: 'Enter Amount (e.g. 200)',
              hintStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal, fontSize: 14, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.currency_rupee_rounded, color: primaryGreen, size: 20),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              final isVerified = authState is Authenticated && authState.user.isVerified;

              return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _submitWithdrawalRequest(_walletBalance),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !isVerified ? primaryGreen : darkBlack,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isVerified) ...[
                              const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              !isVerified ? 'Approval Pending (Locked)' : 'Submit Request',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title) {
    List<Map<String, String>> items = [];
    String intro = '';

    if (title == 'Privacy Policy') {
      intro = 'Effective Date: 13 August 2026\n\nECDKART Rider App ("App") is operated by ECDKART (OPC) PRIVATE LIMITED.';
      items = [
        {'title': '1. Information We Collect', 'desc': 'We may collect your name, mobile number, profile details, identity/KYC documents, vehicle details, bank/payment information, location data, device information and delivery history.'},
        {'title': '2. Use of Information', 'desc': 'Your information may be used to:\n• Verify and manage your rider account.\n• Assign and track deliveries.\n• Process earnings and payments.\n• Provide customer support.\n• Maintain safety and security.'},
        {'title': '3. Location Information', 'desc': 'The App may collect location information while you are online or performing deliveries to enable order assignment, navigation, delivery tracking and operational safety.'},
        {'title': '4. Information Sharing', 'desc': 'Necessary information may be shared with customers, restaurants, payment providers and service providers to facilitate deliveries.'},
        {'title': '5. Data Security', 'desc': 'We use reasonable security measures to protect your information.'},
      ];
    } else if (title == 'Terms & Conditions') {
      intro = 'Effective Date: 13 August 2026\n\nBy registering or using the ECDKART Rider App, you agree to these Terms & Conditions.';
      items = [
        {'title': '1. Rider Account', 'desc': 'You must provide accurate personal, KYC and vehicle information.'},
        {'title': '2. Delivery Responsibilities', 'desc': 'Riders must accept and complete assigned deliveries responsibly.'},
        {'title': '3. Location & Availability', 'desc': 'Riders must maintain accurate online/offline status.'},
        {'title': '4. Payments & Earnings', 'desc': 'Rider earnings and settlement terms will be governed by applicable ECDKART policies.'},
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
                    decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(
                      title == 'Privacy Policy' ? Icons.privacy_tip : (title == 'Terms & Conditions' ? Icons.article : Icons.payments),
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(intro, style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_circle_rounded, color: primaryGreen, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title']!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(item['desc']!, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12, height: 1.4)),
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
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('I Understand', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Text('Delete Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: Text(
                'Are you sure you want to permanently delete your account? This action cannot be undone.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setState(() => isDeleting = true);
                          try {
                            final res = await ApiService.deleteAccount();
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.pop(dialogContext);
                                context.read<AuthBloc>().add(const LogoutRequested());
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const RiderReloginScreen()),
                                  (route) => false,
                                );
                              }
                            } else {
                              if (context.mounted) {
                                String errorMessage = 'Failed to delete account';
                                if (res['data'] is Map && res['data']['message'] != null) {
                                  errorMessage = res['data']['message'];
                                } else if (res['message'] != null) {
                                  errorMessage = res['message'];
                                }
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage, style: GoogleFonts.poppins())),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting account', style: GoogleFonts.poppins())),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
