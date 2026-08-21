import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/auth_service.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../../widgets/custom_button.dart';
import 'otp_screen.dart';
import 'pin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isCheckingPin = true;
  bool _hasPin = false;
  String? _savedPhone;

  @override
  void initState() {
    super.initState();
    _checkForSavedCredentials();
  }

  Future<void> _checkForSavedCredentials() async {
    final phone = await AuthService.getUserPhone();
    final hasPin = await AuthService.hasPin();

    // ✅ ADD THIS DEBUG CODE
    final prefs = await SharedPreferences.getInstance();
    print("🔍 LOGIN SCREEN - Checking saved data:");
    print("   Phone: $phone");
    print("   Has PIN: $hasPin");
    print("   All keys in storage: ${prefs.getKeys()}");
    print(
      "   access_token: ${prefs.getString('access_token')?.substring(0, 20)}...",
    );
    print("   user_phone: ${prefs.getString('user_phone')}");
    print("   has_pin (raw): ${prefs.getBool('has_pin')}");

    setState(() {
      _isCheckingPin = false;
      _hasPin = hasPin;
      _savedPhone = phone;
      if (phone != null) {
        _phoneController.text = phone.replaceAll('+91', '');
      }
    });

    print("🎯 UI State after update:");
    print("   _hasPin: $_hasPin");
    print("   _savedPhone: $_savedPhone");
    print("   Should show PIN button: ${_hasPin && _savedPhone != null}");
    print("════════════════════════════════════════\n");
  }

  void _sendOtp() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      context.read<AuthBloc>().add(SendOtpRequested(phone: phone));
    }
  }

  void _navigateToPinLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinLoginScreen(phone: _phoneController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPin) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))));
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white, 
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpSent) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => OtpScreen(phone: state.phone)),
            );
          } else if (state is UserExistsLoginRequired) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF22C55E),
              ),
            );
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PinLoginScreen(phone: state.phone)),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Stack(
          children: [
            // Top Half Green Background (Extended and Animated)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF22C55E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: List.generate(4, (index) {
                    final double topOffset = index == 0 ? 40 : index == 1 ? 120 : index == 2 ? 60 : 180;
                    final double leftOffset = index == 0 ? 30 : index == 1 ? 250 : index == 2 ? 180 : 80;
                    return Positioned(
                      top: topOffset,
                      left: leftOffset,
                      child: Opacity(
                        opacity: 0.08,
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 90,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // Top Section (Logo and Text)
                  // Top Section (Logo and Text)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isKeyboardOpen 
                        ? MediaQuery.of(context).size.height * 0.15 
                        : MediaQuery.of(context).size.height * 0.45 - MediaQuery.of(context).padding.top,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isKeyboardOpen ? 40 : 70,
                          height: isKeyboardOpen ? 40 : 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(isKeyboardOpen ? 12 : 20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isKeyboardOpen ? 12 : 20),
                            child: Image.asset(
                              'splash_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.delivery_dining_rounded,
                                size: isKeyboardOpen ? 24 : 40,
                                color: const Color(0xFF22C55E),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isKeyboardOpen ? 8 : 16),
                        
                        // Title
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: GoogleFonts.poppins(
                            fontSize: isKeyboardOpen ? 16 : 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2.5,
                          ),
                          child: const Text('ECDKART RIDER'),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom White Card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -5),
                          )
                        ]
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Back Text
                              Center(
                                child: Text(
                                  'Welcome back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1C1C1E),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              Text(
                                'Phone Number',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              
                              // Phone Input
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.transparent),
                                ),
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.w600, 
                                    letterSpacing: 2.0,
                                    color: const Color(0xFF1C1C1E),
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_android_rounded, color: Color(0xFF22C55E), size: 22),
                                          const SizedBox(width: 12),
                                          Text(
                                            '+91',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600, 
                                              color: const Color(0xFF1C1C1E), 
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(width: 1, height: 24, color: Colors.grey[300]),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                    hintText: 'Enter your number',
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey[400], 
                                      fontWeight: FontWeight.w500, 
                                      letterSpacing: 0,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    counterText: '',
                                  ),
                                  validator: Validators.validatePhone,
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Main Button
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _sendOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF111827),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: state is AuthLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              'Get Started',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                              
                              // Secondary Button
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final phone = _phoneController.text.trim();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => PinLoginScreen(phone: phone),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF111827),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: const BorderSide(color: Color(0xFF111827), width: 1.5),
                                        ),
                                      ),
                                      child: Text(
                                        'I have an account',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Footer
                              Center(
                                child: Text(
                                  'ECDKART Partner App v1.0',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
