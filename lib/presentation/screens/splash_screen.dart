import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vegbox_driver_app/presentation/screens/auth/login_screen.dart';
import 'package:vegbox_driver_app/presentation/screens/auth/documentation_screen.dart';
import 'package:vegbox_driver_app/presentation/screens/home/driver_home_screen.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  bool _animationCompleted = false;
  AuthState? _pendingState;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _animationCompleted = true;
            _navigateIfReady();
          }
        });
      }
    });

    _animationController.forward();

    // Check authentication status
    context.read<AuthBloc>().add(const CheckAuthStatus());
  }

  void _navigateIfReady() {
    if (_animationCompleted && _pendingState != null) {
      if (_pendingState is Authenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      } else if (_pendingState is Unauthenticated || _pendingState is AuthError) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _pendingState = state;
        _navigateIfReady();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Pulse
                            Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.4),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF22C55E).withOpacity(0.1),
                                ),
                              ),
                            ),
                            // Inner Pulse
                            Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.2),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF22C55E).withOpacity(0.2),
                                ),
                              ),
                            ),
                            // Main Logo Container
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withOpacity(0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: Image.asset(
                                'splash_logo.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.delivery_dining_rounded,
                                  size: 120,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 50),
                  SlideTransition(
                    position: _textSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'ECDKART RIDER',
                            style: GoogleFonts.poppins(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1C1C1E),
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Delivering Freshness',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF22C55E),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 60),
                          _DotLoadingIndicator(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DotLoadingIndicator extends StatefulWidget {
  @override
  _DotLoadingIndicatorState createState() => _DotLoadingIndicatorState();
}

class _DotLoadingIndicatorState extends State<_DotLoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate a sine wave based offset for each dot to make it bounce
        final double offset = (index * 0.2);
        final double t = (_controller.value - offset) % 1.0;
        final double y = (math.sin(t * math.pi * 2) * -8.0).clamp(-8.0, 8.0); // bounce height

        return Transform.translate(
          offset: Offset(0, y < 0 ? y : 0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24, // Give it some height for the bounce
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDot(0, const Color(0xFF22C55E)), // Green
          _buildDot(1, Colors.orange), // Orange
          _buildDot(2, const Color(0xFF22C55E)), // Green
        ],
      ),
    );
  }
}
