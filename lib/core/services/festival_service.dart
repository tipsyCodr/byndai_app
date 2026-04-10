import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gridcard/config/app_config.dart';

class FestivalService {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static Future<Map<String, List<String>>> fetchFestivalImages() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/get-tag-images'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      Map<String, List<String>> result = {};

      data.forEach((key, value) {
        result[key] = List<String>.from(value);
      });

      return result;
    } else {
      throw Exception("Failed to load data");
    }
  }
}
