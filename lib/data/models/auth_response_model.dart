import 'package:equatable/equatable.dart';
import 'package:vegbox_driver_app/data/models/user_models.dart';

class AuthResponseModel extends Equatable {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['token'] ?? json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
