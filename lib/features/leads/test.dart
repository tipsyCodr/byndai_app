class LeadModel {
  final int? id;
  final String? name;
  final String? company_name;
  final String? mobile_no_1;
  final String? mobile_no_2;
  final String? mobile_no_3;
  final String? email;
  final String? email2;
  final String? website;
  final String? address; 
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeadModel({
    this.id,
    this.name,
    this.company_name,
    this.mobile_no_1,
    this.mobile_no_2,
    this.mobile_no_3,
    this.email,
    this.email2,
    this.website,
    this.address,  
    this.createdAt,
    this.updatedAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'],
      name: json['name'],
      company_name: json['company_name'],
      mobile_no_1: json['mobile_no_1'],
      mobile_no_2: json['mobile_no_2'],
      mobile_no_3: json['mobile_no_3'],
      email: json['email'],
      email2: json['email2'],
      website: json['website'],
      address: json['address'],     
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'company_name': company_name,
      'mobile_no_1': mobile_no_1,
      'mobile_no_2': mobile_no_2,
      'mobile_no_3': mobile_no_3,
      'email': email,
      'email2': email2,
      'website': website,
      'address': address,      
    };
  }
}
