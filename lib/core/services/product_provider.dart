import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/product_service.dart';
import 'package:gridcard/models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> data = await ProductService.fetchProducts();
      _products = data.map((item) => ProductModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('🚨 Error in ProductProvider.fetchProducts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProduct({
    required String name,
    required double price,
    required String description,
    List<String>? titleLinks,
    List<String>? links,
    List<File>? files,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await ProductService.createProduct(
        name: name,
        price: price,
        description: description,
        titleLinks: titleLinks,
        links: links,
        files: files,
      );
      if (success) {
        await fetchProducts(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Error in ProductProvider.createProduct: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
