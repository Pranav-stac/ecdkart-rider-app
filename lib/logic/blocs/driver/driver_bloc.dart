import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/api_service.dart';
import '../../../data/models/user_models.dart';
import 'driver_event.dart';
import 'driver_state.dart';

class DriverBloc extends Bloc<DriverEvent, DriverState> {
  List<dynamic> _activeOrders = [];
  List<dynamic> _completedOrders = [];
  List<dynamic> _cancelledOrders = [];
  Map<String, dynamic>? _summaryData;

  DriverBloc() : super(const DriverInitial()) {
    on<ToggleOnlineStatus>(_onToggleOnlineStatus);
    on<MarkReachedStore>(_onMarkReachedStore);
    on<UpdateDriverLocation>(_onUpdateDriverLocation);
    on<LoadActiveOrders>(_onLoadActiveOrders);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<AcceptOrder>(_onAcceptOrder);
    on<DeclineOrder>(_onDeclineOrder);
    on<ResetDriverError>(_onResetDriverError);
  }

  // Toggle online/offline status
  Future<void> _onToggleOnlineStatus(
    ToggleOnlineStatus event,
    Emitter<DriverState> emit,
  ) async {
    emit(DriverLoading(
      orders: _activeOrders,
      completedOrders: _completedOrders,
      cancelledOrders: _cancelledOrders,
      summaryData: _summaryData,
    ));

    try {
      final result = await ApiService.toggleOnlineStatus(event.isOnline);
      if (result['success'] == true) {
        final updatedUser = event.currentUser.copyWith(
          isOnline: event.isOnline,
          isReturning: false,
        );

        emit(
          OnlineStatusUpdated(
            isOnline: event.isOnline,
            message: result['data']?['message'] ?? 'Status updated to ${event.isOnline ? "Online" : "Offline"}',
            updatedUser: updatedUser,
            orders: _activeOrders,
            completedOrders: _completedOrders,
            cancelledOrders: _cancelledOrders,
            summaryData: _summaryData,
          ),
        );
      } else {
        emit(DriverError(
          message: result['message'] ?? 'Failed to update status',
          orders: _activeOrders,
          completedOrders: _completedOrders,
          cancelledOrders: _cancelledOrders,
          summaryData: _summaryData,
        ));
      }
    } catch (e) {
      emit(DriverError(
        message: 'Network error: $e',
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }
  }

  // Mark driver as reached store
  Future<void> _onMarkReachedStore(
    MarkReachedStore event,
    Emitter<DriverState> emit,
  ) async {
    emit(const DriverLoading());

    // try {
    //   final result = await ApiService.markReachedStore();
    //   ...
    // } catch (e) { ... }

    // Logic Bypass for Development: Always succeed
    await Future.delayed(const Duration(milliseconds: 800));

    final updatedUser = UserModel(
      id: "mock_id",
      phone: "9876543210",
      name: "Mock Driver",
      role: "driver",
      isVerified: true,
      hasPinSet: true,
      createdAt: DateTime.now(),
      isOnline: true,
      isReturning: false,
    );

    emit(ReachedStoreConfirmed(
      message: 'Welcome back! You are now available for new orders (Mock)',
      updatedUser: updatedUser,
      orders: _activeOrders,
      completedOrders: _completedOrders,
      cancelledOrders: _cancelledOrders,
      summaryData: _summaryData,
    ));
  }

  // Update driver location
  Future<void> _onUpdateDriverLocation(
    UpdateDriverLocation event,
    Emitter<DriverState> emit,
  ) async {
    try {
      final result = await ApiService.updateLocation(
        latitude: event.latitude,
        longitude: event.longitude,
        speed: event.speed,
        heading: event.heading,
      );
      
      if (result['success'] == true) {
        emit(
          LocationUpdated(
            latitude: event.latitude, 
            longitude: event.longitude,
            orders: _activeOrders,
            completedOrders: _completedOrders,
            cancelledOrders: _cancelledOrders,
            summaryData: _summaryData,
          ),
        );
      }
    } catch (e) {
      log('Failed to update location: $e');
    }
  }

  // Load active orders
  Future<void> _onLoadActiveOrders(
    LoadActiveOrders event,
    Emitter<DriverState> emit,
  ) async {
    if (!event.isSilent) {
      emit(DriverLoading(
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }

    try {
      final activeResponse = await ApiService.getActiveOrders();
      final historyResponse = await ApiService.getOrderHistory();
      final summaryResponse = await ApiService.getDriverSummary();

      List<dynamic> newActiveOrders = [];
      List<dynamic> newCompletedOrders = [];
      List<dynamic> newCancelledOrders = [];

      if (activeResponse['success'] == true && activeResponse['data'] != null) {
        final data = activeResponse['data'];
        if (data['order'] != null) {
           final Map<String, dynamic> orderObj = Map<String, dynamic>.from(data['order']);
           if (data['restaurant'] != null) {
             orderObj['restaurant'] = data['restaurant'];
           }
           if (data['customer'] != null) {
             orderObj['customer'] = data['customer'];
           }
           newActiveOrders.add(orderObj);
        }
      }

      if (historyResponse['success'] == true && historyResponse['data'] != null) {
        final data = historyResponse['data'];
        if (data['orders'] != null && data['orders'] is List) {
          final List<dynamic> rawOrders = data['orders'] as List;
          final List<dynamic> normalizedOrders = [];
          
          for (var o in rawOrders) {
            final Map<String, dynamic> normalized = Map<String, dynamic>.from(o);
            // Normalize status and active flags
            normalized['deliveryStatus'] = o['status'] ?? 'delivered';
            normalized['_id'] = o['orderId'] ?? o['_id'] ?? '';
            
            // Normalize amounts
            final amount = o['customer']?['payableAmount'] ?? o['payableAmount'] ?? o['totalAmount'] ?? 0.0;
            normalized['totalAmount'] = amount;
            normalized['payableAmount'] = amount;
            
            // Normalize address object
            normalized['deliveryAddress'] = {
              'addressLine': o['customer']?['address'] ?? '',
              'city': o['customer']?['city'] ?? 'Indore',
            };
            normalizedOrders.add(normalized);
          }
          
          newCompletedOrders = normalizedOrders.where((o) => o['deliveryStatus'] == 'delivered').toList();
          newCancelledOrders = normalizedOrders.where((o) => o['deliveryStatus'] == 'cancelled' || o['deliveryStatus'] == 'failed').toList();
        }
      }

      if (summaryResponse['success'] == true && summaryResponse['data'] != null) {
        _summaryData = summaryResponse['data'];
      }

      _activeOrders = newActiveOrders;
      _completedOrders = newCompletedOrders;
      _cancelledOrders = newCancelledOrders;

      emit(ActiveOrdersLoaded(
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    } catch (e) {
      emit(DriverError(
        message: 'Network error: $e',
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }
  }

  // Update order status
  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<DriverState> emit,
  ) async {
    emit(DriverLoading(
      orders: _activeOrders,
      completedOrders: _completedOrders,
      cancelledOrders: _cancelledOrders,
      summaryData: _summaryData,
    ));

    try {
      final Map<String, dynamic> result = await ApiService.updateOrderStatus(
        orderId: event.orderId,
        status: event.status,
        otp: event.otp,
      );

      if (result['success'] == true) {
        String message = 'Order status updated successfully';

        if (result['data'] is Map && result['data']['message'] != null) {
          message = result['data']['message'].toString();
        }

        // Trigger active orders reload to refresh dashboard & details status!
        add(const LoadActiveOrders());

        emit(
          OrderStatusUpdated(
            orderId: event.orderId,
            status: event.status,
            message: message,
            orders: _activeOrders,
            completedOrders: _completedOrders,
            cancelledOrders: _cancelledOrders,
            summaryData: _summaryData,
          ),
        );
      } else {
        String errorMessage = 'Failed to update order status';

        if (result['data'] is Map && result['data']['message'] != null) {
          errorMessage = result['data']['message'].toString();
        }

        emit(DriverError(
          message: errorMessage,
          orders: _activeOrders,
          completedOrders: _completedOrders,
          cancelledOrders: _cancelledOrders,
          summaryData: _summaryData,
        ));
      }
    } catch (e) {
      emit(DriverError(
        message: 'Network error: $e',
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }
  }

  // Accept assigned order
  Future<void> _onAcceptOrder(
    AcceptOrder event,
    Emitter<DriverState> emit,
  ) async {
    emit(DriverLoading(
      orders: _activeOrders,
      completedOrders: _completedOrders,
      cancelledOrders: _cancelledOrders,
      summaryData: _summaryData,
    ));

    try {
      // Optimistic update to prevent double-accept UI issue
      if (_activeOrders.isNotEmpty && _activeOrders.first['_id'] == event.orderId) {
        _activeOrders.first['deliveryStatus'] = 'accepted';
      }

      final result = await ApiService.acceptOrder(event.orderId);
      if (result['success'] == true) {
        String message = 'Order accepted successfully';
        if (result['data'] is Map && result['data']['message'] != null) {
          message = result['data']['message'].toString();
        }

        // Trigger active orders reload to refresh dashboard & details status!
        add(const LoadActiveOrders());

        emit(
          OrderStatusUpdated(
            orderId: event.orderId,
            status: 'accepted',
            message: message,
            orders: _activeOrders,
            completedOrders: _completedOrders,
            cancelledOrders: _cancelledOrders,
            summaryData: _summaryData,
          ),
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to accept order';
        emit(DriverError(
          message: errorMessage,
          orders: _activeOrders,
          completedOrders: _completedOrders,
          cancelledOrders: _cancelledOrders,
          summaryData: _summaryData,
        ));
      }
    } catch (e) {
      emit(DriverError(
        message: 'Network error: $e',
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }
  }

  // Decline assigned order
  Future<void> _onDeclineOrder(
    DeclineOrder event,
    Emitter<DriverState> emit,
  ) async {
    emit(DriverLoading(
      orders: _activeOrders,
      completedOrders: _completedOrders,
      cancelledOrders: _cancelledOrders,
      summaryData: _summaryData,
    ));

    try {
      final result = await ApiService.declineOrder(event.orderId, reason: event.reason);
      if (result['success'] == true) {
        String message = 'Order declined successfully';
        if (result['data'] is Map && result['data']['message'] != null) {
          message = result['data']['message'].toString();
        }

        // Trigger active orders reload to refresh dashboard & details status!
        add(const LoadActiveOrders());

        emit(
          OrderStatusUpdated(
            orderId: event.orderId,
            status: 'declined',
            message: message,
            orders: _activeOrders,
            completedOrders: _completedOrders,
            cancelledOrders: _cancelledOrders,
            summaryData: _summaryData,
          ),
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to decline order';
        emit(DriverError(
          message: errorMessage,
          orders: _activeOrders,
          completedOrders: _completedOrders,
          cancelledOrders: _cancelledOrders,
          summaryData: _summaryData,
        ));
      }
    } catch (e) {
      emit(DriverError(
        message: 'Network error: $e',
        orders: _activeOrders,
        completedOrders: _completedOrders,
        cancelledOrders: _cancelledOrders,
        summaryData: _summaryData,
      ));
    }
  }

  // Reset error state
  Future<void> _onResetDriverError(
    ResetDriverError event,
    Emitter<DriverState> emit,
  ) async {
    emit(const DriverInitial());
  }
}
