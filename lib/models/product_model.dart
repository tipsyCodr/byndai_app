class ProductModel {
  final int id;
  final String name;
  final double price;
  final String description;
  final List<String> images;
  final List<String> titleLinks;
  final List<String> links;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.images = const [],
    this.titleLinks = const [],
    this.links = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['product_name'] ?? '',
      price: double.tryParse(json['product_price']?.toString() ?? '0') ?? 0.0,
      description: json['description'] ?? '',
      images: (json['product_images'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      titleLinks:
          (json['title_links'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      links: (json['links'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': name,
      'product_price': price,
      'description': description,
      'product_images': images,
      'title_links': titleLinks,
      'links': links,
    };
  }
}
