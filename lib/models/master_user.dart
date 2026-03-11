class MasterUser {
  final int? empId;
  final String? fname;
  final String? mobileOne;
  final String? emailOne;
  final String? profilePic;
  final String? profileLogo;

  MasterUser({
    this.empId,
    this.fname,
    this.mobileOne,
    this.emailOne,
    this.profilePic,
    this.profileLogo,
  });

  factory MasterUser.fromJson(Map<String, dynamic> json) {
    return MasterUser(
      empId: json['emp_id'],
      fname: json['fname'],
      mobileOne: json['mobile_one'],
      emailOne: json['email_one'],
      profilePic: json['profile_pic'],
      profileLogo: json['profile_logo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      'fname': fname,
      'mobile_one': mobileOne,
      'email_one': emailOne,
      'profile_pic': profilePic,
      'profile_logo': profileLogo,
    };
  }
}
