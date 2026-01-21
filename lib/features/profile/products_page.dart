import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/product_provider.dart';
import 'package:gridcard/features/profile/product_creation_page.dart';
import 'package:provider/provider.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = provider.products;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title:
            Text('My Products', style: TextStyle(color: colorScheme.primary)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ProductCreationPage()),
          );
        },
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      body: provider.isLoading && products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? Center(
                  child: Text('No products added yet',
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.3))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colorScheme.onSurface.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.images.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: Image.network(
                                product.images.first,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 180,
                                  color: isDark
                                      ? colorScheme.surfaceContainerHighest
                                      : Colors.grey[200],
                                  child: Icon(Icons.image_not_supported,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.1)),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: TextStyle(
                                            color: isDark
                                                ? colorScheme.onSurface
                                                : colorScheme.primary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      '₹${product.price}',
                                      style: TextStyle(
                                          color: isDark
                                              ? colorScheme.primary
                                              : Colors.green[700],
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product.description,
                                  style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7),
                                      fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (product.links.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    children: product.links
                                        .map((link) => Chip(
                                              label: Text('Link',
                                                  style: TextStyle(
                                                      color:
                                                          colorScheme.primary,
                                                      fontSize: 10)),
                                              backgroundColor: colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              padding: EdgeInsets.zero,
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
