import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStreamSubscription;
  static Position? _lastPosition;

  /// Check if location permission is granted
  static Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    
    if (status.isPermanentlyDenied) {
      // Open app settings if permanently denied
      await openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  /// Check if location service is enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location once
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission
      final hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        final granted = await requestLocationPermission();
        if (!granted) return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastPosition = position;
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Start listening to location updates
  static Future<Stream<Position>?> startLocationUpdates({
    Function(Position)? onLocationUpdate,
  }) async {
    try {
      // Check if service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission
      final hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        final granted = await requestLocationPermission();
        if (!granted) return null;
      }

      // Create location settings
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      // Start listening to position stream
      final positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );

      if (onLocationUpdate != null) {
        _positionStreamSubscription = positionStream.listen((position) {
          _lastPosition = position;
          onLocationUpdate(position);
        });
      }

      return positionStream;
    } catch (e) {
      print('Error starting location updates: $e');
      return null;
    }
  }

  /// Stop listening to location updates
  static Future<void> stopLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Get last known position (without requesting new one)
  static Position? getLastPosition() {
    return _lastPosition;
  }

  /// Calculate distance between two points in meters
  static double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }

  /// Open location settings
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
