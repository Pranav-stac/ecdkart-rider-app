import 'package:equatable/equatable.dart';
import 'package:vegbox_driver_app/data/models/user_models.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Initial state
class AuthInitial extends AuthState {
  const AuthInitial();
}

// Loading state
class AuthLoading extends AuthState {
  const AuthLoading();
}

// OTP sent successfully
class OtpSent extends AuthState {
  final String phone;

  const OtpSent({required this.phone});

  @override
  List<Object?> get props => [phone];
}

// User already exists, need to login with PIN
class UserExistsLoginRequired extends AuthState {
  final String phone;
  final String message;

  const UserExistsLoginRequired({required this.phone, required this.message});

  @override
  List<Object?> get props => [phone, message];
}

// User authenticated (logged in)
class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

// User not authenticated (logged out)
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

// Error state
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
