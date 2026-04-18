import 'master_user.dart';

class UserModel {
  final int? id;
  final String? userMobile;
  final String? userName;
  final String? email;
  final String? pin;
  final String? otp;
  final String? status;
  final String? profilePic;
  final String? profileLogo;
  final MasterUser? masterUser;

  UserModel({
    this.id,
    this.userMobile,
    this.userName,
    this.email,
    this.pin,
    this.otp,
    this.status,
    this.profilePic,
    this.profileLogo,
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
      profilePic: json['profile_pic'],
      profileLogo: json['profile_logo'],
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
      'profile_pic': profilePic,
      'profile_logo': profileLogo,
      'master_user': masterUser?.toJson(),
    };
  }
}
