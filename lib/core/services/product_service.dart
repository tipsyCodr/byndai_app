import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ProductService {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /product
  static Future<List<dynamic>> fetchProducts() async {
    final url = Uri.parse('$_baseUrl/product');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (kDebugMode) {
        debugPrint('🔹 GET $url');
        debugPrint('🔹 Status: ${response.statusCode}');
        debugPrint('🔹 Response: ${response.body}');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['data'] != null) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('🚨 Error fetching products: $e');
      return [];
    }
  }

  /// POST /product/create
  /// Body: { "product_name", "product_price", "description", "title_links", "links", "file_name" }
  static Future<bool> createProduct({
    required String name,
    required double price,
    required String description,
    List<String>? titleLinks,
    List<String>? links,
    List<File>? files,
  }) async {
    final url = Uri.parse('$_baseUrl/product/create');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders());

      request.fields['product_name'] = name;
      request.fields['product_price'] = price.toString();
      request.fields['description'] = description;

      if (titleLinks != null) {
        for (var i = 0; i < titleLinks.length; i++) {
          request.fields['title_links[$i]'] = titleLinks[i];
        }
      }

      if (links != null) {
        for (var i = 0; i < links.length; i++) {
          request.fields['links[$i]'] = links[i];
        }
      }

      if (files != null) {
        for (var i = 0; i < files.length; i++) {
          final stream = http.ByteStream(files[i].openRead());
          final length = await files[i].length();
          final multipartFile = http.MultipartFile(
            'file_name[$i]', // Backend expects array of files or specific field names
            stream,
            length,
            filename: files[i].path.split('/').last,
            contentType:
                MediaType('image', 'jpeg'), // Adjust based on file type
          );
          request.files.add(multipartFile);
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint('🔹 POST $url');
        debugPrint('🔹 Status: ${response.statusCode}');
        debugPrint('🔹 Response: ${response.body}');
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('🚨 Error creating product: $e');
      return false;
    }
  }
}
