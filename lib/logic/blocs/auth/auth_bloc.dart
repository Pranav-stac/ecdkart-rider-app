import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/auth_response_model.dart';
import '../../../data/models/user_models.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitial()) {
    on<SendOtpRequested>(_onSendOtpRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<LoginWithPinRequested>(_onLoginWithPinRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetAuthError>(_onResetAuthError);
    on<UpdateUserData>(_onUpdateUserData); // ✅ NEW
  }

  // Send OTP
  Future<void> _onSendOtpRequested(
    SendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await ApiService.sendOtp(event.phone);

      if (result['success'] == true) {
        if (result['data']?['exists'] == true) {
          final message = result['data']?['message'] ?? 'Account exists. Please login.';
          emit(UserExistsLoginRequired(phone: event.phone, message: message));
        } else {
          emit(OtpSent(phone: event.phone));
        }
      } else {
        final message = result['data']?['message'] ?? 'Failed to send OTP';
        emit(AuthError(message: message));
      }
    } catch (e) {
      emit(AuthError(message: 'Network error: $e'));
    }
  }

  // Verify OTP (with optional PIN setup)
  Future<void> _onVerifyOtpRequested(
    VerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await ApiService.verifyOtp(
        event.phone,
        event.otp,
        pin: event.pin,
      );

      if (result['success'] == true) {
        final rawData = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : (result['data'] != null ? Map<String, dynamic>.from(result['data'] as Map) : result);
        final authResponse = AuthResponseModel.fromJson(rawData);

        // If we provided a PIN, we definitely have a PIN set
        final hasPinSet = event.pin != null && event.pin!.isNotEmpty;

        debugPrint("🔐 Saving tokens after OTP verification for phone: ${event.phone}");

        // Save tokens
        await AuthService.saveTokens(
          authResponse.accessToken.isNotEmpty ? authResponse.accessToken : "token_${DateTime.now().millisecondsSinceEpoch}",
          authResponse.refreshToken.isNotEmpty ? authResponse.refreshToken : "refresh_${DateTime.now().millisecondsSinceEpoch}",
          event.phone,
          hasPin: hasPinSet,
        );

        // Force offline on fresh login
        try {
          await ApiService.toggleOnlineStatus(false);
        } catch (_) {}

        NotificationService.registerToken();
        emit(Authenticated(user: authResponse.user.copyWith(isOnline: false, phone: event.phone)));
      } else {
        final message = result['data']?['message'] ?? result['message'] ?? 'Invalid OTP';
        emit(AuthError(message: message.toString()));
      }
    } catch (e) {
      debugPrint("❌ OTP Verification Error: $e");
      emit(AuthError(message: 'Verification failed: $e'));
    }
  }

  // Login with PIN
  Future<void> _onLoginWithPinRequested(
    LoginWithPinRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final result = await ApiService.loginWithPin(event.phone, event.pin);

      if (result['success'] == true) {
        final authResponse = AuthResponseModel.fromJson(result['data']);

        // Save tokens
        await AuthService.saveTokens(
          authResponse.accessToken,
          authResponse.refreshToken,
          event.phone,
          hasPin: true,
        );

        // Force offline on fresh login
        try {
          await ApiService.toggleOnlineStatus(false);
        } catch (_) {}

        NotificationService.registerToken();
        emit(Authenticated(user: authResponse.user.copyWith(isOnline: false)));
      } else {
        final message = result['data']?['message'] ?? 'Invalid PIN';
        emit(AuthError(message: message));
      }
    } catch (e) {
      emit(AuthError(message: 'Login failed: $e'));
    }
  }

  // Check if user is already logged in
  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      final phone = await AuthService.getUserPhone();

      if (isLoggedIn && phone != null && phone.isNotEmpty) {
        final hasPin = await AuthService.hasPin();
        try {
          final result = await ApiService.getProfile();

          if (result['success'] == true) {
            final userData = result['user'] ?? result['data']?['user'] ?? result['data'];
            final riderData = result['rider'] ?? result['data']?['rider'];

            final userMap = userData is Map ? Map<String, dynamic>.from(userData) : <String, dynamic>{};
            final riderMap = riderData is Map ? Map<String, dynamic>.from(riderData) : <String, dynamic>{};

            final vStatus = (riderMap['verificationStatus'] ?? userMap['verificationStatus'] ?? 'pending').toString().toLowerCase();
            final isVerified = (vStatus == 'approved' ||
                vStatus == 'verified' ||
                userMap['isVerified'] == true ||
                riderMap['riderVerified'] == true) &&
                vStatus != 'rejected';
            final isOnline = isVerified && (riderMap['isOnline'] == true || userMap['isOnline'] == true);

            final parsedUser = UserModel.fromJson({
              ...userMap,
              ...riderMap,
              'id': userMap['_id'] ?? userMap['id'] ?? riderMap['_id'] ?? 'RIDER_${phone.replaceAll(RegExp(r'\D'), '')}',
              'riderId': riderMap['_id']?.toString() ?? userMap['riderId']?.toString(),
              'phone': userMap['phone'] ?? userMap['mobile'] ?? riderMap['phone'] ?? riderMap['mobile'] ?? phone,
              'name': userMap['name'] ?? riderMap['name'] ?? 'Rider Partner',
              'isOnline': isOnline,
              'isVerified': isVerified,
              'verificationStatus': vStatus,
              'hasPinSet': hasPin || userMap['pinHash'] != null,
              'upi': riderMap['bankDetails']?['upiId'] ??
                  riderMap['bankDetails']?['upi'] ??
                  riderMap['upiId'] ??
                  riderMap['upi'] ??
                  userMap['bankDetails']?['upiId'] ??
                  userMap['upi'],
              'bankDetails': riderMap['bankDetails'] ?? userMap['bankDetails'],
              'rider': riderMap,
              'user': userMap,
            });

            emit(Authenticated(user: parsedUser));
            return;
          }
        } catch (profileErr) {
          debugPrint("getProfile warning in CheckAuthStatus: $profileErr");
        }

        // Fallback: If logged in with phone & token, authenticate immediately!
        final fallbackUser = UserModel(
          id: 'RIDER_${phone.replaceAll(RegExp(r'\D'), '')}',
          phone: phone,
          name: 'Rider Partner',
          role: 'driver',
          isVerified: false, // Default to false (pending admin review)
          hasPinSet: hasPin,
          isOnline: false,
          isReturning: true,
          createdAt: DateTime.now(),
        );

        emit(Authenticated(user: fallbackUser));
        return;
      }

      emit(const Unauthenticated());
    } catch (e) {
      debugPrint("Auth check error: $e");
      emit(const Unauthenticated());
    }
  }

  // Logout
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Force offline on logout
    try {
      await ApiService.toggleOnlineStatus(false);
    } catch (_) {}

    await AuthService.logout();
    emit(const Unauthenticated());
  }

  // Reset error state
  Future<void> _onResetAuthError(
    ResetAuthError event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthInitial());
  }

  // ✅ NEW: Update user data (when driver changes status)
  Future<void> _onUpdateUserData(
    UpdateUserData event,
    Emitter<AuthState> emit,
  ) async {
    emit(Authenticated(user: event.user));
  }
}
