import 'package:equatable/equatable.dart';
import '../../../data/models/user_models.dart';

abstract class DriverEvent extends Equatable {
  const DriverEvent();

  @override
  List<Object?> get props => [];
}

// Toggle online/offline status
class ToggleOnlineStatus extends DriverEvent {
  final bool isOnline;
  final UserModel currentUser;

  const ToggleOnlineStatus({required this.isOnline, required this.currentUser});

  @override
  List<Object?> get props => [isOnline, currentUser];
}

// Mark driver as reached store
class MarkReachedStore extends DriverEvent {
  const MarkReachedStore();
}

// Update driver location
class UpdateDriverLocation extends DriverEvent {
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;

  const UpdateDriverLocation({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
  });

  @override
  List<Object?> get props => [latitude, longitude, speed, heading];
}

// Load active orders
class LoadActiveOrders extends DriverEvent {
  final bool isSilent;
  const LoadActiveOrders({this.isSilent = false});

  @override
  List<Object?> get props => [isSilent];
}

// Update order status
class UpdateOrderStatus extends DriverEvent {
  final String orderId;
  final String status;
  final String? otp;

  const UpdateOrderStatus({
    required this.orderId,
    required this.status,
    this.otp,
  });

  @override
  List<Object?> get props => [orderId, status, otp];
}

// Accept assigned order
class AcceptOrder extends DriverEvent {
  final String orderId;

  const AcceptOrder({required this.orderId});

  @override
  List<Object?> get props => [orderId];
}

// Decline assigned order
class DeclineOrder extends DriverEvent {
  final String orderId;
  final String? reason;

  const DeclineOrder({required this.orderId, this.reason});

  @override
  List<Object?> get props => [orderId, reason];
}

// Reset driver error state
class ResetDriverError extends DriverEvent {
  const ResetDriverError();
}
