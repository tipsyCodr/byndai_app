class CustomerMasterModel {
  final int? id;
  final String? name;
  final String? companyName;
  final String? phoneNo;
  final String? email;
  final String? website;
  final String? address;
  final String? otherDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerMasterModel({
    this.id,
    this.name,
    this.companyName,
    this.phoneNo,
    this.email,
    this.website,
    this.address,
    this.otherDetails,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerMasterModel.fromJson(Map<String, dynamic> json) {
    return CustomerMasterModel(
      id: json['id'],
      name: json['name'],
      companyName: json['company_name'],
      phoneNo: json['phone_no'],
      email: json['email'],
      website: json['website'],
      address: json['address'],
      otherDetails: json['other_details'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'company_name': companyName,
      'phone_no': phoneNo,
      'email': email,
      'website': website,
      'address': address,
      'other_details': otherDetails,
    };
  }
}
