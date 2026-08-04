class CouponValidationResponse {
  final bool status;
  final String message;
  final bool couponApplied;
  final String couponValidationStatus;
  final String? couponCode;
  final String? referrerName;
  final double? originalPrice;
  final double? discountAmount;
  final double? finalAmount;
  final double? payableAmount;

  CouponValidationResponse({
    required this.status,
    required this.message,
    required this.couponApplied,
    required this.couponValidationStatus,
    this.couponCode,
    this.referrerName,
    this.originalPrice,
    this.discountAmount,
    this.finalAmount,
    this.payableAmount,
  });

  factory CouponValidationResponse.fromJson(Map<String, dynamic> json) {
    return CouponValidationResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      couponApplied: json['coupon_applied'] ?? false,
      couponValidationStatus: json['coupon_validation_status'] ?? 'invalid',
      couponCode: json['coupon_code'],
      referrerName: json['referrer_name'],
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      finalAmount: (json['final_amount'] as num?)?.toDouble(),
      payableAmount: (json['payable_amount'] as num?)?.toDouble(),
    );
  }
}
