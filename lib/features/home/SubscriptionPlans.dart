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
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

/// A responsive widget that displays subscription pricing cards fetched from the API.
class SubscriptionPlans extends StatefulWidget {
  const SubscriptionPlans({super.key});

  @override
  State<SubscriptionPlans> createState() => _SubscriptionPlansState();
}

class _SubscriptionPlansState extends State<SubscriptionPlans> {
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final plans = await SubscriptionService.fetchAllPlans();
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> startPayment(
      BuildContext context, SubscriptionPlanModel plan) async {
    try {
      debugPrint("🔹 [Create Order] Requesting order for Plan ID: ${plan.id}");
      
      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/create-order"),
        headers: await _getHeaders(),
        body: jsonEncode({
          "plan_id": plan.id,
        }),
      );

      debugPrint("🔹 [Create Order] Status Code: ${response.statusCode}");
      debugPrint("🔹 [Create Order] Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ This plan is already active on your account.")),
        );
        return;
      }

      if (response.statusCode == 422) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ ${data["message"] ?? "Selected plan is unavailable."}")),
        );
        return;
      }

      if (data["order_id"] != null || data["status"] == true) {
        final key = data["key"];
        final orderId = data["order_id"];
        final transactionId = data["transaction_id"];
        
        // Use backend amount/currency if available, otherwise fallback to prevent crash
        // Note: Razorpay amount is in paise (e.g. 500.00 -> 50000)
        final amount = data["amount"] ?? (double.tryParse(plan.monthlyPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) * 100;
        final currency = data["currency"] ?? "INR";

        debugPrint("🟢 Opening Razorpay with Amount: $amount $currency");
        openRazorpay(context, key, orderId, transactionId, amount, currency);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ ${data["message"] ?? "Order creation failed"}")),
        );
      }
    } catch (e) {
      debugPrint("🚨 [Create Order] EXCEPTION: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: ${e.toString()}")),
        );
      }
    }
  }

  late Razorpay _razorpay;

  void openRazorpay(
    BuildContext context,
    String key,
    String orderId,
    int transactionId,
    dynamic amount,
    String currency,
  ) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Payment Cancelled or Failed")),
      );
    });

    _razorpay.open(options);
  }

  Future<void> verifyPayment(
    BuildContext context,
    PaymentSuccessResponse response,
    int transactionId,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            contentPadding: EdgeInsets.zero,
            content: Material(
              color: Colors.transparent,
              child: GlassBox(
                width: MediaQuery.of(context).size.width,
                borderRadius: 24,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 24),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Verifying Payment...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Please wait, we are activating\nyour subscription plan.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      debugPrint("🔹 [Payment Success] Transaction ID: $transactionId");
      debugPrint("🔹 [Razorpay] Order: ${response.orderId}, Payment: ${response.paymentId}");

      final url = Uri.parse("${AppConfig.apiBaseUrl}/verify-payment");
      debugPrint("🔹 Calling API: $url");

      final res = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "transaction_id": transactionId,
          "razorpay_order_id": response.orderId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_signature": response.signature,
        }),
      );

      debugPrint("🔹 API Status: ${res.statusCode}");
      debugPrint("🔹 API Response: ${res.body}");

      final data = jsonDecode(res.body);

      // Handle 400 Verification Failure
      if (res.statusCode == 400) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ ${data["message"] ?? "Payment mismatch or signature failed."}")),
        );
        return;
      }

      // Handle 500 Activation Pending
      if (res.statusCode == 500) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text("⌛ Payment received! Activation is taking longer than expected. Please don't pay again."),
          ),
        );
        Navigator.pop(context); // back to home
        return;
      }

      if (data["status"] == true) {
        debugPrint("✅ Payment verified successfully.");
        
        final auth = Provider.of<AuthProvider>(context, listen: false);
        
        // Attempt to refresh multiple times in case of backend lag
        bool success = false;
        for (int i = 1; i <= 3; i++) {
          final delay = i * 2; // 2s, 4s, 6s
          debugPrint("⏳ [Attempt $i] Waiting ${delay}s before refresh...");
          await Future.delayed(Duration(seconds: delay));
          
          await auth.refreshSubscription();
          
          if (auth.isPro) {
            debugPrint("✅ [Attempt $i] SUCCESS: User is now PRO.");
            success = true;
            break;
          } else {
            debugPrint("⚠️ [Attempt $i] User is still FREE. Retrying...");
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Subscription Activated!")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("⌛ Payment successful! Your plan will be active shortly.")),
            );
          }
          Navigator.pop(context); // back to home
        }
      } else {
        if (mounted) Navigator.pop(context); // Close loading dialog
        debugPrint("❌ Payment verification failed: ${data["message"]}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ ${data["message"] ?? "Verification Failed"}")),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      debugPrint("🚨 Exception in verifyPayment: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subscription = auth.subscriptionDetails;
    
    final int currentPlanId = int.tryParse(
      (subscription?['plan_id'] ?? subscription?['plan']?['id'] ?? '0').toString()
    ) ?? 0;
    
    

    final palette = Theme.of(context).extension<AppThemeColors>();
    final colorScheme = Theme.of(context).colorScheme;
    
    // Filter: Always hide the FREE plan from the upgrade list
    final filteredPlans = _plans.where((p) => !p.isFree).toList();

    return Scaffold(
      backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
      appBar: AppBar(
        title: const Text("Choose Your Plan"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette?.backgroundStart ?? colorScheme.surface,
              palette?.backgroundMid ?? colorScheme.surface,
              palette?.backgroundEnd ?? colorScheme.surface,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredPlans.isEmpty
                ? const Center(child: Text("No plans available at the moment."))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: filteredPlans.map((plan) {
                      final bool isActive = plan.id == currentPlanId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PlanCard(
                          plan: plan,
                          isActive: isActive,
                          onSelect: (p) {
                            if (isActive) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("This plan is already active")),
                              );
                              return;
                            }
                            
                            if (p.monthlyPrice == '0' ||
                                p.monthlyPrice == '₹0' ||
                                p.monthlyPrice.contains('Free')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Free plan already active")),
                              );
                              return;
                            }
                            startPayment(context, p);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
    );
  }
}

/// Individual card widget
class _PlanCard extends StatelessWidget {
  final SubscriptionPlanModel plan;
  final bool isActive;
  final Function(SubscriptionPlanModel) onSelect;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardColor = isActive 
        ? Colors.green 
        : (plan.isPopular ? colorScheme.secondary : colorScheme.onSurface.withValues(alpha: 0.1));

    return GlassBox(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      opacity: isDark ? 0.05 : 0.08,
      border: Border.all(
        color: cardColor.withValues(alpha: (plan.isPopular || isActive) ? 0.5 : 0.2),
        width: (plan.isPopular || isActive) ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER
          Container(
            decoration: BoxDecoration(
              color: isActive 
                  ? Colors.green.withValues(alpha: 0.1)
                  : (plan.isPopular ? colorScheme.secondary.withValues(alpha: 0.1) : Colors.transparent),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive || plan.isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : colorScheme.secondary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? "Active Plan" : "Most Popular",
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? Colors.white : colorScheme.onSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.monthlyPrice.startsWith('₹')
                          ? plan.monthlyPrice
                          : '₹${plan.monthlyPrice}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "/mo",
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                if (plan.yearlyPrice != null)
                  Text(
                    "or ${plan.yearlyPrice!.startsWith('₹') ? plan.yearlyPrice : '₹${plan.yearlyPrice}'}",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                const SizedBox(height: 6),
                if (plan.description != null)
                  Text(
                    plan.description!,
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),

          Divider(color: colorScheme.onSurface.withValues(alpha: 0.1)),

          // 🔥 FEATURES
          if (plan.features != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: plan.features!.map((feature) {
                  return _FeatureRow(
                    label: feature.label,
                    included: feature.included,
                    isMultiLine: feature.isMultiLine,
                  );
                }).toList(),
              ),
            ),

          // 🔥 BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onSelect(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? Colors.green.withValues(alpha: 0.1)
                      : (plan.isPopular ? colorScheme.secondary : colorScheme.primary),
                  foregroundColor: isActive 
                      ? Colors.green 
                      : (plan.isPopular ? colorScheme.onSecondary : colorScheme.onPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: isActive ? 0 : 4,
                  shadowColor: plan.isPopular ? colorScheme.secondary.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: isActive ? const BorderSide(color: Colors.green) : BorderSide.none,
                  ),
                ),
                child: Text(
                  isActive 
                      ? "Active" 
                      : (plan.buttonText ?? (plan.monthlyPrice == '0' ? 'Get Free Forever' : 'Get Started')),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row displaying a single feature with check/cross icon
class _FeatureRow extends StatelessWidget {
  final String label;
  final bool included;
  final bool isMultiLine;

  const _FeatureRow({
    required this.label,
    required this.included,
    this.isMultiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              included ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: included ? Colors.green : colorScheme.error.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: isMultiLine ? 1.4 : 1.3,
                color: included ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
