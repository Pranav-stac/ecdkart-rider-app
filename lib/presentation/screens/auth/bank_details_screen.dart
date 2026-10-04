import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/user_models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../home/driver_home_screen.dart';

class BankDetailsScreen extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String? pin;
  final String? profileImageBase64;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleYear;
  final String? regNumber;
  final String? licenseNumber;
  final String? licenseExpiry;
  final String? licenseImageBase64;
  final String? panNumber;
  final String? panImageBase64;
  final String? aadhaarNumber;
  final String? aadhaarImageBase64;

  const BankDetailsScreen({
    super.key,
    this.name,
    this.email,
    this.phone,
    this.pin,
    this.profileImageBase64,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.regNumber,
    this.licenseNumber,
    this.licenseExpiry,
    this.licenseImageBase64,
    this.panNumber,
    this.panImageBase64,
    this.aadhaarNumber,
    this.aadhaarImageBase64,
  });

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _accountHolderNameController;
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _upiIdController = TextEditingController();

  static const Color primaryGreen = Color(0xFF248C70);

  @override
  void initState() {
    super.initState();
    _accountHolderNameController = TextEditingController(text: widget.name ?? '');
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState!.validate()) {
      if (widget.phone != null && widget.phone!.isNotEmpty) {
        await AuthService.registerPhone(widget.phone!);
      }

      final payload = {
        'name': widget.name,
        'email': widget.email,
        'phone': widget.phone,
        'mobile': widget.phone,
        'pin': widget.pin,
        'profilePic': widget.profileImageBase64 != null ? 'data:image/jpeg;base64,${widget.profileImageBase64}' : null,
        'vehicle': {
          'type': widget.vehicleType ?? 'Scooter / Motorcycle',
          'brand': widget.vehicleBrand ?? '',
          'model': widget.vehicleModel ?? '',
          'year': widget.vehicleYear ?? '',
          'number': widget.regNumber ?? '',
          'regNumber': widget.regNumber ?? '',
        },
        'documents': {
          'license': {
            'number': widget.licenseNumber ?? '',
            'expiryDate': widget.licenseExpiry ?? '',
            'image': widget.licenseImageBase64 != null ? 'data:image/jpeg;base64,${widget.licenseImageBase64}' : null,
            'frontImage': widget.licenseImageBase64 != null ? 'data:image/jpeg;base64,${widget.licenseImageBase64}' : null,
          },
          'panCard': {
            'number': widget.panNumber ?? '',
            'image': widget.panImageBase64 != null ? 'data:image/jpeg;base64,${widget.panImageBase64}' : null,
          },
          'aadharCard': {
            'number': widget.aadhaarNumber ?? '',
            'image': widget.aadhaarImageBase64 != null ? 'data:image/jpeg;base64,${widget.aadhaarImageBase64}' : null,
            'frontImage': widget.aadhaarImageBase64 != null ? 'data:image/jpeg;base64,${widget.aadhaarImageBase64}' : null,
          },
          'rc': {
            'number': widget.regNumber ?? '',
          }
        },
        'bankDetails': {
          'accountHolderName': _accountHolderNameController.text.trim(),
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'ifscCode': _ifscCodeController.text.trim(),
          'upiId': _upiIdController.text.trim(),
        },
      };
      final onboardingRes = await ApiService.completeRiderOnboarding(payload);
      final responseData = onboardingRes['data'] is Map ? onboardingRes['data'] : onboardingRes;
      final existingToken = await AuthService.getToken();
      final freshToken = responseData?['token']?.toString() ??
          responseData?['authToken']?.toString() ??
          existingToken ??
          '';

      final phone = widget.phone ?? '';
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
      final newUser = UserModel(
        id: responseData?['user']?['_id']?.toString() ??
            'RIDER_${cleanPhone.isNotEmpty ? cleanPhone : DateTime.now().millisecondsSinceEpoch}',
        phone: cleanPhone.isNotEmpty ? '+91$cleanPhone' : '+919876543210',
        name: widget.name ?? 'Rider Partner',
        email: widget.email,
        role: 'driver',
        isVerified: false, // Pending admin verification
        hasPinSet: widget.pin != null && widget.pin!.isNotEmpty,
        isOnline: false,
        isReturning: false,
        upi: _upiIdController.text.trim(),
        createdAt: DateTime.now(),
      );

      if (freshToken.isNotEmpty) {
        await AuthService.saveTokens(
          freshToken,
          freshToken,
          cleanPhone.isNotEmpty ? cleanPhone : '9876543210',
          hasPin: widget.pin != null && widget.pin!.isNotEmpty,
        );
      }
      if (cleanPhone.isNotEmpty) {
        await AuthService.registerPhone(cleanPhone);
      }

      if (!mounted) return;

      context.read<AuthBloc>().add(UpdateUserData(user: newUser));

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 65,
                height: 65,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 45),
              ),
              const SizedBox(height: 18),
              Text(
                'Registration Completed!',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your vehicle, documents, and bank payout details have been submitted successfully. You are now ready to start delivering!',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Go to Home', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with Step indicator and banner
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'bank_header.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/bank_header.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'docs_header.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF0FDF4),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Back Button
                Positioned(
                  top: 10,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E1E1E), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                // Step (3) Badge
                Positioned(
                  top: 16,
                  right: 24,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '3',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                // Title and Progress Bar
                Positioned(
                  bottom: 12,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Details',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 3-Step Progress Bar (All 3 active)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Payout Information Notice
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, color: primaryGreen, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Earnings, bonuses, and tips will be directly credited to this account.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF1E1E1E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Account Holder Name
                      _buildTextField(
                        label: 'Account Holder Name',
                        controller: _accountHolderNameController,
                        hint: 'Enter account holder name',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter account holder name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Bank Name
                      _buildTextField(
                        label: 'Bank Name',
                        controller: _bankNameController,
                        hint: 'Enter bank name (e.g. HDFC, SBI, ICICI)',
                        icon: Icons.account_balance_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter bank name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3. Account Number (replaces IBAN)
                      _buildTextField(
                        label: 'Account Number',
                        controller: _accountNumberController,
                        hint: 'Enter bank account number',
                        icon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter account number';
                          }
                          if (value.trim().length < 8) {
                            return 'Please enter a valid account number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 4. IFSC Code (replaces BIC / Swift Code)
                      _buildTextField(
                        label: 'IFSC Code',
                        controller: _ifscCodeController,
                        hint: 'Enter 11-digit IFSC code (e.g. HDFC0001234)',
                        icon: Icons.pin_outlined,
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter IFSC code';
                          }
                          if (value.trim().length < 8) {
                            return 'Please enter a valid IFSC code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. UPI ID (Optional)
                      _buildTextField(
                        label: 'UPI ID (Optional)',
                        controller: _upiIdController,
                        hint: 'e.g. name@okhdfcbank or 9876543210@paytm',
                        icon: Icons.payments_outlined,
                        isOptional: true,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          // Optional field - no validation required if empty
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Submit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: primaryGreen.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C2C2C),
              ),
            ),
            if (isOptional) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Optional',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF2C2C2C),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: primaryGreen, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }
}
