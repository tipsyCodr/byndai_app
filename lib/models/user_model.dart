import 'master_user.dart';

class UserModel {
  final int? id;
  final String? userMobile;
  final String? userName;
  final String? email;
  final String? pin;
  final String? otp;
  final String? status;
  final MasterUser? masterUser;

  UserModel({
    this.id,
    this.userMobile,
    this.userName,
    this.email,
    this.pin,
    this.otp,
    this.status,
    this.masterUser,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      userMobile: json['user_mobile'],
      userName: json['user_name'],
      email: json['email'],
      pin: json['pin'],
      otp: json['otp']?.toString(),
      status: json['status'],
      masterUser: json['master_user'] != null
          ? MasterUser.fromJson(json['master_user'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_mobile': userMobile,
      'user_name': userName,
      'email': email,
      'pin': pin,
      'otp': otp,
      'status': status,
      'master_user': masterUser?.toJson(),
    };
  }
}
