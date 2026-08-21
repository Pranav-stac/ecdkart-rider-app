import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/blocs/auth/auth_bloc.dart';
import '../../../logic/blocs/auth/auth_event.dart';
import '../../../logic/blocs/auth/auth_state.dart';
import '../../../logic/blocs/driver/driver_bloc.dart';
import '../../../logic/blocs/driver/driver_event.dart';
import '../../../logic/blocs/driver/driver_state.dart';
import '../../../data/services/location_service.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';
import '../order/order_details_screen.dart';
import '../order/order_tracking_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final Set<String> _processedOrders = {};

  late AnimationController _timerController;
  Timer? _pollingTimer;

  // Blinkit-style colors
  static const Color primaryGreen = Color(0xFF22C55E);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color darkGreen = Color(0xFF0A5C17);

  @override
  void initState() {
    super.initState();
    _initializeDriverStatus();
    _checkLocationPermission();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && _showIncomingOrder) {
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
      // Poll for active orders every 3 seconds for near real-time order popups
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) {
          context.read<DriverBloc>().add(const LoadActiveOrders(isSilent: true));
        }
      });
    });
  }



  void _initializeDriverStatus() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      setState(() {
        _isOnline = authState.user.isOnline;
        _isReturning = authState.user.isReturning;
      });
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
        title: const Row(
          children: [
            Icon(Icons.location_on, color: primaryGreen, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Location Required')),
          ],
        ),
        content: const Text(
          'ECDKART Rider needs location access to receive and deliver orders. Please tap Enable to allow location access, or tap Open Settings if previously disabled.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final granted = await LocationService.requestLocationPermission();
              if (!granted && mounted) {
                await LocationService.openAppSettingsDirect();
              } else if (granted && mounted) {
                if (!_isOnline) {
                  _toggleOnlineStatus();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Enable / Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOnlineStatus() async {
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

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<DriverBloc>().add(
        ToggleOnlineStatus(
          isOnline: newStatus, 
          currentUser: authState.user,
        ),
      );
      
      // Auto-refresh orders when going online
      if (newStatus) {
        context.read<DriverBloc>().add(const LoadActiveOrders());
      }
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
    context.read<DriverBloc>().add(const MarkReachedStore());
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _timerController.dispose();
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
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
        BlocListener<DriverBloc, DriverState>(
          listener: (context, state) {
            if (state is OnlineStatusUpdated) {
              setState(() => _isOnline = state.isOnline);

              // ✅ Update AuthBloc with new user data
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
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: state.isOnline
                      ? primaryGreen
                      : Colors.orange[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            } else if (state is ReachedStoreConfirmed) {
              setState(() => _isReturning = false);

              // ✅ Update AuthBloc with new user data
              if (state.updatedUser != null) {
                context.read<AuthBloc>().add(
                  UpdateUserData(user: state.updatedUser!),
                );
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.store, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            } else if (state is DriverError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.red[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            } else if (state is ActiveOrdersLoaded) {
              if (state.orders.isNotEmpty) {
                final activeOrder = state.orders.first;
                final processKey = '${activeOrder['_id']}_${activeOrder['updatedAt'] ?? ''}';
                if (activeOrder['deliveryStatus'] == 'driver_notified' && !_showIncomingOrder && !_processedOrders.contains(processKey)) {
                  setState(() => _showIncomingOrder = true);
                  _timerController.reset();
                  _timerController.forward();
                }
              }
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: const Color(0xFF9EF01A),
          foregroundColor: Colors.black,
          elevation: 2,
          shadowColor: Colors.black45,
          titleSpacing: 8,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'splash_logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.local_shipping,
                      color: primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ECD KART',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RIDER',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? const Color(0xFF16A34A) : Colors.redAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.white : Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'ONLINE' : 'OFFLINE',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
            ),
          ],
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! Authenticated) {
              return const Center(child: CircularProgressIndicator());
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
                      children: [
                        _buildProfileSection(authState.user),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                        _buildStatsCards(),
                        const SizedBox(height: 16),
                        _buildTodayProgressSection(),
                        const SizedBox(height: 20),
                        _buildOrdersSection(),
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

  Widget _buildIncomingOrderPopup() {
    return BlocBuilder<DriverBloc, DriverState>(
      builder: (context, state) {
        final activeOrder = state.orders.isNotEmpty ? state.orders.first : null;
        if (activeOrder == null) return const SizedBox.shrink();

        final storeName = activeOrder['store']?['name'] ?? 'Restaurant';
        final storeAddress = (activeOrder['store']?['address'] is String) ? activeOrder['store']['address'] : (activeOrder['store']?['address']?['fullAddress'] ?? 'Store Location');
        final deliveryAddress = (activeOrder['customer']?['address'] is String) ? activeOrder['customer']['address'] : ((activeOrder['address'] is String) ? activeOrder['address'] : (activeOrder['address']?['fullAddress'] ?? 'Customer Location'));
        final earnings = (activeOrder['driverEarnings'] ?? activeOrder['deliveryCharge'] ?? 50.0).toStringAsFixed(2);
        final orderAmount = (activeOrder['payableAmount'] ?? activeOrder['totalAmount'] ?? 0.0).toStringAsFixed(2);
        final customerName = activeOrder['customer']?['name'] ?? 'Customer';
        final orderNumber = activeOrder['orderNumber'] ?? 'Unknown';
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
                                      "ACCEPT ORDER",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        color: _timerController.value > 0.8 ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Assignment expires in ${(15 * (1.0 - _timerController.value)).ceil()}s",
                                    style: TextStyle(
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
                    const Text(
                      "New Delivery Assigned!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildPopupInfoRow(
                  icon: Icons.storefront,
                  color: Colors.orange[700]!,
                  title: storeName,
                  subtitle: storeAddress,
                  onTrack: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          order: activeOrder,
                          isToRestaurant: true,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                
                // Delivery Info
                _buildPopupInfoRow(
                  icon: Icons.location_on,
                  color: primaryGreen,
                  title: customerName,
                  subtitle: deliveryAddress,
                  onTrack: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          order: activeOrder,
                          isToRestaurant: false,
                        ),
                      ),
                    );
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
                        const Text(
                          "Total Order Amount:",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Row(
                          children: [
                            Text(
                              "₹$orderAmount",
                              style: const TextStyle(
                                fontSize: 20,
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
                                style: TextStyle(
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
                        const Text(
                          "Your Earnings:",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          "₹$earnings",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
          const Center(
            child: FittedBox(
              child: Text(
                "Slide Right: Accept | Left: Deny",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                if (orderId != null) {
                  _processedOrders.add(processKey!);
                  context.read<DriverBloc>().add(AcceptOrder(orderId: orderId));
                }
                _timerController.stop();
                setState(() => _showIncomingOrder = false);
                return true;
              } else if (direction == DismissDirection.endToStart) {
                // Deny
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

  Widget _buildProfileSection(user) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
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
                ? Icon(Icons.person, size: 28, color: Colors.grey[400])
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'Driver',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (user.upi != null && user.upi!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payment, size: 14, color: primaryGreen.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'UPI ID: ${user.upi}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.riderId ?? 'DRIVER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          BlocBuilder<DriverBloc, DriverState>(
            builder: (context, state) {
              final isLoading = state is DriverLoading;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _toggleOnlineStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnline
                        ? Colors.orange[700]
                        : const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                              _isOnline
                                  ? Icons.pause_circle
                                  : Icons.play_circle_filled,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOnline ? 'Go Offline' : 'Go Online',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
          if (_isReturning) ...[
            const SizedBox(height: 12),
            BlocBuilder<DriverBloc, DriverState>(
              builder: (context, state) {
                final isLoading = state is DriverLoading;

                return Container(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _markReachedStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                            children: const [
                              Icon(Icons.store_outlined, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'I Reached Store',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
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
              value: _isReturning ? 'Returning' : 'Available',
              color: _isReturning ? Colors.orange[700]! : Colors.blue[600]!,
              bgColor: _isReturning ? Colors.orange[50]! : Colors.blue[50]!,
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

        final String earnings = '₹${earningsVal.toStringAsFixed(2)}';
        final String orders = ordersVal.toString();
        final double hoursVal = secondsVal / 3600.0;
        final String hours = '${hoursVal.toStringAsFixed(1)}h';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: lightGreen.withOpacity(0.5), // More green themed
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryGreen.withOpacity(0.2)),
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
                  const Text(
                    'Today Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildProgressItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Earnings',
                    value: earnings,
                    color: Colors.green,
                  ),
                  _buildProgressItem(
                    icon: Icons.shopping_bag_rounded,
                    label: 'Today Order',
                    value: orders,
                    color: primaryGreen,
                  ),
                  _buildProgressItem(
                    icon: Icons.timer_rounded,
                    label: 'Today Hours',
                    value: hours,
                    color: Colors.orange[700]!,
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
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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
            child: const Text(
              'Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              isScrollable: false,
              labelColor: primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryGreen,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Complete'),
                Tab(text: 'Cancel'),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                padding: const EdgeInsets.only(top: 40),
                child: _buildNoOrdersWidget(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrdersWidget({String? title}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? (_isOnline ? 'No active orders' : 'Go online to receive orders'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!_isOnline && title == null) ...[
              const SizedBox(height: 8),
              const Text(
                'You are currently offline',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 250),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  "Order #${order['orderNumber'] ?? 'N/A'}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Removed QR Code for Payments as requested
              _buildStatusBadge(order['deliveryStatus'] ?? 'PENDING'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Restaurant Pick-up and Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    order['restaurant']?['name'] ?? 'FreshNow Store',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${order['restaurant']?['distance_km'] ?? order['store']?['distance_km'] ?? order['distanceKm'] ?? '--'} km',
                      style: TextStyle(fontSize: 10, color: Colors.orange[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (!isHistorical)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(order: order, isToRestaurant: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 28),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Track Pick-up",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer
          Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                order['customer']?['name'] ?? 'N/A',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Total: ₹${order['payableAmount'] ?? order['totalAmount'] ?? '0.00'}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Earn: ₹${(order['driverEarnings'] ?? order['deliveryCharge'] ?? 50.0).toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[200]! : Colors.blue[200]!),
                    ),
                    child: Text(
                      (order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD' ? 'Cash on Delivery' : 'Online / UPI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ((order['paymentTransaction'] != null && (order['paymentTransaction']['provider'] == 'cod' || order['paymentTransaction']['provider'] == 'Cash on Delivery')) || order['paymentMethod'] == 'Cash on Delivery' || order['paymentMethod'] == 'COD') ? Colors.green[800] : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Address and Tracking
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${order['deliveryAddress']?['addressLine'] ?? ''}, ${order['deliveryAddress']?['city'] ?? ''}".trim() == ","
                      ? ((order['customer']?['address'] is String) ? order['customer']['address'] : ((order['address'] is String) ? order['address'] : (order['address']?['fullAddress'] ?? 'N/A')))
                      : "${order['deliveryAddress']?['addressLine'] ?? ''}, ${order['deliveryAddress']?['city'] ?? ''}",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isHistorical) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(order: order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Track Delivery",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Footer: Estimate and Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isHistorical ? Icons.history : Icons.access_time,
                    size: 18,
                    color: isHistorical ? Colors.grey : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isHistorical ? "Completed" : "Estimate: 8 mins",
                    style: TextStyle(
                      fontSize: 13,
                      color: isHistorical ? Colors.grey : Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (!isHistorical && (order['deliveryStatus'] == 'picked_up' || order['deliveryStatus'] == 'out_for_delivery')) ...[
            const SizedBox(height: 16),
            InlineDeliveryOtpForm(order: order),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<DriverBloc>().add(
              const LoadActiveOrders(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _showPaymentQRDialog(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text(
              'Accept Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Order #${order['orderNumber']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 200, color: Colors.black),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan to Pay via PhonePe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Total: ₹${order['payableAmount'] ?? order['totalAmount']}',
                    style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Wait for customer to scan and complete payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment Confirmed!'), backgroundColor: primaryGreen),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Payment Received'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
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

