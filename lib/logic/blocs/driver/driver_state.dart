import 'package:equatable/equatable.dart';
import '../../../data/models/user_models.dart';

abstract class DriverState extends Equatable {
  final List<dynamic> orders;
  final List<dynamic> completedOrders;
  final List<dynamic> cancelledOrders;
  final Map<String, dynamic>? summaryData;

  const DriverState({
    this.orders = const [],
    this.completedOrders = const [],
    this.cancelledOrders = const [],
    this.summaryData,
  });

  @override
  List<Object?> get props => [orders, completedOrders, cancelledOrders, summaryData];
}

class DriverInitial extends DriverState {
  const DriverInitial() : super();
}

class DriverLoading extends DriverState {
  const DriverLoading({
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });
}

class OnlineStatusUpdated extends DriverState {
  final bool isOnline;
  final String message;
  final UserModel? updatedUser;

  const OnlineStatusUpdated({
    required this.isOnline,
    required this.message,
    this.updatedUser,
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });

  @override
  List<Object?> get props => [isOnline, message, updatedUser, ...super.props];
}

class ReachedStoreConfirmed extends DriverState {
  final String message;
  final UserModel? updatedUser;

  const ReachedStoreConfirmed({
    required this.message,
    this.updatedUser,
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });

  @override
  List<Object?> get props => [message, updatedUser, ...super.props];
}

class LocationUpdated extends DriverState {
  final double latitude;
  final double longitude;

  const LocationUpdated({
    required this.latitude,
    required this.longitude,
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });

  @override
  List<Object?> get props => [latitude, longitude, ...super.props];
}

class ActiveOrdersLoaded extends DriverState {
  const ActiveOrdersLoaded({
    required super.orders,
    required super.completedOrders,
    required super.cancelledOrders,
    super.summaryData,
  });
}

class OrderStatusUpdated extends DriverState {
  final String orderId;
  final String status;
  final String message;

  const OrderStatusUpdated({
    required this.orderId,
    required this.status,
    required this.message,
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });

  @override
  List<Object?> get props => [orderId, status, message, ...super.props];
}

class DriverError extends DriverState {
  final String message;

  const DriverError({
    required this.message,
    super.orders,
    super.completedOrders,
    super.cancelledOrders,
    super.summaryData,
  });

  @override
  List<Object?> get props => [message, ...super.props];
}
