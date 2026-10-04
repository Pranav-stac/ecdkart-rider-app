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
  final String? riderId;      // Driver ID (e.g. DRV-1234 or MongoDB ObjectId)
  final String phone;
  final String? name;
  final String role;
  final bool isVerified;
  final String? avatar;
  final String? email;
  final bool hasPinSet;
  final bool isOnline;        // Driver online status
  final bool isReturning;     // Driver returning to store
  final String? upi;          // Driver UPI payment identifier
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
    this.isOnline = false,
    this.isReturning = false,
    this.upi,
    required this.createdAt,
  });

  factory UserModel.fromJson(dynamic rawJson) {
    if (rawJson == null) {
      return UserModel(
        id: 'RIDER_${DateTime.now().millisecondsSinceEpoch}',
        phone: '',
        name: 'Rider Partner',
        role: 'driver',
        isVerified: true,
        hasPinSet: false,
        isOnline: false,
        isReturning: false,
        createdAt: DateTime.now(),
      );
    }

    final Map<String, dynamic> json = rawJson is Map<String, dynamic>
        ? rawJson
        : Map<String, dynamic>.from(rawJson as Map);

    final rawUser = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null;
    final rawRider = json['rider'] is Map ? Map<String, dynamic>.from(json['rider'] as Map) : null;
    final rawData = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null;

    final id = json['id'] ??
        json['_id'] ??
        rawUser?['_id'] ??
        rawUser?['id'] ??
        rawRider?['_id'] ??
        rawData?['_id'] ??
        rawData?['id'] ??
        'RIDER_${DateTime.now().millisecondsSinceEpoch}';

    final riderId = json['riderId']?.toString() ??
        rawRider?['_id']?.toString() ??
        rawData?['riderId']?.toString() ??
        (json['rider'] is String ? json['rider'].toString() : null);

    final phone = json['phone']?.toString() ??
        json['mobile']?.toString() ??
        rawUser?['phone']?.toString() ??
        rawUser?['mobile']?.toString() ??
        rawRider?['phone']?.toString() ??
        rawRider?['mobile']?.toString() ??
        rawData?['phone']?.toString() ??
        rawData?['mobile']?.toString() ??
        '';

    final name = json['name']?.toString() ??
        rawUser?['name']?.toString() ??
        rawRider?['name']?.toString() ??
        rawData?['name']?.toString() ??
        'Rider Partner';

    final role = json['role']?.toString() ??
        rawUser?['role']?.toString() ??
        rawData?['role']?.toString() ??
        'driver';

    final vStatus = (json['verificationStatus'] ??
            rawRider?['verificationStatus'] ??
            rawData?['verificationStatus'] ??
            (json['isVerified'] == true ? 'approved' : 'pending'))
        .toString()
        .toLowerCase();

    final bool isVerified = (vStatus == 'approved' ||
            vStatus == 'verified' ||
            json['isVerified'] == true ||
            rawUser?['isVerified'] == true ||
            json['riderVerified'] == true ||
            rawRider?['riderVerified'] == true) &&
        vStatus != 'rejected';

    final avatar = json['avatar']?.toString() ??
        json['profilePic']?.toString() ??
        rawUser?['profilePic']?.toString() ??
        rawUser?['avatar']?.toString() ??
        rawData?['profilePic']?.toString();

    final email = json['email']?.toString() ??
        rawUser?['email']?.toString() ??
        rawData?['email']?.toString();

    final hasPinSet = json['pinHash'] != null ||
        json['hasPin'] == true ||
        json['hasPinSet'] == true ||
        rawUser?['pinHash'] != null ||
        rawData?['hasPin'] == true;

    final isOnline = isVerified && (
        json['isOnline'] == true ||
        rawRider?['isOnline'] == true ||
        rawData?['isOnline'] == true
    );

    final isExplicitNewUser = json['isNewUser'] == true ||
        rawUser?['isNewUser'] == true ||
        rawData?['isNewUser'] == true;

    final isReturning = !isExplicitNewUser && (
        json['isReturning'] == true ||
        rawUser?['isReturning'] == true ||
        rawRider?['isReturning'] == true ||
        rawData?['isReturning'] == true ||
        json['isRegistered'] == true ||
        rawUser?['isRegistered'] == true ||
        json['isNewUser'] == false ||
        rawUser?['isNewUser'] == false ||
        (name.isNotEmpty && !name.toLowerCase().startsWith('rider ') && name.toLowerCase() != 'new partner') ||
        (phone.isNotEmpty && (riderId != null && riderId.isNotEmpty))
    );

    final upi = json['upi']?.toString() ??
        json['upiId']?.toString() ??
        json['bankDetails']?['upiId']?.toString() ??
        json['bankDetails']?['upi']?.toString() ??
        rawRider?['bankDetails']?['upiId']?.toString() ??
        rawRider?['bankDetails']?['upi']?.toString() ??
        rawRider?['upiId']?.toString() ??
        rawRider?['upi']?.toString() ??
        rawUser?['bankDetails']?['upiId']?.toString() ??
        rawUser?['upi']?.toString() ??
        rawData?['upi']?.toString() ??
        rawData?['bankDetails']?['upiId']?.toString();

    DateTime parsedDate = DateTime.now();
    final dateStr = json['createdAt'] ?? rawUser?['createdAt'] ?? rawData?['createdAt'];
    if (dateStr != null) {
      parsedDate = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
    }

    return UserModel(
      id: id.toString(),
      riderId: riderId,
      phone: phone,
      name: name,
      role: role,
      isVerified: isVerified,
      avatar: avatar,
      email: email,
      hasPinSet: hasPinSet,
      isOnline: isOnline,
      isReturning: isReturning,
      upi: upi,
      createdAt: parsedDate,
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
        riderId,
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
