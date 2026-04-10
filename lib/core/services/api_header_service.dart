import 'package:gridcard/core/services/user_storage_service.dart';

class ApiHeaderService {
  /// Returns standard headers including Authorization Bearer token if available.
  static Future<Map<String, String>> getHeaders({bool isMultipart = false}) async {
    final token = await UserStorageService().getToken();
    
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
