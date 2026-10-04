import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/user_models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../../../logic/blocs/driver/driver_bloc.dart';
import '../../../logic/blocs/driver/driver_event.dart';
import '../../../logic/blocs/driver/driver_state.dart';
import '../../../data/services/location_service.dart';
import '../auth/rider_relogin_screen.dart';
import '../auth/profile_screen.dart';
import '../onboarding_screen.dart';
import '../order/order_tracking_screen.dart';
import '../wallet/rider_wallet_screen.dart';
import 'widgets/notifications_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _isReturning = false;
  bool _isTrackingLocation = false;
  bool _showIncomingOrder = false;
  bool _celebrationDialogShown = false;
  final Set<String> _processedOrders = {};

  late AnimationController _timerController;
  Timer? _pollingTimer;
  StreamSubscription? _notificationSub;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRingtonePlaying = false;

  // ECD Kart brand colors
  static const Color primaryGreen = Color(0xFF248C70);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color darkBlack = Color(0xFF1E2022);

  @override
  void initState() {
    super.initState();
    _initializeDriverStatus();
    _checkLocationPermission();

    // Initialize Push Notifications (FCM) & In-App notification listener
    NotificationService.initialize();
    _notificationSub = NotificationService.onNotificationReceived.listen((payload) {
      if (!mounted) return;
      final title = payload['title'] ?? 'Notification';
      final body = payload['body'] ?? '';
      final type = payload['type'] ?? '';
      final isApproval = type == 'RIDER_VERIFIED' ||
          title.toLowerCase().contains('rider approved') ||
          (title.toLowerCase().contains('approved') && !title.toLowerCase().contains('payment') && !title.toLowerCase().contains('payout') && !title.toLowerCase().contains('withdrawal'));

      if (isApproval) {
        context.read<AuthBloc>().add(const CheckAuthStatus());
        _showApprovalCelebrationDialog(title, body);
      } else {
        if (type == 'dispatch_request' || type == 'order_available' || title.toLowerCase().contains('delivery request') || title.toLowerCase().contains('order')) {
          context.read<DriverBloc>().add(const LoadActiveOrders());
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  type == 'PAYOUT_APPROVED' ? Icons.account_balance_wallet_rounded : Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    body.isNotEmpty ? body : title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: type == 'PAYOUT_REJECTED' ? Colors.redAccent : primaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && _showIncomingOrder) {
          _stopOrderRingtone();
          final state = context.read<DriverBloc>().state;
          final activeOrder = state.orders.isNotEmpty ? state.orders.first : null;
          if (activeOrder != null && activeOrder['deliveryStatus'] == 'driver_notified') {
             final String? orderId = activeOrder['_id'];
             final String updatedAt = activeOrder['updatedAt'] ?? '';
             if (orderId != null) {
               _processedOrders.add('${orderId}_$updatedAt');
               context.read<DriverBloc>().add(DeclineOrder(orderId: orderId));
             }
          }
          setState(() => _showIncomingOrder = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order Expired - Time Out'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverBloc>().add(const LoadActiveOrders());
      NotificationService.syncWithdrawalNotifications();
      _startPollingActiveOrders();
    });
  }

  void _startPollingActiveOrders() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && _isOnline) {
        context.read<DriverBloc>().add(const LoadActiveOrders(isSilent: true));
      }
    });
  }

  void _showApprovalCelebrationDialog(String title, String body) {
    if (_celebrationDialogShown) return;
    _celebrationDialogShown = true;

    final notifTitle = title.isNotEmpty ? title : 'Profile Approved! 🎉';
    final notifBody = body.isNotEmpty
        ? body
        : 'Congratulations! Your rider profile has been verified and approved by Admin. You can now go online and start accepting orders.';

    // Save notification to bell icon list
    NotificationService.addNotification(
      title: notifTitle,
      body: notifBody,
      type: 'APPROVAL',
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: primaryGreen, size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'Profile Approved! 🎉',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          notifBody,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700], height: 1.4),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Start Earning', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _initializeDriverStatus() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final isVerified = authState.user.isVerified;
      setState(() {
        _isOnline = isVerified ? authState.user.isOnline : false;
        _isReturning = authState.user.isReturning;
      });
      if (isVerified) {
        NotificationService.addNotification(
          title: 'Profile Approved! 🎉',
          body: 'Congratulations! Your rider profile has been verified and approved by Admin. You can now go online and start accepting orders.',
          type: 'APPROVAL',
        );
      }
    } else if (authState is AuthInitial) {
      context.read<AuthBloc>().add(const CheckAuthStatus());
    }
  }

  Future<void> _checkLocationPermission() async {
    final hasPermission = await LocationService.hasLocationPermission();
    if (!hasPermission && mounted) {
      _showLocationPermissionDialog();
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: primaryGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location Required',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Enable location to receive and deliver orders. Your location helps us assign nearby orders.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await LocationService.requestLocationPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text('Enable', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOnlineStatus() async {
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
                  'Your profile is under review by Admin. You can go online once approved.',
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

    final user = authState.user;
    final newStatus = !_isOnline;

    if (newStatus) {
      final hasPermission = await LocationService.hasLocationPermission();
      if (!hasPermission) {
        _showLocationPermissionDialog();
        return;
      }
      await _startLocationTracking();
    } else {
      await _stopLocationTracking();
    }

    if (!mounted) return;
    context.read<DriverBloc>().add(
      ToggleOnlineStatus(
        isOnline: newStatus, 
        currentUser: user,
      ),
    );
    
    // Auto-refresh orders when going online
    if (newStatus) {
      context.read<DriverBloc>().add(const LoadActiveOrders());
      _startPollingActiveOrders();
    } else {
      _pollingTimer?.cancel();
    }
  }

  Future<void> _startLocationTracking() async {
    await LocationService.startLocationUpdates(
      onLocationUpdate: (Position position) {
        context.read<DriverBloc>().add(
          UpdateDriverLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            heading: position.heading,
          ),
        );
      },
    );
    if (mounted) setState(() => _isTrackingLocation = true);
  }

  Future<void> _stopLocationTracking() async {
    await LocationService.stopLocationUpdates();
    if (mounted) setState(() => _isTrackingLocation = false);
  }

  void _markReachedStore() {
    final authState = context.read<AuthBloc>().state;
    UserModel? user;
    if (authState is Authenticated) {
      user = authState.user;
    }
    context.read<DriverBloc>().add(MarkReachedStore(currentUser: user));
  }

  void _playOrderRingtone() async {
    try {
      if (_isRingtonePlaying) return;
      _isRingtonePlaying = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('ordertone.mpeg'));
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _stopOrderRingtone() async {
    try {
      _isRingtonePlaying = false;
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  @override
  void dispose() {
    _stopOrderRingtone();
    _notificationSub?.cancel();
    _stopLocationTracking();
    _timerController.dispose();
    _pollingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is Unauthenticated) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RiderReloginScreen()),
                (route) => false,
              );
            } else if (state is Authenticated) {
              setState(() {
                _isOnline = state.user.isVerified ? state.user.isOnline : false;
                _isReturning = state.user.isReturning;
              });

              if (state.user.isVerified && !_celebrationDialogShown) {
                _showApprovalCelebrationDialog(
                  'Profile Approved! 🎉',
                  'Congratulations! Your rider profile has been verified and approved by Admin. You can now go online and start accepting orders.',
                );
              }
            }
          },
        ),
        BlocListener<DriverBloc, DriverState>(
          listener: (context, state) {
            if (state is OnlineStatusUpdated) {
              _stopOrderRingtone();
              final authState = context.read<AuthBloc>().state;
              final isVerified = authState is Authenticated && authState.user.isVerified;
              setState(() => _isOnline = isVerified ? state.isOnline : false);

              // Update AuthBloc with new user data
              if (state.updatedUser != null) {
                context.read<AuthBloc>().add(
                  UpdateUserData(user: state.updatedUser!),
                );
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        state.isOnline
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_filled_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  backgroundColor: state.isOnline
                      ? primaryGreen
                      : darkBlack,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else if (state is ReachedStoreConfirmed) {
              setState(() => _isReturning = false);

              if (state.updatedUser != null) {
                context.read<AuthBloc>().add(
                  UpdateUserData(user: state.updatedUser!),
                );
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  backgroundColor: primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else if (state is DriverError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontSize: 12))),
                    ],
                  ),
                  backgroundColor: Colors.red[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else if (state is ActiveOrdersLoaded) {
              if (state.orders.isNotEmpty) {
                final incomingIndex = state.orders.indexWhere((o) => o['deliveryStatus'] == 'driver_notified');
                final activeOrder = incomingIndex != -1 ? state.orders[incomingIndex] : state.orders.first;
                final processKey = '${activeOrder['_id']}_${activeOrder['updatedAt'] ?? ''}';
                if (activeOrder['deliveryStatus'] == 'driver_notified' && !_showIncomingOrder && !_processedOrders.contains(processKey)) {
                  setState(() => _showIncomingOrder = true);
                  _playOrderRingtone();
                  _timerController.reset();
                  _timerController.forward();
                } else if (incomingIndex == -1 || _processedOrders.contains(processKey)) {
                  if (_showIncomingOrder || _isRingtonePlaying) {
                    _stopOrderRingtone();
                    setState(() => _showIncomingOrder = false);
                  }
                }
              } else {
                if (_showIncomingOrder || _isRingtonePlaying) {
                  _stopOrderRingtone();
                  setState(() => _showIncomingOrder = false);
                }
              }
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! Authenticated) {
              if (authState is Unauthenticated || authState is AuthError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RiderReloginScreen()),
                      (route) => false,
                    );
                  }
                });
              } else if (authState is AuthInitial) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.read<AuthBloc>().add(const CheckAuthStatus());
                  }
                });
              }
              return const Center(child: CircularProgressIndicator(color: primaryGreen));
            }

            return Stack(
              children: [
                RefreshIndicator(
                  color: primaryGreen,
                  onRefresh: () async {
                    context.read<DriverBloc>().add(const LoadActiveOrders());
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Frosted Header Banner with Generated Rider Image
                        _buildRiderHeaderBanner(authState.user),

                        const SizedBox(height: 14),

                        // Profile Card
                        _buildProfileSection(authState.user),

                        const SizedBox(height: 14),

                        // Go Online / Offline Action Button
                        _buildActionButtons(),

                        const SizedBox(height: 14),

                        // Location & Status Stats Cards
                        _buildStatsCards(),

                        const SizedBox(height: 14),

                        // Today Progress Section
                        _buildTodayProgressSection(),

                        const SizedBox(height: 18),

                        // Orders Section (Active, Complete, Cancel tabs)
                        _buildOrdersSection(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                
                // Incoming Order Popup (Simulated)
                if (_showIncomingOrder)
                  _buildIncomingOrderPopup(),
              ],
            );
          },
        ),
      ),
    );
  }

  // Clear & Premium Header Banner with Rider Hero Image
  Widget _buildRiderHeaderBanner(dynamic user) {
    return SizedBox(
      width: double.infinity,
      height: 230,
      child: Stack(
        children: [
          // Crisp Background Rider Hero Image (No aggressive blur!)
          Positioned.fill(
            child: Image.asset(
              'rider_partner_hero.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.15, -0.15),
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/rider_partner_hero.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0.15, -0.15),
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'rider_hero_header.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.15, -0.15),
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/rider_hero_header.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: primaryGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Subtle Top & Bottom Gradient to ensure text contrast while keeping rider 100% visible
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.60),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.30),
                    const Color(0xFFF8F9FA),
                  ],
                  stops: const [0.0, 0.30, 0.70, 0.88, 1.0],
                ),
              ),
            ),
          ),

          // Header Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Brand capsule + Status Pill + Notification
                  Row(
                    children: [
                      // Brand Pill Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'splash_logo.png',
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/splash_logo.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.delivery_dining_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ECD KART',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'RIDER PARTNER',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFF70E000),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Online / Offline Status Badge
                      GestureDetector(
                        onTap: _toggleOnlineStatus,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: !user.isVerified
                                ? primaryGreen
                                : (_isOnline ? primaryGreen : Colors.redAccent.withOpacity(0.95)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: (!user.isVerified
                                        ? primaryGreen
                                        : (_isOnline ? primaryGreen : Colors.redAccent))
                                    .withOpacity(0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                !user.isVerified
                                    ? 'PENDING'
                                    : (_isOnline ? 'ONLINE' : 'OFFLINE'),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Notifications Button with Live Badge
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationService.unreadCountNotifier,
                        builder: (context, unreadCount, _) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                                    color: unreadCount > 0 ? const Color(0xFFFBBF24) : Colors.white,
                                    size: 20,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    NotificationsSheet.show(context);
                                  },
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red[600],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  // Bottom Welcome Floating Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Text(
                                  'Hello, ${(user.name != null && user.name.toString().trim().isNotEmpty && user.name.toString().trim() != 'Rider Partner') ? user.name : (user.phone.isNotEmpty ? user.phone : 'Rider Partner')} 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !user.isVerified
                                    ? '⏳ Profile under review. Waiting for admin approval.'
                                    : (_isOnline
                                        ? '🟢 You are online & ready to receive orders'
                                        : '🔴 You are offline. Tap Go Online to start'),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: !user.isVerified
                                      ? const Color(0xFFFFB703)
                                      : (_isOnline ? const Color(0xFF9EF01A) : Colors.white70),
                                  fontWeight: FontWeight.w500,
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
            ),
          ),
        ],
      ),
    );
  }

  String _parseAddressToString(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is List) {
      if (raw.isEmpty) return '';
      return _parseAddressToString(raw.first);
    }
    if (raw is Map) {
      final line = raw['fullAddress'] ?? raw['address'] ?? raw['addressLine'] ?? raw['street'] ?? '';
      final city = raw['city'] ?? raw['cityName'] ?? '';
      final lineStr = _parseAddressToString(line);
      final cityStr = _parseAddressToString(city);
      if (lineStr.isNotEmpty) {
        if (cityStr.isNotEmpty && !lineStr.toLowerCase().contains(cityStr.toLowerCase())) {
          return "$lineStr, $cityStr";
        }
        return lineStr;
      }
      if (cityStr.isNotEmpty) return cityStr;
    }
    return raw.toString();
  }

  Widget _buildIncomingOrderPopup() {
    return BlocBuilder<DriverBloc, DriverState>(
      builder: (context, state) {
        final incomingIndex = state.orders.indexWhere((o) => o['deliveryStatus'] == 'driver_notified');
        final activeOrder = incomingIndex != -1 ? state.orders[incomingIndex] : (state.orders.isNotEmpty ? state.orders.first : null);
        if (activeOrder == null) return const SizedBox.shrink();

        final storeName = activeOrder['store']?['name'] ?? activeOrder['restaurant']?['name'] ?? 'FreshNow Store';
        final rawStoreAddr = _parseAddressToString(activeOrder['store']?['address'] ?? activeOrder['restaurant']?['address']);
        final storeAddress = rawStoreAddr.isNotEmpty ? rawStoreAddr : 'Store Location';

        final rawDeliveryAddr = _parseAddressToString(
          activeOrder['deliveryAddress'] ?? activeOrder['address'] ?? activeOrder['customer']?['address']
        );
        final deliveryAddress = rawDeliveryAddr.isNotEmpty ? rawDeliveryAddr : 'Customer Location';
        final earnings = (activeOrder['driverEarnings'] ?? activeOrder['deliveryCharge'] ?? 50.0).toStringAsFixed(2);
        final orderAmount = (activeOrder['payableAmount'] ?? activeOrder['totalAmount'] ?? 0.0).toStringAsFixed(2);
        final customerName = activeOrder['customer']?['name'] ?? 'Customer';
        final paymentMode = (activeOrder['paymentTransaction'] != null && (activeOrder['paymentTransaction']['provider'] == 'cod' || activeOrder['paymentTransaction']['provider'] == 'Cash on Delivery')) || activeOrder['paymentMethod'] == 'Cash on Delivery' || activeOrder['paymentMethod'] == 'COD' ? 'Cash on Delivery' : 'Online / UPI';

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    // Square Progress Action Box
                    AnimatedBuilder(
                      animation: _timerController,
                      builder: (context, child) {
                        return Container(
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _timerController.value > 0.8 
                                ? Colors.red.withOpacity(0.05) 
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: BorderProgressPainter(
                              progress: 1.0 - _timerController.value,
                              color: _timerController.value > 0.8 ? Colors.red : primaryGreen,
                              strokeWidth: 4,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    child: Text(
                                      "NEW ORDER REQUEST",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        color: _timerController.value > 0.8 ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Expires in ${(15 * (1.0 - _timerController.value)).ceil()}s",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "New Delivery Request!",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildPopupInfoRow(
                  icon: Icons.storefront,
                  color: primaryGreen,
                  title: storeName,
                  subtitle: storeAddress,
                  onTrack: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          order: activeOrder,
                          isToRestaurant: true,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      context.read<DriverBloc>().add(const LoadActiveOrders());
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Delivery Info
                _buildPopupInfoRow(
                  icon: Icons.location_on,
                  color: primaryGreen,
                  title: customerName,
                  subtitle: deliveryAddress,
                  onTrack: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          order: activeOrder,
                          isToRestaurant: false,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      context.read<DriverBloc>().add(const LoadActiveOrders());
                    }
                  },
                ),
                const SizedBox(height: 20),
                
                const Divider(),
                const SizedBox(height: 12),
                
                // Amounts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Order Amount:",
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                        ),
                        Row(
                          children: [
                            Text(
                              "₹$orderAmount",
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: paymentMode == 'Cash on Delivery' ? Colors.green[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: paymentMode == 'Cash on Delivery' ? Colors.green[200]! : Colors.blue[200]!),
                              ),
                              child: Text(
                                paymentMode,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: paymentMode == 'Cash on Delivery' ? Colors.green[800] : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Your Earnings:",
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                        ),
                        Text(
                          "₹$earnings",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Explicit ACCEPT and REJECT Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _stopOrderRingtone();
                          final String? orderId = activeOrder['_id'];
                          final String updatedAt = activeOrder['updatedAt'] ?? '';
                          if (orderId != null) {
                            _processedOrders.add('${orderId}_$updatedAt');
                            context.read<DriverBloc>().add(DeclineOrder(orderId: orderId));
                          }
                          _timerController.stop();
                          setState(() => _showIncomingOrder = false);
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        label: Text("REJECT", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _stopOrderRingtone();
                          final String? orderId = activeOrder['_id'];
                          final String updatedAt = activeOrder['updatedAt'] ?? '';
                          if (orderId != null) {
                            _processedOrders.add('${orderId}_$updatedAt');
                            context.read<DriverBloc>().add(AcceptOrder(orderId: orderId));
                          }
                          _timerController.stop();
                          setState(() => _showIncomingOrder = false);
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        label: Text("ACCEPT", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Slide to Accept Interaction
                _buildSlideAction(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTrack,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        if (onTrack != null)
          TextButton(
            onPressed: onTrack,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Track", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSlideAction() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Center(
            child: FittedBox(
              child: Text(
                "Slide Right: Accept | Left: Deny",
                style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          Dismissible(
            key: const Key('slide_to_accept'),
            confirmDismiss: (direction) async {
              final state = context.read<DriverBloc>().state;
              final activeOrder = state.orders.isNotEmpty ? state.orders.first : null;
              final String? orderId = activeOrder?['_id'];
              final String updatedAt = activeOrder?['updatedAt'] ?? '';
              final processKey = orderId != null ? '${orderId}_$updatedAt' : null;

              if (direction == DismissDirection.startToEnd) {
                // Accept
                _stopOrderRingtone();
                if (orderId != null) {
                  _processedOrders.add(processKey!);
                  context.read<DriverBloc>().add(AcceptOrder(orderId: orderId));
                }
                _timerController.stop();
                setState(() => _showIncomingOrder = false);
                return true;
              } else if (direction == DismissDirection.endToStart) {
                // Deny
                _stopOrderRingtone();
                if (orderId != null) {
                  _processedOrders.add(processKey!);
                  context.read<DriverBloc>().add(DeclineOrder(orderId: orderId));
                }
                _timerController.stop();
                setState(() => _showIncomingOrder = false);
                return true;
              }
              return false;
            },
            child: Container(
              height: 60,
              width: 100,
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 0)),
                ],
              ),
              child: const Icon(Icons.keyboard_double_arrow_right, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(dynamic user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryGreen.withOpacity(0.2)),
                image: user.avatar != null && user.avatar!.isNotEmpty
                    ? DecorationImage(
                        image: (user.avatar!.startsWith('http') || kIsWeb)
                            ? NetworkImage(user.avatar!)
                            : FileImage(File(user.avatar!)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user.avatar == null || user.avatar!.isEmpty
                  ? const Icon(Icons.person_rounded, size: 28, color: primaryGreen)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user.name != null && user.name.toString().trim().isNotEmpty && user.name.toString().trim() != 'Rider Partner') ? user.name! : (user.phone.isNotEmpty ? user.phone : 'Rider Partner'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        user.phone ?? '',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (user.upi != null && user.upi!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 13, color: primaryGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'UPI: ${user.upi}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    user.riderId ?? 'RIDER',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: user.isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: user.isVerified ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.isVerified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                        size: 11,
                        color: user.isVerified ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        user.isVerified ? 'Verified' : 'Pending',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: user.isVerified ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final authState = context.watch<AuthBloc>().state;
    final isVerified = authState is Authenticated && authState.user.isVerified;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          BlocBuilder<DriverBloc, DriverState>(
            builder: (context, state) {
              final isLoading = state is DriverLoading;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _toggleOnlineStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !isVerified
                        ? primaryGreen
                        : (_isOnline ? primaryGreen : darkBlack),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: (!isVerified
                            ? primaryGreen
                            : (_isOnline ? primaryGreen : darkBlack))
                        .withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !isVerified
                                  ? Icons.lock_clock_rounded
                                  : (_isOnline
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded),
                              size: 22,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              !isVerified
                                  ? 'Approval Pending (Locked)'
                                  : (_isOnline ? 'Go Offline' : 'Go Online'),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white,
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
    );
  }

  Widget _buildStatsCards() {
    final authState = context.watch<AuthBloc>().state;
    final isVerified = authState is Authenticated && authState.user.isVerified;

    String statusText;
    Color statusColor;
    Color statusBgColor;

    if (!isVerified) {
      statusText = 'Pending';
      statusColor = primaryGreen;
      statusBgColor = lightGreen;
    } else if (_isOnline) {
      statusText = 'Available';
      statusColor = primaryGreen;
      statusBgColor = lightGreen;
    } else {
      statusText = 'Offline';
      statusColor = Colors.grey[700]!;
      statusBgColor = Colors.grey[100]!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.location_on_outlined,
              title: 'Location',
              value: _isTrackingLocation ? 'Tracking' : 'Not Tracking',
              color: _isTrackingLocation ? primaryGreen : Colors.grey,
              bgColor: _isTrackingLocation ? lightGreen : Colors.grey[100]!,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.assignment_outlined,
              title: 'Status',
              value: statusText,
              color: statusColor,
              bgColor: statusBgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgressSection() {
    return BlocBuilder<DriverBloc, DriverState>(
      builder: (context, state) {
        final summary = state.summaryData;
        final earningsVal = summary?['earnings'] ?? 0;
        final ordersVal = summary?['orders_completed'] ?? 0;
        final secondsVal = summary?['ride_time_seconds'] ?? 0;

        final String earnings = '₹${(earningsVal as num).toDouble().toStringAsFixed(2)}';
        final String orders = ordersVal.toString();
        final double hoursVal = (secondsVal as num) / 3600.0;
        final String hours = '${hoursVal.toStringAsFixed(1)}h';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryGreen.withOpacity(0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RiderWalletScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _buildProgressItem(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Earnings',
                        value: earnings,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildProgressItem(
                      icon: Icons.shopping_bag_rounded,
                      label: 'Today Order',
                      value: orders,
                      color: primaryGreen,
                    ),
                  ),
                  Expanded(
                    child: _buildProgressItem(
                      icon: Icons.timer_rounded,
                      label: 'Today Hours',
                      value: hours,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersSection() {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Orders',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                isScrollable: false,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[700],
                indicator: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Complete'),
                  Tab(text: 'Cancel'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          BlocBuilder<DriverBloc, DriverState>(
            builder: (context, state) {
              if (state is DriverLoading && state.orders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                );
              }

              // Show orders if we have them in state (regardless of specific status)
              if (state.orders.isNotEmpty || state.completedOrders.isNotEmpty || state.cancelledOrders.isNotEmpty) {
                final displayActiveOrders = state.orders.where((o) => o['deliveryStatus'] != 'driver_notified').toList();
                return SizedBox(
                  height: 400, // Fixed height for TabBarView
                  child: TabBarView(
                    children: [
                      _buildOrderList(displayActiveOrders, title: 'No active orders'),
                      _buildOrderList(state.completedOrders, isHistorical: true, title: 'No completed orders yet'),
                      _buildOrderList(state.cancelledOrders, isHistorical: true, title: 'No cancelled orders yet'),
                    ],
                  ),
                );
              }

              // Show error if any
              if (state is DriverError) {
                return _buildErrorWidget(state.message);
              }

              // Default: No orders
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildNoOrdersWidget(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrdersWidget({String? title}) {
    final authState = context.read<AuthBloc>().state;
    final isVerified = authState is Authenticated && authState.user.isVerified;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                !isVerified ? Icons.lock_clock_outlined : Icons.inbox_outlined,
                size: 40,
                color: !isVerified ? primaryGreen : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title ?? (!isVerified
                  ? 'Your profile is under review by Admin'
                  : (_isOnline ? 'No active orders right now' : 'Go online to receive nearby orders')),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!_isOnline && title == null) ...[
              const SizedBox(height: 6),
              Text(
                !isVerified
                    ? 'Orders will be available once Admin approves'
                    : 'You are currently offline',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {bool isHistorical = false, String? title}) {
    // Hide active orders if offline
    if (!isHistorical && !_isOnline) {
      return _buildNoOrdersWidget(title: title);
    }

    if (orders.isEmpty) {
      return _buildNoOrdersWidget(title: title);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, isHistorical: isHistorical);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {bool isHistorical = false}) {
    final storeName = order['store']?['name'] ?? order['restaurant']?['name'] ?? 'FreshNow Store';
    final rawCustAddr = _parseAddressToString(
      order['deliveryAddress'] ?? order['address'] ?? order['customer']?['address']
    );
    final customerAddress = rawCustAddr.isNotEmpty ? rawCustAddr : 'Customer Address';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Order #${order['orderNumber'] ?? order['orderId'] ?? order['_id'] ?? 'N/A'}",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(order['deliveryStatus'] ?? 'PENDING'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Restaurant Pick-up and Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storeName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total: ₹${order['payableAmount'] ?? order['totalAmount'] ?? '0.00'}",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "Earn: ₹${(order['driverEarnings'] ?? order['deliveryCharge'] ?? 50.0).toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Address and Tracking
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerAddress,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isHistorical) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final status = order['deliveryStatus'] ?? 'accepted';
                    final isToStore = ['accepted', 'assigned', 'reached_store'].contains(status);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          order: order,
                          isToRestaurant: isToStore,
                        ),
                      ),
                    );
                    if (context.mounted) {
                      context.read<DriverBloc>().add(const LoadActiveOrders());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: const Size(0, 30),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Track",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Footer: Estimate and Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHistorical ? Icons.history : Icons.access_time,
                    size: 16,
                    color: isHistorical ? Colors.grey : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isHistorical ? "Delivered" : "Estimate: 8-15 mins",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: isHistorical ? Colors.grey : Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[200]! : Colors.blue[200]!),
                ),
                child: Text(
                  (order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD' ? 'Cash on Delivery' : 'Online / UPI',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[800] : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'delivered':
      case 'complete':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        break;
      case 'cancelled':
      case 'cancel':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        break;
      default:
        bgColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => context.read<DriverBloc>().add(
              const LoadActiveOrders(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            label: Text("Retry", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class BorderProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  BorderProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    ));

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class InlineDeliveryOtpForm extends StatefulWidget {
  final Map<String, dynamic> order;
  const InlineDeliveryOtpForm({super.key, required this.order});

  @override
  State<InlineDeliveryOtpForm> createState() => _InlineDeliveryOtpFormState();
}

class _InlineDeliveryOtpFormState extends State<InlineDeliveryOtpForm> {
  static const Color primaryGreen = Color(0xFF248C70);
  
  final TextEditingController _otpController = TextEditingController();
  bool _isSendingOtp = false;

  void _sendOtp() async {
    setState(() => _isSendingOtp = true);
    try {
      final response = await ApiService.sendDeliveryOtp(widget.order['_id'] ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'OTP sent successfully'), backgroundColor: primaryGreen),
      );
    } catch (e) {
      if (!mounted) return;
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

