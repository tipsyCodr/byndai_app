class AppConfig {
  static const String appName = 'ByndAI';
  static const String companyName = 'Path Idea InfoTech';
  static const String baseUrl = 'https://app.byndai.in';
  static const String apiBaseUrl = '$baseUrl/api';
  static const String apiProfileImg = "$baseUrl/storage";
  static const String imageBaseUrl = baseUrl;
  static const String storageBaseUrl = "$baseUrl/storage";
  static const double roundness = 6;

  // ── AI Chatbot ──────────────────────────────────────────────────────────────
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String openAiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String openAiModel = 'gpt-4o-mini';

  /// Robust Laravel URL Rewriter
  static String? getFullUrl(String? path) {
    if (path == null || path.isEmpty) return null;

    String cleanPath = path.trim();

    // 1. If it's already a full HTTP URL, return as is
    if (cleanPath.startsWith('http')) {
      return cleanPath;
    }

    // 2. Handle paths that already contain the base URL parts
    if (cleanPath.contains('assets/uploads/') || cleanPath.startsWith('uploads/')) {
       if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
       return "$imageBaseUrl/$cleanPath";
    }

    if (cleanPath.contains('storage/')) {
      if (cleanPath.startsWith('storage/')) {
        return "$imageBaseUrl/$cleanPath";
      }
      if (cleanPath.startsWith('/storage/')) {
        return "$imageBaseUrl$cleanPath";
      }
      if (cleanPath.contains('public/storage/')) {
        cleanPath = 'storage/${cleanPath.split('public/storage/').last}';
        return "$imageBaseUrl/$cleanPath";
      }
    }

    // 3. Normalize leading slash
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    
    // 4. Final construction with /storage base for relative paths
    // If it doesn't have storage/ prefix, we assume it's a relative storage path (modern behavior)
    if (!cleanPath.startsWith('storage/')) {
       return "$apiProfileImg/$cleanPath";
    }

    return "$imageBaseUrl/$cleanPath";
  }
}