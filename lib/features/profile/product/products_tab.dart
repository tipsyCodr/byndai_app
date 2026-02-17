import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import './add_product_page.dart';
import './product_details_page.dart'; // we'll create this next

class ProductsTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;

  const ProductsTab({super.key, this.userDetails});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;
  List products = [];

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Constructs full image URL from relative path
  String _getFullImageUrl(Map<String, dynamic> product) {
    try {
      if (product['product_image'] != null &&
          (product['product_image'] as List).isNotEmpty) {
        var imagePath =
            product['product_image'][0]['product_images'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          // If it's already a full URL, return as is
          if (imagePath.startsWith('http')) return imagePath;

          // Remove leading slash if present
          if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);

          // Base URL without '/api' (assuming images are stored in public dir)
          String base = _baseUrl;
          if (base.endsWith('/api')) {
            base = base.substring(0, base.length - 4);
          } else if (base.endsWith('/')) {
            base = base.substring(0, base.length - 1);
          }
          // Remove trailing slash
          if (base.endsWith('/')) base = base.substring(0, base.length - 1);

          return '$base/$imagePath';
        }
      }
    } catch (e) {
      debugPrint('Error constructing image URL: $e');
    }
    return ''; // Return empty if no image
  }

  Future<void> _fetchProducts() async {
    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();
      final userId = await UserStorageService().getUserId();
      final url = Uri.parse("$_baseUrl/products-by-user/$userId");

      final res = await http.get(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        var dataObject = jsonData["data"];
        if (dataObject != null && dataObject["data"] != null) {
          products = dataObject["data"] as List;
        } else {
          products = [];
        }
        if (mounted) setState(() {});
      } else {
        throw (jsonData["message"] ?? "Products load failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Delete a product by ID
  Future<void> _deleteProduct(int productId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/products-delete/$productId");
      final res = await http.delete(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        setState(() {
          products.removeWhere((p) => p['id'] == productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted successfully")),
        );
      } else {
        throw (jsonData["message"] ?? "Delete failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting product: $e")),
      );
    }
  }

  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product"),
        content: Text(
            "Are you sure you want to delete '${product['product_name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(product['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(Map<String, dynamic> product) {
    final imageUrl = _getFullImageUrl(product);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailsPage(product: product, imageUrl: imageUrl),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? const Center(child: Text("No products found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i] as Map<String, dynamic>;

                    // return Card(
                    //   elevation: 2,
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(14),
                    //   ),
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(8.0),
                    //     child: Row(
                    //       children: [
                    //         // Tappable area (image + details)
                    //         Expanded(
                    //           child: GestureDetector(
                    //             onTap: () => _navigateToDetails(p),
                    //             child: Row(
                    //               children: [
                    //                 // Product image
                    //                 ClipRRect(
                    //                   borderRadius: BorderRadius.circular(8),
                    //                   child: _buildProductImage(p),
                    //                 ),
                    //                 const SizedBox(width: 12),
                    //                 // Product details
                    //                 Expanded(
                    //                   child: Column(
                    //                     crossAxisAlignment:
                    //                         CrossAxisAlignment.start,
                    //                     children: [
                    //                       Text(
                    //                         p["product_name"] ?? "-",
                    //                         style: const TextStyle(
                    //                           fontWeight: FontWeight.w600,
                    //                           fontSize: 16,
                    //                         ),
                    //                       ),
                    //                       const SizedBox(height: 4),
                    //                       Text(
                    //                         "₹ ${p["product_price"] ?? "0"}",
                    //                         style: const TextStyle(
                    //                           fontSize: 14,
                    //                           color: Colors.green,
                    //                         ),
                    //                       ),
                    //                       if (p["description"] != null &&
                    //                           p["description"]
                    //                               .toString()
                    //                               .isNotEmpty)
                    //                         Padding(
                    //                           padding:
                    //                               const EdgeInsets.only(top: 4),
                    //                           child: Text(
                    //                             p["description"],
                    //                             maxLines: 2,
                    //                             overflow: TextOverflow.ellipsis,
                    //                             style: const TextStyle(
                    //                               fontSize: 12,
                    //                               color: Colors.grey,
                    //                             ),
                    //                           ),
                    //                         ),
                    //                     ],
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //         ),
                    //         // Three-dot menu

                    //         PopupMenuButton<String>(
                    //           icon: const Icon(Icons.more_vert),
                    //           onSelected: (value) async {
                    //             if (value == 'edit') {
                    //               // ✅ Navigate to AddProductPage in Edit Mode
                    //               final result = await Navigator.push(
                    //                 context,
                    //                 MaterialPageRoute(
                    //                   builder: (_) =>
                    //                       AddProductPage(product: p),
                    //                 ),
                    //               );

                    //               // ✅ If updated successfully, refresh list
                    //               if (result == true) {
                    //                 _fetchProducts();
                    //               }
                    //             } else if (value == 'delete') {
                    //               _confirmDelete(p);
                    //             }
                    //           },
                    //           itemBuilder: (ctx) => const [
                    //             PopupMenuItem(
                    //               value: 'edit',
                    //               child: Row(
                    //                 children: [
                    //                   Icon(Icons.edit, size: 18),
                    //                   SizedBox(width: 8),
                    //                   Text("Edit"),
                    //                 ],
                    //               ),
                    //             ),
                    //             PopupMenuItem(
                    //               value: 'delete',
                    //               child: Row(
                    //                 children: [
                    //                   Icon(Icons.delete,
                    //                       size: 18, color: Colors.red),
                    //                   SizedBox(width: 8),
                    //                   Text("Delete",
                    //                       style: TextStyle(color: Colors.red)),
                    //                 ],
                    //               ),
                    //             ),
                    //           ],
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // );

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _navigateToDetails(
                            p), // ✅ Full card click -> details
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              // Product image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildProductImage(p),
                              ),

                              const SizedBox(width: 12),

                              // Product details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p["product_name"] ?? "-",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹ ${p["product_price"] ?? "0"}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                      ),
                                    ),
                                    if (p["description"] != null &&
                                        p["description"].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          p["description"],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Three-dot menu (ye tap se safe rahega)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddProductPage(product: p),
                                      ),
                                    );

                                    if (result == true) {
                                      _fetchProducts();
                                    }
                                  } else if (value == 'delete') {
                                    _confirmDelete(p);
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text("Edit"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text("Delete",
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),
          );
          if (result == true) {
            _fetchProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrl = _getFullImageUrl(product);

    if (imageUrl.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        color: Colors.grey[300],
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }

    return Image.network(
      imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 60,
        height: 60,
        color: Colors.grey[300],
        child: Icon(Icons.broken_image, color: Colors.grey[600]),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 60,
          height: 60,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
