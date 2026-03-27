class FeatureAccessHelper {
  /// 🔥 check feature limit (used <= limit)
  static bool canUseFeature({
    required int featureId,
    required Map<String, dynamic>? subscription,
  }) {
    if (subscription == null) return false;

    final features = subscription['features'];

    if (features == null || features is! List) return false;

    try {
      final feature = features.firstWhere(
        (f) => f['feature_id'] == featureId,
      );

      final int used = int.tryParse(feature['used_value'].toString()) ?? 0;
      final int limit = int.tryParse(feature['limit_value'].toString()) ?? 0;

      return used < limit; // ✅ main condition
    } catch (e) {
      return false; // feature not found
    }
  }
}