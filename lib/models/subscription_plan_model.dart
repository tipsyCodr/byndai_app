class SubscriptionPlanModel {
  final int id;
  final String name;
  final String monthlyPrice;
  final String? yearlyPrice;
  final String? description;
  final String? buttonText;
  final bool isPopular;
  final bool isFree;
  final List<SubscriptionFeatureModel>? features;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    this.yearlyPrice,
    this.description,
    this.buttonText,
    this.isPopular = false,
    this.isFree = false,
    this.features,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      monthlyPrice: json['monthly_price']?.toString() ?? json['price']?.toString() ?? '0',
      yearlyPrice: json['yearly_price']?.toString(),
      description: json['description'],
      buttonText: json['button_text'],
      isPopular: json['is_popular'] == 1 || json['is_popular'] == true,
      isFree: json['is_free'] == 1 || json['is_free'] == true,
      features: json['features'] != null
          ? (json['features'] as List)
              .map((i) => SubscriptionFeatureModel.fromJson(i))
              .toList()
          : null,
    );
  }
}

class SubscriptionFeatureModel {
  final int id;
  final String label;
  final bool included;
  final bool isMultiLine;

  SubscriptionFeatureModel({
    required this.id,
    required this.label,
    required this.included,
    this.isMultiLine = false,
  });

  factory SubscriptionFeatureModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeatureModel(
      id: json['id'] ?? 0,
      label: json['label'] ?? json['name'] ?? '',
      included: json['included'] == 1 || json['included'] == true || json['pivot']?['included'] == 1,
      isMultiLine: json['is_multi_line'] == 1 || json['is_multi_line'] == true,
    );
  }
}
