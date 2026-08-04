/// Business card data model with per-field confidence scores.
class BusinessCard {
  final String name;
  final String company;
  final String designation;
  final String mobile;
  final String alternateMobile;
  final String email;
  final String website;
  final String address;
  final String city;
  final String state;
  final String country;

  /// Confidence scores per field (0.0 – 1.0).
  /// Missing keys imply full confidence (1.0).
  final Map<String, double> confidence;

  const BusinessCard({
    this.name = '',
    this.company = '',
    this.designation = '',
    this.mobile = '',
    this.alternateMobile = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.confidence = const {},
  });

  factory BusinessCard.fromJson(Map<String, dynamic> json) {
    Map<String, double> conf = {};
    if (json['confidence'] is Map) {
      (json['confidence'] as Map).forEach((k, v) {
        conf[k.toString()] = (v as num?)?.toDouble() ?? 1.0;
      });
    }
    return BusinessCard(
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      alternateMobile: json['alternate_mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      confidence: conf,
    );
  }

  /// Maps the server `/gpt-ocr` response keys to [BusinessCard].
  ///
  /// Server returns: name, company_name, email, email2, website, address,
  ///                 mobile_no_1, mobile_no_2, mobile_no_3
  factory BusinessCard.fromServerJson(Map<String, dynamic> json) {
    return BusinessCard(
      name: json['name']?.toString() ?? '',
      company: json['company_name']?.toString() ?? '',
      designation: '',
      mobile: json['mobile_no_1']?.toString() ?? '',
      alternateMobile: json['mobile_no_2']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: '',
      state: '',
      country: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'company': company,
        'designation': designation,
        'mobile': mobile,
        'alternate_mobile': alternateMobile,
        'email': email,
        'website': website,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
      };

  /// Maps to the field keys expected by [ExtractedDataModal].
  Map<String, dynamic> toFormMap() => {
        'name': name,
        'company_name': company,
        'designation': designation,
        'mobile1': mobile,
        'mobile2': alternateMobile,
        'email1': email,
        'website': website,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
      };


  double confidenceFor(String field) => confidence[field] ?? 1.0;

  BusinessCard copyWith({
    String? name,
    String? company,
    String? designation,
    String? mobile,
    String? alternateMobile,
    String? email,
    String? website,
    String? address,
    String? city,
    String? state,
    String? country,
    Map<String, double>? confidence,
  }) =>
      BusinessCard(
        name: name ?? this.name,
        company: company ?? this.company,
        designation: designation ?? this.designation,
        mobile: mobile ?? this.mobile,
        alternateMobile: alternateMobile ?? this.alternateMobile,
        email: email ?? this.email,
        website: website ?? this.website,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        confidence: confidence ?? this.confidence,
      );
}
