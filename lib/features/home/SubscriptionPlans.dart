import 'package:flutter/material.dart';

/// A responsive widget that displays subscription pricing cards.
/// Cards wrap to the next line on smaller screens to avoid overflow.
class SubscriptionPlans extends StatelessWidget {
  const SubscriptionPlans({super.key});

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
          children: const [
            _PlanCard(plan: PlanData.free),
            SizedBox(height: 16),
            _PlanCard(plan: PlanData.starter),
            SizedBox(height: 16),
            _PlanCard(plan: PlanData.growth),
            SizedBox(height: 16),
            _PlanCard(plan: PlanData.scale),
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

  const _PlanCard({required this.plan});

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected ${plan.name}')),
                  );
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
