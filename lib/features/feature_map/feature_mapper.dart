class FeatureMapper {
  static const Map<String, int> _featureMap = {
    'connection_request_send': 1,
    'connection_request_accept': 2,
    'leads_create': 3,    
    'profile_view': 5,
    'ai_generated_feedback': 6,
    'create-flyer': 7,
    'mini-website': 8,
    'product_short_videos': 9,
  };

  /// 🔥 Get feature_id by key
  static int? getFeatureId(String key) {
    return _featureMap[key];
  }

  /// (Optional) reverse mapping bhi
  static String? getFeatureKey(int id) {
    try {
      return _featureMap.entries
          .firstWhere((entry) => entry.value == id)
          .key;
    } catch (e) {
      return null;
    }
  }
}