import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gridcard/config/app_config.dart';
import 'dart:convert';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:gridcard/widgets/glass_box.dart';

class ProductListWidget extends StatefulWidget {
  final List products;
  final bool isLoading;
  final int? viewerUserId; // 👈 NEW
  final int? profileUserId;

  const ProductListWidget({
    super.key,
    required this.products,
    required this.isLoading,
    this.viewerUserId, // 👈 NEW
    this.profileUserId,
  });

  @override
  State<ProductListWidget> createState() => _ProductListWidgetState();
}

class _ProductListWidgetState extends State<ProductListWidget> {
  @override
  void initState() {
    super.initState();
    debugPrint("🟩 Products Data: ${widget.products}");
    debugPrint("🟩 viewerUserId: ${widget.viewerUserId}"); // 👈 NEW
    debugPrint("🟩 profileUserId: ${widget.profileUserId}"); // 👈 NEW
  }

  @override
  void didUpdateWidget(covariant ProductListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // void _handleProductAction(Map<String, dynamic> product) {
  //   final productId = product["id"];

  //   final data = {
  //     "product_id": productId,
  //     "viewer_user_id": widget.viewerUserId,
  //     "profile_user_id": widget.profileUserId,
  //   };

  //   debugPrint("🟦 Product Clicked JSON:");
  //   debugPrint(jsonEncode(data)); // 👈 JSON print
  // }

  Future<void> _handleProductAction(Map<String, dynamic> product) async {
    final productId = product["id"];

    final data = {
      "product_id": productId,
      "viewer_user_id": widget.viewerUserId,
      "profile_user_id": widget.profileUserId,
    };

    debugPrint("🟦 Product Clicked JSON:");
    debugPrint(jsonEncode(data));

    try {
      final headers = await _getHeaders();

      final url = Uri.parse("${AppConfig.apiBaseUrl}/product-click");

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ API Success: ${response.body}");
      } else {
        debugPrint("❌ API Error: ${response.statusCode}");
        debugPrint(response.body);
      }
    } catch (e) {
      debugPrint("🚨 API Exception: $e");
    }
  }

  String _getFullProductImageUrl(Map<String, dynamic> product) {
    try {
      if (product['product_image'] != null &&
          (product['product_image'] as List).isNotEmpty) {
        var imagePath =
            product['product_image'][0]['product_images'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          if (imagePath.startsWith('http')) return imagePath;
          if (imagePath.startsWith('/')) imagePath = imagePath.substring(1);

          String base = AppConfig.apiBaseUrl;
          if (base.endsWith('/api')) {
            base = base.substring(0, base.length - 4);
          }
          if (base.endsWith('/')) base = base.substring(0, base.length - 1);

          return '$base/$imagePath';
        }
      }
    } catch (e) {
      debugPrint('Error constructing image URL: $e');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Products & Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.products.length,
          itemBuilder: (context, index) {
            final p = widget.products[index] as Map<String, dynamic>;
            final imageUrl = _getFullProductImageUrl(p);
            final productName = p["product_name"] ?? "-";
            final productPrice = p["product_price"];
            final description = p["description"] ?? "";
            final productLinks = p["product_link"] as List?;
            final hasLinks = productLinks != null && productLinks.isNotEmpty;
            final isOwner = widget.viewerUserId == widget.profileUserId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassBox(
                padding: EdgeInsets.zero,
                borderRadius: 12,
                opacity: isDark ? 0.05 : 0.03,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 150,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image, size: 32),
                                      SizedBox(height: 6),
                                      Text("Not found"),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: double.infinity,
                            height: 150,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image, size: 32),
                                  SizedBox(height: 6),
                                  Text("No Image"),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // Product Info.....
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Price Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (productPrice != null &&
                                productPrice.toString().isNotEmpty)
                              Text(
                                "₹ $productPrice",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),

                        if (hasLinks)
                          Column(
                            children: productLinks.map<Widget>((linkObj) {
                              final title = linkObj["title"] ?? "Link";
                              final url = linkObj["links"] ?? "";

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: url.isNotEmpty
                                      ? () async {
                                          await _handleProductAction(p);

                                          final uri = Uri.tryParse(url);
                                          if (uri != null &&
                                              await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6A8DC7),
                                          Color(0xFF4F78B8),
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          )

                        // 👇 ONLY show if NOT owner
                        else if (!isOwner)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            child: ElevatedButton(
                              onPressed: () async {
                                await _handleProductAction(p); // 👈 await add
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: Colors.green,
                              ),
                              child: const Text(
                                "Add to Cart",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
