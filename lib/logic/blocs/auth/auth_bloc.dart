import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
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
        final authResponse = AuthResponseModel.fromJson(result['data']);

        // ✅ FIX: If we provided a PIN, we definitely have a PIN set
        final hasPinSet = event.pin != null && event.pin!.isNotEmpty;

        print("🔐 Saving tokens after OTP verification:");
        print("   PIN provided in request: ${event.pin != null}");
        print("   PIN value: ${event.pin}");
        print("   Setting hasPin to: $hasPinSet");

        // Save tokens
        await AuthService.saveTokens(
          authResponse.accessToken,
          authResponse.refreshToken,
          event.phone,
          hasPin: hasPinSet,
        );

        // Force offline on fresh login
        try {
          await ApiService.toggleOnlineStatus(false);
        } catch (_) {}

        emit(Authenticated(user: authResponse.user.copyWith(isOnline: false)));
      } else {
        final message = result['data']?['message'] ?? 'Invalid OTP';
        emit(AuthError(message: message));
      }
    } catch (e) {
      print("❌ OTP Verification Error: $e");
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

      if (isLoggedIn && phone != null) {
        // Try to get profile
        final result = await ApiService.getProfile();

        if (result['success'] == true) {
          final user = result['data']['user'];
          emit(
            Authenticated(
              user: user != null
                  ? AuthResponseModel.fromJson({'user': user}).user
                  : throw Exception('User data not found'),
            ),
          );
        } else {
          // Token might be invalid, logout
          await AuthService.logout();
          emit(const Unauthenticated());
        }
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      await AuthService.logout();
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
