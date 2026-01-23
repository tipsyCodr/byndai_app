
class MasterUser {
  final int? empId;
  final String? fname;
  final String? mobileOne;
  final String? emailOne;

  MasterUser({
    this.empId,
    this.fname,
    this.mobileOne,
    this.emailOne,
  });

  factory MasterUser.fromJson(Map<String, dynamic> json) {
    return MasterUser(
      empId: json['emp_id'],
      fname: json['fname'],
      mobileOne: json['mobile_one'],
      emailOne: json['email_one'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': empId,
      'fname': fname,
      'mobile_one': mobileOne,
      'email_one': emailOne,
    };
  }
}
