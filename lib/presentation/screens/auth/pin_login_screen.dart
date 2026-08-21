import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../home/driver_home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class PinLoginScreen extends StatefulWidget {
  final String? phone; // Make it optional

  const PinLoginScreen({super.key, this.phone});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.phone != null) {
      _phoneController.text = widget.phone!;
    }
  }

  void _loginWithPin() {
    if (_formKey.currentState!.validate() && _pinController.text.length == 4) {
      context.read<AuthBloc>().add(
            LoginWithPinRequested(
              phone: _phoneController.text.trim(),
              pin: _pinController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 54,
      height: 54,
      textStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1C1C1E),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        border: Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
              (route) => false,
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _pinController.clear();
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
              child: Stack(
                children: [
                  Column(
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
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                              const SizedBox(height: 8),
                              
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
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    counterText: '',
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              Text(
                                'Security PIN',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // PIN Input
                              Center(
                                child: Pinput(
                                  controller: _pinController,
                                  length: 4,
                                  obscureText: true,
                                  defaultPinTheme: defaultPinTheme,
                                  focusedPinTheme: defaultPinTheme.copyWith(
                                    decoration: defaultPinTheme.decoration!.copyWith(
                                      border: Border.all(color: const Color(0xFF22C55E), width: 2),
                                    ),
                                  ),
                                  onCompleted: (_) => _loginWithPin(),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Login Button
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _loginWithPin,
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
                                              'Login Now',
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
                              
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
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
                                        'Use OTP Instead',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
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
    _pinController.dispose();
    super.dispose();
  }
}
