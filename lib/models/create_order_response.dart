class CreateOrderResponse {
  final bool status;
  final String message;
  final String? orderId;
  final String? key;
  final int? transactionId;
  final int? amountInPaisa;
  final String? currency;
  final double? originalPrice;
  final double? discountAmount;
  final double? finalAmount;
  final double? payableAmount;
  final bool couponApplied;
  final String couponValidationStatus;
  final String? couponCode;
  final String? referrerName;

  CreateOrderResponse({
    required this.status,
    required this.message,
    this.orderId,
    this.key,
    this.transactionId,
    this.amountInPaisa,
    this.currency,
    this.originalPrice,
    this.discountAmount,
    this.finalAmount,
    this.payableAmount,
    required this.couponApplied,
    required this.couponValidationStatus,
    this.couponCode,
    this.referrerName,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      orderId: json['order_id'],
      key: json['key'],
      transactionId: json['transaction_id'],
      amountInPaisa: json['amount'],
      currency: json['currency'],
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      finalAmount: (json['final_amount'] as num?)?.toDouble(),
      payableAmount: (json['payable_amount'] as num?)?.toDouble(),
      couponApplied: json['coupon_applied'] ?? false,
      couponValidationStatus: json['coupon_validation_status'] ?? 'not_provided',
      couponCode: json['coupon_code'],
      referrerName: json['referrer_name'],
    );
  }
}
