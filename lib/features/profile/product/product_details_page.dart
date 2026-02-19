import 'package:flutter/material.dart';

class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> product;
  final String imageUrl;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final name = (product['product_name'] ?? 'No Name').toString();
    final price = (product['product_price'] ?? '0').toString();
    final desc = (product['description'] ?? '').toString();
    final sku = (product['sku'] ?? '-').toString();
    final category = (product['category_name'] ?? '-').toString();
    final stock = (product['stock'] ?? 0).toString();
    final tags = (product['tags'] ?? '-').toString();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Product Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Top Image Section
            Container(
              width: double.infinity,
              color: Colors.white,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 260,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, error, stack) => Container(
                          height: 260,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 55),
                        ),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 260,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 260,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 55),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Main Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Price Row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                "₹ $price",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Stock badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                "Stock: $stock",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _chip("Category: $category", Icons.category),
                            _chip("SKU: $sku", Icons.qr_code_2),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Description Card
                  if (desc.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Description",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),
                  
                  // Tags Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tags",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ✅ TAGS AS CHIPS
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: tags
                              .split(',')
                              .map((t) => t.trim())
                              .where((t) => t.isNotEmpty)
                              .map(
                                (tag) => Chip(
                                  label: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
