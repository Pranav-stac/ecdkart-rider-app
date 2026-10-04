import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../logic/blocs/driver/driver_bloc.dart';
import '../../../logic/blocs/driver/driver_event.dart';
import '../../../logic/blocs/driver/driver_state.dart';
import '../../../data/services/api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isToRestaurant;

  const OrderTrackingScreen({
    super.key,
    required this.order,
    this.isToRestaurant = false,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const Color primaryGreen = Color(0xFF248C70);
  static const Color lightGreen = Color(0xFFE8F5E9);

  GoogleMapController? _mapController;
  LatLng? _driverLatLng;
  StreamSubscription<Position>? _positionSubscription;
  bool _isLoading = false;
  late String _currentDeliveryStatus;
  late bool _isToRestaurant;
  Timer? _statusPollTimer;

  final Set<Polyline> _polylines = {};
  static const String googleApiKey = 'AIzaSyCN7XqyxOj5lgr2uaMNrTOg6PzHTOGa0xU';
  PolylinePoints polylinePoints = PolylinePoints(apiKey: googleApiKey);

  @override
  void initState() {
    super.initState();
    _currentDeliveryStatus = (widget.order['deliveryStatus'] ?? widget.order['status'] ?? 'accepted').toString();
    final isDelivering = ['picked_up', 'out_for_delivery', 'reached_customer_location', 'delivered'].contains(_currentDeliveryStatus.toLowerCase());
    _isToRestaurant = widget.isToRestaurant && !isDelivering;
    _determineInitialPosition();
    _startLocationSubscription();
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final orderId = (widget.order['_id'] ?? widget.order['orderId'] ?? '').toString();
      if (orderId.isEmpty || !mounted) return;
      try {
        final res = await ApiService.getOrderDetails(orderId);
        if (res['success'] == true && res['data'] != null && mounted) {
          final data = res['data'];
          final Map<String, dynamic> rawObj = (data is Map && data['order'] is Map) ? Map<String, dynamic>.from(data['order']) : (data is Map ? Map<String, dynamic>.from(data) : {});
          final status = (rawObj['deliveryStatus'] ?? rawObj['status'] ?? data['deliveryStatus'] ?? data['status'] ?? '').toString().toLowerCase();
          final isDelivering = ['picked_up', 'out_for_delivery', 'on_the_way', 'reached_customer_location', 'delivered'].contains(status);

          final bool isLocalOutForDelivery = _currentDeliveryStatus == 'out_for_delivery' || _currentDeliveryStatus == 'on_the_way';
          final bool isFetchedPickedUp = status == 'picked_up' || status == 'partner_picked' || status == 'accepted' || status == 'assigned';

          if (isDelivering && _isToRestaurant) {
            setState(() {
              _isToRestaurant = false;
              if (isLocalOutForDelivery) {
                _currentDeliveryStatus = 'out_for_delivery';
              } else {
                _currentDeliveryStatus = (status == 'assigned' || status == 'accepted') ? 'picked_up' : status;
              }
              if (rawObj['customer'] != null) widget.order['customer'] = rawObj['customer'];
              if (rawObj['deliveryAddress'] != null) widget.order['deliveryAddress'] = rawObj['deliveryAddress'];
              if (rawObj['address'] != null) widget.order['address'] = rawObj['address'];
            });
            _getPolyline();
            if (_driverLatLng != null) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLatLng!, 15.0));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 OTP Verified by Restaurant! Order Handed Over. Deliver to Customer!'),
                backgroundColor: primaryGreen,
                duration: Duration(seconds: 4),
              ),
            );
          } else if (status.isNotEmpty && status != _currentDeliveryStatus.toLowerCase()) {
            if (!(isLocalOutForDelivery && isFetchedPickedUp)) {
              setState(() {
                _currentDeliveryStatus = status;
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
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

  Future<void> _determineInitialPosition() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _driverLatLng = LatLng(position.latitude, position.longitude);
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_driverLatLng!, 15.0));
          _getPolyline();
        }
      }
    } catch (_) {}
  }

  void _startLocationSubscription() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _driverLatLng = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _getPolyline() async {
    if (_driverLatLng == null) return;
    
    final targetLatLng = _isToRestaurant ? _getRestaurantLatLng() : _getCustomerLatLng();
    
    // ignore: deprecated_member_use
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      // ignore: deprecated_member_use
      request: PolylineRequest(
        origin: PointLatLng(_driverLatLng!.latitude, _driverLatLng!.longitude),
        destination: PointLatLng(targetLatLng.latitude, targetLatLng.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      if (mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: _isToRestaurant ? Colors.orange : primaryGreen,
              points: polylineCoordinates,
              width: 5,
            ),
          );
        });
      }
    }
  }

  LatLng _getRestaurantLatLng() {
    try {
      final store = widget.order['store'];
      final restaurant = widget.order['restaurant'];
      final storeLoc = store?['location'] ?? restaurant?['location'] ?? widget.order['restaurantLocation'] ?? widget.order['location'];
      if (storeLoc != null && storeLoc['coordinates'] != null) {
        final coords = storeLoc['coordinates'] as List;
        if (coords.length >= 2) {
          final lat = (coords[1] as num).toDouble();
          final lng = (coords[0] as num).toDouble();
          if (lat != 0 && lng != 0) {
            return LatLng(lat, lng);
          }
        }
      }
      if (restaurant is Map && restaurant['latitude'] != null && restaurant['longitude'] != null) {
        return LatLng((restaurant['latitude'] as num).toDouble(), (restaurant['longitude'] as num).toDouble());
      }
    } catch (_) {}
    return const LatLng(22.7196, 75.8577); // Default Indore Coordinates
  }

  LatLng _getCustomerLatLng() {
    try {
      final address = widget.order['address'] ?? widget.order['deliveryAddress'] ?? widget.order['customer']?['address'];
      if (address != null && address is Map) {
        final loc = address['location'];
        if (loc != null && loc['coordinates'] != null) {
          final coords = loc['coordinates'] as List;
          if (coords.length >= 2) {
            final lat = (coords[1] as num).toDouble();
            final lng = (coords[0] as num).toDouble();
            if (lat != 0 && lng != 0) {
              return LatLng(lat, lng);
            }
          }
        }
        if (address['latitude'] != null && address['longitude'] != null) {
          return LatLng((address['latitude'] as num).toDouble(), (address['longitude'] as num).toDouble());
        }
      }
      final directAddr = widget.order['deliveryAddress'] ?? widget.order['address'];
      if (directAddr is Map && directAddr['coordinates'] != null) {
        final coords = directAddr['coordinates'] as List;
        if (coords.length >= 2) {
          final lat = (coords[1] as num).toDouble();
          final lng = (coords[0] as num).toDouble();
          if (lat != 0 && lng != 0) return LatLng(lat, lng);
        }
      }
      final custLoc = widget.order['customerLocation'] ?? widget.order['location'];
      if (custLoc is Map && custLoc['coordinates'] != null) {
        final coords = custLoc['coordinates'] as List;
        if (coords.length >= 2) {
          final lat = (coords[1] as num).toDouble();
          final lng = (coords[0] as num).toDouble();
          if (lat != 0 && lng != 0) return LatLng(lat, lng);
        }
      }
    } catch (_) {}
    return const LatLng(22.7196, 75.8577); // Default Indore Coordinates
  }

  String _getLiveDistance() {
    if (_driverLatLng != null) {
      final targetLatLng = _isToRestaurant ? _getRestaurantLatLng() : _getCustomerLatLng();
      try {
        final distanceInMeters = Geolocator.distanceBetween(
          _driverLatLng!.latitude,
          _driverLatLng!.longitude,
          targetLatLng.latitude,
          targetLatLng.longitude,
        );
        final distanceInKm = distanceInMeters / 1000;
        return distanceInKm.toStringAsFixed(1);
      } catch (_) {}
    }
    
    try {
      if (_isToRestaurant) {
        final rDist = widget.order['restaurant']?['distance_km'] ?? widget.order['store']?['distance_km'];
        if (rDist != null) return rDist.toString();
      } else {
        final cDist = widget.order['customer']?['distance_km'];
        if (cDist != null) return cDist.toString();
      }
      final oDist = widget.order['distanceKm'] ?? widget.order['distance_km'];
      if (oDist != null) return oDist.toString();
    } catch (_) {}
    
    return '1.2';
  }

  Future<void> _openExternalMap() async {
    final dest = _isToRestaurant ? _getRestaurantLatLng() : _getCustomerLatLng();
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving';
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps application')),
        );
      }
    }
  }

  void _handleStatusTransition(BuildContext context) async {
    final orderId = (widget.order['_id'] ?? widget.order['orderId'] ?? '').toString();
    
    if (_isToRestaurant) {
      if (_currentDeliveryStatus == 'accepted' || _currentDeliveryStatus == 'assigned') {
        setState(() => _isLoading = true);
        context.read<DriverBloc>().add(
              UpdateOrderStatus(orderId: orderId, status: 'reached_store'),
            );
        setState(() {
          _currentDeliveryStatus = 'reached_store';
          _isLoading = false;
        });
      } else if (_currentDeliveryStatus == 'reached_store') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔑 Please tell the 4-digit OTP to the restaurant owner so they can verify and hand over the order.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Customer Delivery Flow
    if (_currentDeliveryStatus == 'picked_up' || _currentDeliveryStatus == 'accepted' || _currentDeliveryStatus == 'assigned') {
      setState(() => _isLoading = true);
      final res = await ApiService.updateOrderStatus(orderId: orderId, status: 'out_for_delivery');
      if (mounted) {
        setState(() {
          _currentDeliveryStatus = 'out_for_delivery';
          _isToRestaurant = false;
          _isLoading = false;
        });
        _getPolyline();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Order is Out for Delivery! Navigation started to Customer location.'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } else if (_currentDeliveryStatus == 'out_for_delivery' || _currentDeliveryStatus == 'on_the_way' || _currentDeliveryStatus == 'reached_customer_location' || _currentDeliveryStatus == 'delivery_arrived') {
      setState(() => _isLoading = true);
      final res = await ApiService.updateOrderStatus(orderId: orderId, status: 'delivered');
      if (mounted) {
        setState(() => _isLoading = false);
        context.read<DriverBloc>().add(const LoadActiveOrders());
        _showOrderDeliveredDialog();
      }
    }
  }

  void _showOrderDeliveredDialog() {
    final orderNum = widget.order['orderNumber'] ?? widget.order['orderId'] ?? widget.order['_id'] ?? '';
    final custName = widget.order['customer']?['name'] ?? 'Customer';
    final orderId = (widget.order['_id'] ?? widget.order['orderId'] ?? '').toString();
    final noteController = TextEditingController();
    double selectedRating = 5.0;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 54),
                ),
                const SizedBox(height: 14),
                Text(
                  '🎉 Order Delivered Successfully!',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Order #$orderNum delivered to $custName. Please rate your delivery experience with customer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Rate Customer',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = star.toDouble();
                        });
                      },
                      icon: Icon(
                        star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber[700],
                        size: 32,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    );
                  }),
                ),
                Text(
                  '${selectedRating.toInt()} / 5 Stars',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[800]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add note about customer / delivery (optional)...',
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            await ApiService.updateOrderStatus(orderId: orderId, status: 'delivered');
                            await ApiService.rateCustomer(
                              orderId: orderId,
                              rating: selectedRating,
                              note: noteController.text.trim(),
                            );
                            if (mounted) {
                              context.read<DriverBloc>().add(const LoadActiveOrders());
                              Navigator.pop(ctx);
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Rating submitted! Order completed.'),
                                  backgroundColor: primaryGreen,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Submit & Finish',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.order['customer'] ?? {};
    final address = widget.order['address'] ?? widget.order['deliveryAddress'] ?? {};
    final restaurant = widget.order['restaurant'] ?? {'name': 'Restaurant Store', 'address': 'Indore, MP'};

    final targetLatLng = _isToRestaurant ? _getRestaurantLatLng() : _getCustomerLatLng();

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('target'),
        position: targetLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _isToRestaurant ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueGreen,
        ),
      ),
    };

    if (_driverLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    String actionBtnText = '';
    Color actionBtnColor = primaryGreen;
    bool showActionButton = true;

    if (_isToRestaurant) {
      if (_currentDeliveryStatus == 'accepted' || _currentDeliveryStatus == 'assigned') {
        actionBtnText = 'I have Reached the Store';
        actionBtnColor = Colors.orange[700]!;
      } else if (_currentDeliveryStatus == 'reached_store') {
        actionBtnText = 'Waiting for Restaurant';
        actionBtnColor = Colors.orange[300]!;
      } else {
        showActionButton = false;
      }
    } else {
      if (_currentDeliveryStatus == 'picked_up' || _currentDeliveryStatus == 'accepted' || _currentDeliveryStatus == 'assigned') {
        actionBtnText = 'Order On The Way';
        actionBtnColor = primaryGreen;
      } else if (_currentDeliveryStatus == 'out_for_delivery' || _currentDeliveryStatus == 'on_the_way' || _currentDeliveryStatus == 'reached_customer_location' || _currentDeliveryStatus == 'delivery_arrived') {
        actionBtnText = 'Order Delivered';
        actionBtnColor = primaryGreen;
      } else {
        showActionButton = false;
      }
    }

    return BlocListener<DriverBloc, DriverState>(
      listener: (context, state) {
        if (state is OrderStatusUpdated) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: primaryGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (state.status == 'delivered') {
            _showOrderDeliveredDialog();
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
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isToRestaurant ? 'Track Pick-up' : 'Track Delivery'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: targetLatLng,
                          zoom: 14.5,
                        ),
                        onMapCreated: (controller) => _mapController = controller,
                        markers: markers,
                        polylines: _polylines,
                      ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton.extended(
                            onPressed: _openExternalMap,
                            backgroundColor: Colors.blue[600],
                            icon: const Icon(Icons.navigation, color: Colors.white),
                            label: const Text('Navigate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Arrival',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              Text(
                                'Est. Arrival',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _isToRestaurant ? Colors.orange[700] : primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: (_isToRestaurant ? Colors.orange[700] : primaryGreen)!.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_getLiveDistance()} KM',
                              style: TextStyle(
                                color: _isToRestaurant ? Colors.orange[700] : primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (_isToRestaurant ? Colors.orange[50] : lightGreen),
                            child: Icon(
                              _isToRestaurant ? Icons.storefront : Icons.person,
                              color: _isToRestaurant ? Colors.orange[700] : primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isToRestaurant ? (restaurant['name'] ?? 'Restaurant') : (customer['name'] ?? 'Customer'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isToRestaurant
                                      ? (_parseAddressToString(restaurant['address']).isNotEmpty ? _parseAddressToString(restaurant['address']) : 'Store Location')
                                      : (_parseAddressToString(address).isNotEmpty ? _parseAddressToString(address) : (_parseAddressToString(customer['address']).isNotEmpty ? _parseAddressToString(customer['address']) : 'Customer Location')),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isToRestaurant ? (restaurant['phone'] ?? 'No Number') : (widget.order['deliveryPhone'] ?? customer['phone'] ?? 'No Number'),
                                  style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final phone = _isToRestaurant ? restaurant['phone'] : (widget.order['deliveryPhone'] ?? customer['phone']);
                              if (phone != null && phone.toString().isNotEmpty) {
                                final uri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.phone),
                            color: _isToRestaurant ? Colors.orange[700] : primaryGreen,
                            style: IconButton.styleFrom(
                              backgroundColor: (_isToRestaurant ? Colors.orange[700] : primaryGreen)!.withValues(alpha: 0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isToRestaurant) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '🔑 SHOW THIS 4-DIGIT OTP TO RESTAURANT FOR PICKUP',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ((widget.order['pickupOtp'] ?? widget.order['store']?['pickupOtp'] ?? widget.order['restaurant']?['pickupOtp'] ?? widget.order['deliveryOtp']) ?? '----').toString(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Restaurant owner will verify this code to hand over the order.',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (showActionButton) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () => _handleStatusTransition(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: actionBtnColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
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
                      ]
                    ],
                  ),
                ),
              ],
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
}
