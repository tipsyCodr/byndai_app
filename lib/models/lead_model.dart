// class LeadModel {
//   final int? id;
//   final String? name;
//   final String? company_name;
//   final String? mobile_no_1;
//   final String? mobile_no_2;
//   final String? mobile_no_3;
//   final String? email;
//   final String? email2;
//   final String? lead_image; // ✅ Add lead_image field
//   final String? image_filename; // ✅ Add image_filename field
//   final String? imageUrl;
//   final String? website;
//   final String? address;
//   final DateTime? createdAt;
//   final DateTime? updatedAt;
//   final String? leadImage;
//   final String? imageFilename;
  

//   LeadModel({
//     this.id,
//     this.name,
//     this.company_name,
//     this.mobile_no_1,
//     this.mobile_no_2,
//     this.mobile_no_3,
//     this.email,
//     this.email2,
//     this.lead_image, // ✅ Add to constructor
//     this.image_filename, // ✅ Add to constructor
//     this.imageUrl,
//     this.website,
//     this.address,
//     this.createdAt,
//     this.updatedAt,
//     this.leadImage,
//     this.imageFilename,
   
//   });

//   factory LeadModel.fromJson(Map<String, dynamic> json) {
//     return LeadModel(
//       id: json['id'],
//       name: json['name'],
//       company_name: json['company_name'],
//       mobile_no_1: json['mobile_no_1'],
//       mobile_no_2: json['mobile_no_2'],
//       mobile_no_3: json['mobile_no_3'],
//       email: json['email'],
//       email2: json['email2'],
//       lead_image: json['lead_image'], // ✅ Add from JSON
//       image_filename: json['image_filename'], // ✅ Add from JSON
//       imageUrl: json['image_url'],   
//       website: json['website'],
//       address: json['address'],
//       leadImage: json['lead_image'],
//       imageFilename: json['image_filename'],
     
//       createdAt:
//           json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
//       updatedAt:
//           json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       if (id != null) 'id': id,
//       'name': name,
//       'company_name': company_name,
//       'mobile_no_1': mobile_no_1,
//       'mobile_no_2': mobile_no_2,
//       'mobile_no_3': mobile_no_3,
//       'email': email,
//       'email2': email2,
//       'website': website,
//       'address': address,
//       'lead_image': leadImage,
//       'image_filename': imageFilename,
//       'image_url': imageUrl,
//       if (lead_image != null) 'lead_image': lead_image, // ✅ Add to JSON
//       if (image_filename != null) 'image_filename': image_filename, // ✅ Add to JSON
//     };
//   }
// }


class LeadModel {
  final int? id;
  final int? userId;                // ✅ NEW
  final String? name;
  final String? company_name;
  final String? category;            // ✅ NEW
  final String? mobile_no_1;
  final String? mobile_no_2;
  final String? mobile_no_3;
  final String? email;
  final String? email2;
  final String? lead_image;
  final String? image_filename;
  final String? selfy_image_1;       // ✅ NEW
  final String? selfy_image_2;       // ✅ NEW
  final String? selfy_video;         // ✅ NEW
  final String? imageUrl;
  final String? website;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? leadImage;            // existing duplicate
  final String? imageFilename;        // existing duplicate

  LeadModel({
    this.id,
    this.userId,                      // ✅ NEW
    this.name,
    this.company_name,
    this.category,                    // ✅ NEW
    this.mobile_no_1,
    this.mobile_no_2,
    this.mobile_no_3,
    this.email,
    this.email2,
    this.lead_image,
    this.image_filename,
    this.selfy_image_1,               // ✅ NEW
    this.selfy_image_2,               // ✅ NEW
    this.selfy_video,                 // ✅ NEW
    this.imageUrl,
    this.website,
    this.address,
    this.createdAt,
    this.updatedAt,
    this.leadImage,
    this.imageFilename,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'],
      userId: json['user_id'],                         // ✅ NEW
      name: json['name'],
      company_name: json['company_name'],
      category: json['category'],                       // ✅ NEW
      mobile_no_1: json['mobile_no_1'],
      mobile_no_2: json['mobile_no_2'],
      mobile_no_3: json['mobile_no_3'],
      email: json['email'],
      email2: json['email2'],
      lead_image: json['lead_image'],
      image_filename: json['image_filename'],
      selfy_image_1: json['selfy_image_1'],             // ✅ NEW
      selfy_image_2: json['selfy_image_2'],             // ✅ NEW
      selfy_video: json['selfy_video'],                 // ✅ NEW
      imageUrl: json['image_url'],
      website: json['website'],
      address: json['address'],
      leadImage: json['lead_image'],
      imageFilename: json['image_filename'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,                                 // ✅ NEW
      'name': name,
      'company_name': company_name,
      'category': category,                               // ✅ NEW
      'mobile_no_1': mobile_no_1,
      'mobile_no_2': mobile_no_2,
      'mobile_no_3': mobile_no_3,
      'email': email,
      'email2': email2,
      'website': website,
      'address': address,
      'lead_image': leadImage ?? lead_image,
      'image_filename': imageFilename ?? image_filename,
      'selfy_image_1': selfy_image_1,                     // ✅ NEW
      'selfy_image_2': selfy_image_2,                     // ✅ NEW
      'selfy_video': selfy_video,                         // ✅ NEW
      'image_url': imageUrl,
      if (lead_image != null) 'lead_image': lead_image,
      if (image_filename != null) 'image_filename': image_filename,
    };
  }
}