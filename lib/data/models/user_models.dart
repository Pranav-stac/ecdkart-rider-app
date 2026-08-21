// import 'package:equatable/equatable.dart';

// class UserModel extends Equatable {
//   final String id;
//   final String phone;
//   final String? name;
//   final String role;
//   final bool isVerified;
//   final String? avatar;
//   final String? email;
//   final bool hasPinSet;
//   final DateTime createdAt;

//   const UserModel({
//     required this.id,
//     required this.phone,
//     this.name,
//     required this.role,
//     required this.isVerified,
//     this.avatar,
//     this.email,
//     required this.hasPinSet,
//     required this.createdAt,
//   });

//   factory UserModel.fromJson(Map<String, dynamic> json) {
//     return UserModel(
//       id: json['id'] ?? json['_id'] ?? '',
//       phone: json['phone'] ?? '',
//       name: json['name'],
//       role: json['role'] ?? 'driver',
//       isVerified: json['isVerified'] ?? false,
//       avatar: json['avatar'],
//       email: json['email'],
//       hasPinSet: json['pinHash'] != null,
//       createdAt: json['createdAt'] != null
//           ? DateTime.parse(json['createdAt'])
//           : DateTime.now(),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'phone': phone,
//       'name': name,
//       'role': role,
//       'isVerified': isVerified,
//       'avatar': avatar,
//       'email': email,
//       'hasPinSet': hasPinSet,
//       'createdAt': createdAt.toIso8601String(),
//     };
//   }

//   UserModel copyWith({
//     String? id,
//     String? phone,
//     String? name,
//     String? role,
//     bool? isVerified,
//     String? avatar,
//     String? email,
//     bool? hasPinSet,
//     DateTime? createdAt,
//   }) {
//     return UserModel(
//       id: id ?? this.id,
//       phone: phone ?? this.phone,
//       name: name ?? this.name,
//       role: role ?? this.role,
//       isVerified: isVerified ?? this.isVerified,
//       avatar: avatar ?? this.avatar,
//       email: email ?? this.email,
//       hasPinSet: hasPinSet ?? this.hasPinSet,
//       createdAt: createdAt ?? this.createdAt,
//     );
//   }

//   @override
//   List<Object?> get props => [
//         id,
//         phone,
//         name,
//         role,
//         isVerified,
//         avatar,
//         email,
//         hasPinSet,
//         createdAt,
//       ];
// }















import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? riderId;      // ✅ NEW: Driver ID (e.g. DRV-1234)
  final String phone;
  final String? name;
  final String role;
  final bool isVerified;
  final String? avatar;
  final String? email;
  final bool hasPinSet;
  final bool isOnline;        // ✅ NEW: Driver online status
  final bool isReturning;     // ✅ NEW: Driver returning to store
  final String? upi;          // ✅ NEW: Driver UPI payment identifier
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.riderId,
    required this.phone,
    this.name,
    required this.role,
    required this.isVerified,
    this.avatar,
    this.email,
    required this.hasPinSet,
    this.isOnline = false,      // ✅ Default false
    this.isReturning = false,   // ✅ Default false
    this.upi,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      riderId: json['riderId'], // ✅ Parse from backend
      phone: json['phone'] ?? '',
      name: json['name'],
      role: json['role'] ?? 'driver',
      isVerified: json['isVerified'] ?? false,
      avatar: json['avatar'],
      email: json['email'],
      hasPinSet: json['pinHash'] != null,
      isOnline: json['isOnline'] ?? false,        // ✅ Parse from backend
      isReturning: json['isReturning'] ?? false,  // ✅ Parse from backend
      upi: json['upi'],                           // ✅ Parse from backend
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'riderId': riderId,
      'phone': phone,
      'name': name,
      'role': role,
      'isVerified': isVerified,
      'avatar': avatar,
      'email': email,
      'hasPinSet': hasPinSet,
      'isOnline': isOnline,
      'isReturning': isReturning,
      'upi': upi,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? riderId,
    String? phone,
    String? name,
    String? role,
    bool? isVerified,
    String? avatar,
    String? email,
    bool? hasPinSet,
    bool? isOnline,
    bool? isReturning,
    String? upi,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      avatar: avatar ?? this.avatar,
      email: email ?? this.email,
      hasPinSet: hasPinSet ?? this.hasPinSet,
      isOnline: isOnline ?? this.isOnline,
      isReturning: isReturning ?? this.isReturning,
      upi: upi ?? this.upi,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        name,
        role,
        isVerified,
        avatar,
        email,
        hasPinSet,
        isOnline,
        isReturning,
        upi,
        createdAt,
      ];
}
