import 'package:equatable/equatable.dart';
import '../../../data/models/user_models.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// Send OTP
class SendOtpRequested extends AuthEvent {
  final String phone;

  const SendOtpRequested({required this.phone});

  @override
  List<Object?> get props => [phone];
}

// Verify OTP (with optional PIN for first-time setup)
class VerifyOtpRequested extends AuthEvent {
  final String phone;
  final String otp;
  final String? pin;

  const VerifyOtpRequested({required this.phone, required this.otp, this.pin});

  @override
  List<Object?> get props => [phone, otp, pin];
}

// Login with PIN
class LoginWithPinRequested extends AuthEvent {
  final String phone;
  final String pin;

  const LoginWithPinRequested({required this.phone, required this.pin});

  @override
  List<Object?> get props => [phone, pin];
}

// Check if user is already logged in (on app start)
class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

// Logout
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

// Reset error state
class ResetAuthError extends AuthEvent {
  const ResetAuthError();
}

// ✅ NEW: Update user data (when driver status changes)
class UpdateUserData extends AuthEvent {
  final UserModel user;

  const UpdateUserData({required this.user});

  @override
  List<Object?> get props => [user];
}
