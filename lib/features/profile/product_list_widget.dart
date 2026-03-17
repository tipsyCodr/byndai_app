import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gridcard/config/app_config.dart';

class ProductListWidget extends StatefulWidget {
  final List products;
  final bool isLoading;

  const ProductListWidget({
    super.key,
    required this.products,
    required this.isLoading,
  });

  @override
  State<ProductListWidget> createState() => _ProductListWidgetState();
}

class _ProductListWidgetState extends State<ProductListWidget> {
  @override
  void initState() {
    super.initState();
    debugPrint("🟩 Products Data: ${widget.products}");
  }

  @override
  void didUpdateWidget(covariant ProductListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.onSurface.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    // child: imageUrl.isNotEmpty
                    //     ? Image.network(
                    //         imageUrl,
                    //         width: double.infinity,
                    //         fit: BoxFit.contain, // ✅ image crop नहीं होगा
                    //         errorBuilder: (context, error, stackTrace) =>
                    //             Container(
                    //           height: 150,
                    //           color: Colors.grey[300],
                    //           child: const Icon(Icons.image_not_supported),
                    //         ),
                    //       )
                    //     : Container(
                    //         width: double.infinity,
                    //         height: 150,
                    //         color: Colors.grey[300],
                    //         child: const Center(
                    //           child: Column(
                    //             mainAxisSize: MainAxisSize.min,
                    //             children: [
                    //               Icon(Icons.image, size: 32),
                    //               SizedBox(height: 6),
                    //               Text("No Image"),
                    //             ],
                    //           ),
                    //         ),
                    //       ),

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
                  // Product Info
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
                        // Links (if any) - now styled as in the image
                        if (productLinks != null && productLinks.isNotEmpty)
                          // Column(
                          //   crossAxisAlignment: CrossAxisAlignment.start,
                          //   children: productLinks.map<Widget>((linkObj) {
                          //     final title = linkObj["title"] ?? "Link";
                          //     final url = linkObj["links"] ?? "";
                          //     return Padding(
                          //       padding: const EdgeInsets.symmetric(vertical: 4),
                          //       child: InkWell(
                          //         onTap: url.isNotEmpty
                          //             ? () async {
                          //                 final uri = Uri.tryParse(url);
                          //                 if (uri != null &&
                          //                     await canLaunchUrl(uri)) {
                          //                   await launchUrl(uri);
                          //                 }
                          //               }
                          //             : null,
                          //         child: Row(
                          //           mainAxisSize: MainAxisSize.min,
                          //           children: [
                          //             Text(
                          //               title,
                          //               style: const TextStyle(
                          //                 color: Colors.blue,
                          //                 fontSize: 14,
                          //                 decoration: TextDecoration.underline,
                          //               ),
                          //             ),
                          //             const SizedBox(width: 4),
                          //             const Icon(Icons.arrow_forward,
                          //                 size: 16, color: Colors.blue),
                          //           ],
                          //         ),
                          //       ),
                          //     );
                          //   }).toList(),
                          // ),

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
                                          final uri = Uri.tryParse(url);
                                          if (uri != null &&
                                              await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
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
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
