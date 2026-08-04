import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/subscription_service.dart';
import 'package:gridcard/models/subscription_plan_model.dart';
import 'package:gridcard/models/coupon_response.dart';
import 'package:gridcard/models/create_order_response.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

/// A responsive widget that displays subscription pricing cards in a premium horizontal carousel.
class SubscriptionPlans extends StatefulWidget {
  final bool isEmbedded;
  const SubscriptionPlans({super.key, this.isEmbedded = false});

  @override
  State<SubscriptionPlans> createState() => _SubscriptionPlansState();
}

class _SubscriptionPlansState extends State<SubscriptionPlans> {
  List<SubscriptionPlanModel> _plans = [];
  List<int> _queuedPlanIds = [];
  bool _isLoading = true;
  bool _isMonthly = false;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(viewportFraction: widget.isEmbedded ? 0.98 : 0.85);
    _fetchPlans();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    final results = await Future.wait([
      SubscriptionService.fetchAllPlans(),
      SubscriptionService.fetchQueuedPlanIds(),
    ]);

    if (mounted) {
      setState(() {
        _plans = results[0] as List<SubscriptionPlanModel>;
        _queuedPlanIds = results[1] as List<int>;
        _isLoading = false;
      });
    }
  }

  List<SubscriptionPlanModel> get filteredPlans {
    final type = _isMonthly ? 'monthly' : 'yearly';
    // Hide free plans from the upgrade carousel
    final filtered =
        _plans.where((p) => p.type.toLowerCase() == type && !p.isFree).toList();
    return filtered.isNotEmpty
        ? filtered
        : _plans.where((p) => !p.isFree).toList();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Apply Coupon Code API
  Future<CouponValidationResponse?> applyCoupon(
      int planId, String couponCode) async {
    try {
      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/apply-coupon"),
        headers: await _getHeaders(),
        body: jsonEncode({
          "plan_id": planId,
          "coupon_code": couponCode.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      return CouponValidationResponse.fromJson(data);
    } catch (e) {
      return CouponValidationResponse(
        status: false,
        message: "Failed to validate coupon: ${e.toString()}",
        couponApplied: false,
        couponValidationStatus: "error",
      );
    }
  }

  /// Create Razorpay order with optional coupon code
  Future<void> startPayment(BuildContext context, SubscriptionPlanModel plan,
      {String? couponCode}) async {
    try {
      final bodyData = <String, dynamic>{
        "plan_id": plan.id,
      };
      if (couponCode != null && couponCode.trim().isNotEmpty) {
        bodyData["coupon_code"] = couponCode.trim();
      }

      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/create-order"),
        headers: await _getHeaders(),
        body: jsonEncode(bodyData),
      );

      final data = jsonDecode(response.body);
      final createOrderRes = CreateOrderResponse.fromJson(data);

      if (!mounted) return;

      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("⚠️ This plan is already active on your account.")),
        );
        return;
      }

      if (createOrderRes.orderId != null || createOrderRes.status == true) {
        final key = createOrderRes.key ?? data["key"];
        final orderId = createOrderRes.orderId ?? data["order_id"];
        final transactionId =
            createOrderRes.transactionId ?? data["transaction_id"];
        final amount = createOrderRes.amountInPaisa ??
            data["amount"] ??
            (double.tryParse(
                        plan.monthlyPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                    0) *
                100;
        final currency = createOrderRes.currency ?? data["currency"] ?? "INR";

        openRazorpay(context, key, orderId, transactionId, amount, currency);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "❌ ${createOrderRes.message.isNotEmpty ? createOrderRes.message : "Order creation failed"}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: ${e.toString()}")),
        );
      }
    }
  }

  late Razorpay _razorpay;

  void openRazorpay(BuildContext context, String key, String orderId,
      int transactionId, dynamic amount, String currency) {
    _razorpay = Razorpay();
    final authUser = context.read<AuthProvider>().user;

    var options = {
      'key': key,
      'amount': amount,
      'currency': currency,
      'order_id': orderId,
      'name': AppConfig.appName,
      'description': 'Subscription Plan',
      'prefill': {
        'contact': authUser?.userMobile ?? '',
        'email': authUser?.email ?? '',
      },
    };

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
      verifyPayment(context, response, transactionId);
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Payment Cancelled or Failed")));
      }
    });

    _razorpay.open(options);
  }

  Future<void> verifyPayment(BuildContext context,
      PaymentSuccessResponse response, int transactionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassBox(
          borderRadius: 24,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Color(0xFFE4FF1A)),
              SizedBox(height: 24),
              Text("Verifying Payment...",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/verify-payment"),
        headers: await _getHeaders(),
        body: jsonEncode({
          "transaction_id": transactionId,
          "razorpay_order_id": response.orderId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_signature": response.signature,
        }),
      );

      final data = jsonDecode(res.body);

      if (!mounted) return;

      if (data["status"] == true) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.refreshSubscription();

        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Plan queued successfully!")));
          Navigator.pop(context); // Back to home
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("❌ ${data["message"] ?? "Verification Failed"}")));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subscription = auth.subscriptionDetails;

    final int currentPlanId = int.tryParse(
            (subscription?['plan_id'] ?? subscription?['plan']?['id'] ?? '0')
                .toString()) ??
        0;
    final int upcomingPlanId = int.tryParse(
            (subscription?['upcoming']?['next_plan']?['id'] ?? '0')
                .toString()) ??
        0;

    final currentFilteredPlans = filteredPlans;

    final colorScheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<AppThemeColors>();

    final plansContent = _isLoading
        ? Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(color: colorScheme.primary)))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: widget.isEmbedded ? 4 : 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isEmbedded ? "Available Plans" : "Pricing",
                      style: TextStyle(
                        fontSize: widget.isEmbedded ? 22 : 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (widget.isEmbedded)
                      Container(
                        height: 36,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _buildToggleButton("Annual", !_isMonthly),
                            _buildToggleButton("Monthly", _isMonthly),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: widget.isEmbedded ? 4 : 24),
                child: Row(
                  children: List.generate(
                    currentFilteredPlans.length,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 830,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: currentFilteredPlans.length,
                  itemBuilder: (context, index) {
                    final plan = currentFilteredPlans[index];
                    final bool isActive = plan.id == currentPlanId;
                    final bool isUpcoming = plan.id == upcomingPlanId ||
                        _queuedPlanIds.contains(plan.id);

                    final List<SubscriptionFeatureModel> displayFeatures;
                    if (plan.description != null &&
                        plan.description!.contains('\n')) {
                      displayFeatures = plan.description!
                          .split('\n')
                          .where((s) => s.trim().isNotEmpty)
                          .map((s) => SubscriptionFeatureModel(
                              id: 0, label: s.trim(), included: true))
                          .toList();
                    } else if (plan.features != null &&
                        plan.features!.isNotEmpty) {
                      displayFeatures = plan.features!;
                    } else {
                      displayFeatures = _getHardcodedFeatures(plan.isFree);
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: widget.isEmbedded ? 2 : 8),
                      child: _PlanCard(
                        plan: plan,
                        isActive: isActive,
                        isUpcoming: isUpcoming,
                        isHighlighted: index == _currentPage,
                        features: displayFeatures,
                        onApplyCoupon: (planId, couponCode) =>
                            applyCoupon(planId, couponCode),
                        onSelect: (p, couponCode) {
                          if (isActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("This plan is already active")));
                            return;
                          }
                          if (isUpcoming) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "This plan is already in your queue")));
                            return;
                          }
                          startPayment(context, p, couponCode: couponCode);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          );

    if (widget.isEmbedded) {
      return plansContent;
    }

    return Scaffold(
      backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _buildToggleButton("Annual", !_isMonthly),
                  _buildToggleButton("Monthly", _isMonthly),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: plansContent,
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _isMonthly = label == "Monthly"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<SubscriptionFeatureModel> _getHardcodedFeatures(bool isFree) {
    final features = [
      "AI Business Card Scanner",
      "Unlimited Digital Business Cards",
      "Smart QR Code Networking",
      "AI-Powered Lead Management",
      "Export Leads to CSV",
      "Greeting & Promotional Flyer Creator",
      "Public Mini Business Website",
      "Business Profile & Service Showcase",
      "Professional Business Presence",
      "Smart Contact Organization",
      "Social Media Ready Flyers",
    ];

    return features.asMap().entries.map((entry) {
      // For free plan, only first 3 features are included as a demo
      bool included = !isFree || entry.key < 3;
      return SubscriptionFeatureModel(
        id: entry.key,
        label: entry.value,
        included: included,
      );
    }).toList();
  }
}

class _PlanCard extends StatefulWidget {
  final SubscriptionPlanModel plan;
  final bool isActive;
  final bool isUpcoming;
  final bool isHighlighted;
  final List<SubscriptionFeatureModel> features;
  final Future<CouponValidationResponse?> Function(
      int planId, String couponCode) onApplyCoupon;
  final Function(SubscriptionPlanModel plan, String? couponCode) onSelect;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.isUpcoming,
    required this.isHighlighted,
    required this.features,
    required this.onApplyCoupon,
    required this.onSelect,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  final TextEditingController _couponController = TextEditingController();
  CouponValidationResponse? _appliedCoupon;
  bool _isApplyingCoupon = false;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _handleApplyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    final response = await widget.onApplyCoupon(widget.plan.id, code);

    if (mounted) {
      setState(() {
        _isApplyingCoupon = false;
        if (response != null && response.status && response.couponApplied) {
          _appliedCoupon = response;
          _couponError = null;
        } else {
          _appliedCoupon = null;
          _couponError = response?.message.isNotEmpty == true
              ? response!.message
              : "Invalid or inactive coupon code";
        }
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryAccent = colorScheme.primary;

    // Calculate savings
    int? savePercent;
    if (widget.plan.regularPrice != null) {
      final regular = double.tryParse(
              widget.plan.regularPrice!.replaceAll('₹', '').trim()) ??
          0;
      final current = double.tryParse(
              widget.plan.monthlyPrice.replaceAll('₹', '').trim()) ??
          0;
      if (regular > current) {
        savePercent = (((regular - current) / regular) * 100).round();
      }
    }

    final double displayPrice = _appliedCoupon?.payableAmount ??
        (double.tryParse(widget.plan.monthlyPrice.replaceAll('₹', '').trim()) ??
            0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF2E2612), const Color(0xFF1D180B)]
          : [const Color(0xFFFFFDF2), const Color(0xFFFFF3CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const goldBorderColor = Color(0xFFD4AF37);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: goldGradient,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: widget.isHighlighted
                  ? const Color(0xFFFFD700)
                  : goldBorderColor.withValues(alpha: 0.6),
              width: widget.isHighlighted ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37)
                    .withValues(alpha: isDark ? 0.25 : 0.18),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.plan.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.isActive ||
                              widget.plan.isPopular ||
                              widget.isUpcoming)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.isActive
                                    ? Colors.green
                                    : widget.isUpcoming
                                        ? Colors.orange
                                        : primaryAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.isActive
                                    ? "Active"
                                    : widget.isUpcoming
                                        ? "Queued"
                                        : "Popular",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: (widget.isActive || widget.isUpcoming)
                                      ? Colors.white
                                      : colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (savePercent != null) const SizedBox(width: 80),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (_appliedCoupon != null) ...[
                              Text(
                                "₹${_appliedCoupon!.originalPrice?.toStringAsFixed(0) ?? widget.plan.monthlyPrice}",
                                style: TextStyle(
                                  fontSize: 24,
                                  decoration: TextDecoration.lineThrough,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  decorationColor: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ] else if (widget.plan.regularPrice != null &&
                                (double.tryParse(widget.plan.regularPrice!
                                            .replaceAll('₹', '')
                                            .trim()) ??
                                        0) >
                                    (double.tryParse(widget.plan.monthlyPrice
                                            .replaceAll('₹', '')
                                            .trim()) ??
                                        0)) ...[
                              Text(
                                widget.plan.regularPrice!.startsWith('₹')
                                    ? widget.plan.regularPrice!
                                    : "₹${widget.plan.regularPrice}",
                                style: TextStyle(
                                  fontSize: 24,
                                  decoration: TextDecoration.lineThrough,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  decorationColor: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              "₹${displayPrice.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: primaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "${widget.plan.type.toLowerCase() == 'yearly' ? '/ year' : '/ month'} (INR)",
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 12),
                          ),
                          if (widget.plan.type.toLowerCase() == 'yearly') ...[
                            const SizedBox(width: 8),
                            Text(
                              "billed yearly",
                              style: TextStyle(
                                color: primaryAccent.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.plan.description != null &&
                          !widget.plan.description!.contains('\n'))
                        Text(
                          widget.plan.description!,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                      color: colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...widget.features.map((feature) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  feature.included
                                      ? Icons.check_circle
                                      : Icons.close,
                                  size: 20,
                                  color: feature.included
                                      ? primaryAccent
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.2),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    feature.label,
                                    style: TextStyle(
                                      color: feature.included
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 16),
                        // Coupon Code Section
                        if (!widget.isActive && !widget.isUpcoming) ...[
                          Divider(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.1)),
                          const SizedBox(height: 12),
                          if (_appliedCoupon != null &&
                              _appliedCoupon!.couponApplied) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.discount,
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Coupon '${_appliedCoupon!.couponCode}' Applied",
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (_appliedCoupon!.referrerName !=
                                            null)
                                          Text(
                                            "Referrer: ${_appliedCoupon!.referrerName}",
                                            style: TextStyle(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        if (_appliedCoupon!.discountAmount !=
                                            null)
                                          Text(
                                            "Saved ₹${_appliedCoupon!.discountAmount!.toStringAsFixed(0)}",
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.redAccent, size: 18),
                                    onPressed: _removeCoupon,
                                    tooltip: "Remove coupon",
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: _couponController,
                                      style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 13),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: "Have a Coupon Code?",
                                        hintStyle: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                          fontSize: 13,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                        filled: true,
                                        fillColor: colorScheme.onSurface
                                            .withValues(alpha: 0.05),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isApplyingCoupon
                                        ? null
                                        : _handleApplyCoupon,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryAccent,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                    ),
                                    child: _isApplyingCoupon
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          )
                                        : const Text("Apply",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                            if (_couponError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                "⚠️ $_couponError",
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 11),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => widget.onSelect(
                          widget.plan, _appliedCoupon?.couponCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isActive
                            ? colorScheme.onSurface.withValues(alpha: 0.1)
                            : colorScheme.onSurface,
                        foregroundColor: widget.isActive
                            ? colorScheme.onSurface
                            : colorScheme.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text(
                        widget.isActive
                            ? "Current Plan"
                            : widget.isUpcoming
                                ? "Queued"
                                : (widget.plan.buttonText ?? "Get Started"),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (savePercent != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: primaryAccent,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomLeft: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Save $savePercent%",
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.circle, size: 4, color: colorScheme.onPrimary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
