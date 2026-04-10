class FeatureAccessHelper {
  /// Checks feature usage against plan limit.
  /// Server convention: limit_value == -1 means unlimited usage.
  static bool canUseFeature({
    required int featureId,
    required Map<String, dynamic>? subscription,
  }) {
    // 🔥 DEBUG LOGGING
    // ignore: avoid_print
    print("🔍 FeatureAccessHelper: Checking featureId=$featureId");
    // ignore: avoid_print
    print("🔍 FeatureAccessHelper: Subscription data is ${subscription == null ? 'NULL' : 'PRESENT'}");

    if (subscription == null) return false;

    final features = subscription['features'];
    // ignore: avoid_print
    print("🔍 FeatureAccessHelper: Features list from API: $features");

    if (features == null || features is! List) {
      // ignore: avoid_print
      print("⚠️ FeatureAccessHelper: Features list is NULL or not a list!");
      return false;
    }

    try {
      final feature = features.firstWhere(
        (f) => 
            f['feature_id']?.toString() == featureId.toString() ||
            f['id']?.toString() == featureId.toString(),
      );

      // ignore: avoid_print
      print("✅ FeatureAccessHelper: Found feature entry: $feature");

      final usedRaw = feature['used_value'] ?? feature['used'];
      final limitRaw = feature['limit_value'] ?? feature['limit'];

      final int used = int.tryParse(usedRaw.toString()) ?? 0;
      final int limit = int.tryParse(limitRaw.toString()) ?? 0;

      // ignore: avoid_print
      print("📊 FeatureAccessHelper: used=$used, limit=$limit");

      if (limit == -1) return true; // unlimited
      return used < limit;
    } catch (e) {
      // ignore: avoid_print
      print("❌ FeatureAccessHelper: Feature ID $featureId NOT FOUND in features list.");
      return false; 
    }
  }
}