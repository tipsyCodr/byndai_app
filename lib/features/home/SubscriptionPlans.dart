import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/auth_provider.dart';

/// A responsive widget that displays subscription pricing cards.
/// Cards wrap to the next line on smaller screens to avoid overflow.

class SubscriptionPlans extends StatefulWidget {
  const SubscriptionPlans({super.key});

  @override
  State<SubscriptionPlans> createState() => _SubscriptionPlansState();
}

class _SubscriptionPlansState extends State<SubscriptionPlans> {
  Future<void> startPayment(BuildContext context, PlanData plan) async {
    try {
      final userId = await UserStorageService().getUserId();

      final response = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/create-order"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "plan_id": getPlanId(plan.name),
        }),
      );

      final data = jsonDecode(response.body);

      final orderId = data["order_id"];
      final key = data["key"];
      final transactionId = data["transaction_id"];

      openRazorpay(context, key, orderId, transactionId);
    } catch (e) {
      print("Payment error: $e");
    }
  }

  int getPlanId(String name) {
    switch (name) {
      case "Starter":
        return 1;
      case "Growth":
        return 2;
      case "Scale":
        return 3;
      default:
        return 0;
    }
  }

  late Razorpay _razorpay;

  void openRazorpay(
      BuildContext context, String key, String orderId, int transactionId) {
    _razorpay = Razorpay();

    var options = {
      'key': key,
      'order_id': orderId,
      'name': 'GridCard',
      'description': 'Subscription Payment',
    };

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
      verifyPayment(context, response, transactionId);
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Payment Failed")),
      );
    });

    _razorpay.open(options);
  }

  Future<void> verifyPayment(
    BuildContext context,
    PaymentSuccessResponse response,
    int transactionId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("${AppConfig.apiBaseUrl}/verify-payment"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "transaction_id": transactionId,
          "razorpay_order_id": response.orderId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_signature": response.signature,
        }),
      );

      final data = jsonDecode(res.body);

      if (data["status"] == true) {
        // 🔥 IMPORTANT: subscription refresh
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.refreshSubscription();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Subscription Activated")),
        );

        Navigator.pop(context); // back to home
      }
    } catch (e) {
      print("Verify error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Choose Your Plan"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // _PlanCard(plan: PlanData.free),
            _PlanCard(
              plan: PlanData.free,
              onSelect: (plan) {},
            ),
            SizedBox(height: 16),
            // _PlanCard(plan: PlanData.starter),
            _PlanCard(
              plan: PlanData.starter,
              onSelect: (plan) => startPayment(context, plan),
            ),
            SizedBox(height: 16),
            // _PlanCard(plan: PlanData.growth),
            _PlanCard(
              plan: PlanData.growth,
              onSelect: (plan) => startPayment(context, plan),
            ),
            SizedBox(height: 16),
            // _PlanCard(plan: PlanData.scale),
            _PlanCard(
              plan: PlanData.scale,
              onSelect: (plan) => startPayment(context, plan),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for a subscription plan
class PlanData {
  final String name;
  final String monthlyPrice;
  final String? yearlyPrice;
  final String description;
  final String buttonText;
  final bool isPopular;
  final List<FeatureItem> features;

  const PlanData({
    required this.name,
    required this.monthlyPrice,
    this.yearlyPrice,
    required this.description,
    required this.buttonText,
    this.isPopular = false,
    required this.features,
  });

  // ---------- Predefined Plans ----------
  static const PlanData free = PlanData(
    name: 'Free Forever',
    monthlyPrice: '₹0',
    description: 'Get started with essential features',
    buttonText: 'Get Free Forever',
    features: FeatureItem.freeFeatures,
  );

  static const PlanData starter = PlanData(
    name: 'Starter',
    monthlyPrice: '₹2499',
    yearlyPrice: '₹24,999/yr',
    description: 'Perfect for small businesses getting started',
    buttonText: 'Get Starter',
    features: FeatureItem.starterFeatures,
  );

  static const PlanData growth = PlanData(
    name: 'Growth',
    monthlyPrice: '₹3999',
    yearlyPrice: '₹39,999/yr',
    description: 'Scale your messaging with advanced features',
    buttonText: 'Choose Growth',
    isPopular: true,
    features: FeatureItem.growthFeatures,
  );

  static const PlanData scale = PlanData(
    name: 'Scale',
    monthlyPrice: '₹4999',
    yearlyPrice: '₹49,999/yr',
    description: 'Perfect for scaling business',
    buttonText: 'Get Scale',
    features: FeatureItem.scaleFeatures,
  );
}

/// A single feature item (like "2 Users included")
class FeatureItem {
  final String label;
  final bool included;
  final bool isMultiLine; // for long integration lists

  const FeatureItem({
    required this.label,
    required this.included,
    this.isMultiLine = false,
  });

  // ---------- Feature Lists for each plan ----------
  static const List<FeatureItem> freeFeatures = [
    FeatureItem(label: '2 Users included', included: true),
    FeatureItem(label: '500 Contacts', included: true),
    FeatureItem(label: '5k Interactions/month', included: true),
    FeatureItem(label: 'API access', included: true),
    FeatureItem(label: 'Multi Channel', included: false),
    FeatureItem(
      label:
          'WhatsApp, FB Messenger, Instagram, Email, Google RCS (coming soon)',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: 'All products', included: false),
    FeatureItem(
      label: 'AI Mate, Zapier, ChatGPT, Facebook Leads Form',
      included: false,
      isMultiLine: true,
    ),
    FeatureItem(label: '30 Days Chat History', included: true),
  ];

  static const List<FeatureItem> starterFeatures = [
    FeatureItem(label: '3 Users included', included: true),
    FeatureItem(label: '2,000 Contacts', included: true),
    FeatureItem(label: '150k Interactions/month', included: true),
    FeatureItem(label: 'API access', included: true),
    FeatureItem(label: 'Multi Channel', included: false),
    FeatureItem(
      label:
          'WhatsApp, FB Messenger, Instagram, Email, Google RCS (coming soon)',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: 'All products', included: true),
    FeatureItem(
      label:
          'AI Mate, Zapier, ChatGPT, Facebook Leads Form, Razorpay, Stripe, PayU',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: '60 Days Chat History', included: true),
  ];

  static const List<FeatureItem> growthFeatures = [
    FeatureItem(label: '5 Users included', included: true),
    FeatureItem(label: '10,000 Contacts', included: true),
    FeatureItem(label: '500k Interactions/month', included: true),
    FeatureItem(label: 'API access', included: true),
    FeatureItem(label: 'Multi Channel', included: true),
    FeatureItem(
      label:
          'WhatsApp, FB Messenger, Instagram, Email, Google RCS (coming soon)',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: 'All products', included: true),
    FeatureItem(
      label:
          'AI Mate, Zapier, ChatGPT, Facebook Leads Form, Razorpay, Stripe, PayU',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: '180 Days Chat History', included: true),
  ];

  static const List<FeatureItem> scaleFeatures = [
    FeatureItem(label: '10 Users included', included: true),
    FeatureItem(label: '20,000 Contacts', included: true),
    FeatureItem(label: '1000k Interactions/month', included: true),
    FeatureItem(label: 'API access', included: true),
    FeatureItem(label: 'Multi Channel', included: true),
    FeatureItem(
      label:
          'WhatsApp, FB Messenger, Instagram, Email, Google RCS (coming soon)',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: 'All products', included: true),
    FeatureItem(
      label:
          'AI Mate, Zapier, ChatGPT, Facebook Leads Form, Razorpay, Stripe, PayU, Zoho CRM, Zendesk, WhatsMail',
      included: true,
      isMultiLine: true,
    ),
    FeatureItem(label: '365 Days Chat History', included: true),
  ];
}

/// Individual card widget
class _PlanCard extends StatelessWidget {
  final PlanData plan;
  final Function(PlanData) onSelect;

  const _PlanCard({
    required this.plan,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              plan.isPopular ? const Color(0xFFF5B041) : Colors.grey.shade200,
          width: plan.isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 HEADER
          Container(
            decoration: BoxDecoration(
              color:
                  plan.isPopular ? const Color(0xFFFFF3E0) : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B041),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Most Popular",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.monthlyPrice,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "/mo",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                if (plan.yearlyPrice != null)
                  Text(
                    "or ${plan.yearlyPrice}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(),

          // 🔥 FEATURES
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: plan.features.map((feature) {
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
                // onPressed: () async {
                //   if (plan.name == "Free Forever") return;

                //   Navigator.pushNamed(context, "/payment", arguments: plan);
                // },

                // onPressed: () async {
                //   if (plan.name == "Free Forever") {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(content: Text("Free plan already active")),
                //     );
                //     return;
                //   }

                //   // await startPayment(context, plan);
                //   onSelect(plan);
                // },

                onPressed: () async {
                  if (plan.name == "Free Forever") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Free plan already active")),
                    );
                    return;
                  }

                  onSelect(plan);
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      plan.isPopular ? const Color(0xFFF5B041) : Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(plan.buttonText),
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
              color: included ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: isMultiLine ? 1.4 : 1.3,
                color: included ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
