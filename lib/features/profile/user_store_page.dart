import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/widgets/app_network_image.dart';
import 'package:gridcard/widgets/top_alert.dart';

class UserStorePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final List<dynamic> products;
  final List<dynamic> masterLinks;
  final bool isOwner;

  const UserStorePage({
    super.key,
    required this.profile,
    required this.products,
    this.masterLinks = const [],
    this.isOwner = false,
  });

  @override
  State<UserStorePage> createState() => _UserStorePageState();
}

class _UserStorePageState extends State<UserStorePage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<String> _favoriteProductIds = {};

  // Cart state: prodId -> quantity, prodId -> product map
  final Map<String, int> _cartQuantities = {};
  final Map<String, Map<String, dynamic>> _cartProducts = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getProdId(Map<String, dynamic> p, [int? fallbackIndex]) {
    final raw = p['id'] ?? p['prod_id'] ?? p['product_id'] ?? p['product_name'] ?? p['title'] ?? fallbackIndex ?? 'item';
    return raw.toString();
  }

  double _parsePrice(String priceStr) {
    try {
      final clean = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(clean) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  int get _cartTotalCount {
    return _cartQuantities.values.fold(0, (sum, count) => sum + count);
  }

  double get _cartTotalPrice {
    double total = 0.0;
    _cartQuantities.forEach((id, qty) {
      final p = _cartProducts[id];
      if (p != null) {
        final rawPrice = (p['price'] ?? p['product_price'] ?? '0').toString();
        total += _parsePrice(rawPrice) * qty;
      }
    });
    return total;
  }

  void _addToCart(Map<String, dynamic> product, [int? fallbackIndex]) {
    final id = _getProdId(product, fallbackIndex);
    setState(() {
      _cartProducts[id] = product;
      _cartQuantities[id] = (_cartQuantities[id] ?? 0) + 1;
    });
    TopAlert.show(context, 'Added to cart');
  }

  void _decreaseQuantity(String prodId) {
    setState(() {
      final current = _cartQuantities[prodId] ?? 0;
      if (current <= 1) {
        _cartQuantities.remove(prodId);
        _cartProducts.remove(prodId);
      } else {
        _cartQuantities[prodId] = current - 1;
      }
    });
  }

  void _removeFromCart(String prodId) {
    setState(() {
      _cartQuantities.remove(prodId);
      _cartProducts.remove(prodId);
    });
  }

  void _clearCart() {
    setState(() {
      _cartQuantities.clear();
      _cartProducts.clear();
    });
  }

  String _resolveWhatsAppNumber() {
    final profile = widget.profile;
    final userObj = profile['user'] as Map<String, dynamic>?;
    String raw = (profile['mobile'] ??
            profile['mobile_one'] ??
            userObj?['user_mobile'] ??
            userObj?['mobile'] ??
            '')
        .toString();

    for (final link in widget.masterLinks) {
      final name = (link['name'] ?? '').toString().toLowerCase();
      if (name.contains('whatsapp')) {
        final l = (link['link'] ?? '').toString();
        final digits = l.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty) {
          raw = digits;
          break;
        }
      }
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length == 10 ? '91$digits' : digits;
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;
    String sanitized = url.trim();
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      sanitized = 'https://$sanitized';
    }
    try {
      final uri = Uri.parse(sanitized);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) TopAlert.show(context, 'Could not launch link', isError: true);
      }
    } catch (_) {
      if (mounted) TopAlert.show(context, 'Invalid link', isError: true);
    }
  }

  void _orderOnWhatsApp(String title, String price, {String? sku}) {
    final phone = _resolveWhatsAppNumber();
    if (phone.isEmpty) {
      TopAlert.show(context, 'WhatsApp number not available', isError: true);
      return;
    }
    final skuText = (sku != null && sku.isNotEmpty) ? ' (SKU: $sku)' : '';
    final message = Uri.encodeComponent(
      'Hi! I saw *$title*$skuText priced at ₹$price on your store and would like to order it. Please share payment and delivery details.',
    );
    _launchURL('https://wa.me/$phone?text=$message');
  }

  void _sendCartOrderOnWhatsApp() {
    final phone = _resolveWhatsAppNumber();
    if (phone.isEmpty) {
      TopAlert.show(context, 'WhatsApp number not available', isError: true);
      return;
    }
    if (_cartQuantities.isEmpty) {
      TopAlert.show(context, 'Your cart is empty', isError: true);
      return;
    }

    final storeName = (widget.profile['company_name'] ??
            widget.profile['business_name'] ??
            widget.profile['full_name'] ??
            'Store')
        .toString();

    final buffer = StringBuffer();
    buffer.writeln('Hi $storeName! I would like to order the following items from your store:');
    buffer.writeln('');
    buffer.writeln('🛍️ *CART ITEMS:*');

    int index = 1;
    _cartQuantities.forEach((id, qty) {
      final p = _cartProducts[id];
      if (p != null && qty > 0) {
        final rawTitle = (p['title'] ?? p['product_name'] ?? 'Product').toString();
        final rawPrice = (p['price'] ?? p['product_price'] ?? '0').toString();
        final itemPrice = _parsePrice(rawPrice);
        final itemTotal = itemPrice * qty;
        final sku = (p['sku'] ?? '').toString().trim();
        final skuText = sku.isNotEmpty ? ' [SKU: $sku]' : '';

        buffer.writeln('$index. *$rawTitle*$skuText');
        buffer.writeln('   • Quantity: $qty');
        buffer.writeln('   • Price: ₹${_formatPrice(rawPrice)} each');
        buffer.writeln('   • Subtotal: ₹${_formatPrice(itemTotal.toStringAsFixed(2))}');
        index++;
      }
    });

    buffer.writeln('');
    buffer.writeln('------------------------------');
    buffer.writeln('💰 *Total Amount:* ₹${_formatPrice(_cartTotalPrice.toStringAsFixed(2))}');
    buffer.writeln('📦 *Total Items:* $_cartTotalCount');
    buffer.writeln('------------------------------');
    buffer.writeln('');
    buffer.writeln('Please confirm product availability and share payment/delivery details. Thank you!');

    final message = Uri.encodeComponent(buffer.toString());
    _launchURL('https://wa.me/$phone?text=$message');
  }

  String _formatPrice(String priceStr) {
    try {
      final clean = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      if (clean.isEmpty) return priceStr;
      final value = double.parse(clean);
      final isWhole = value == value.toInt();
      final formatted = isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
      final parts = formatted.split('.');
      final whole = parts[0];
      final decimal = parts.length > 1 ? '.${parts[1]}' : '';
      if (whole.length <= 3) return whole + decimal;
      final lastThree = whole.substring(whole.length - 3);
      final rest = whole.substring(0, whole.length - 3);
      final chunks = <String>[];
      int i = rest.length;
      while (i > 0) {
        if (i >= 2) {
          chunks.add(rest.substring(i - 2, i));
          i -= 2;
        } else {
          chunks.add(rest.substring(0, i));
          i = 0;
        }
      }
      return '${chunks.reversed.join(',')},$lastThree$decimal';
    } catch (_) {
      return priceStr;
    }
  }

  String? _pImg(Map<String, dynamic> p) {
    final img = p['product_image'];
    String? path;
    if (img != null) {
      if (img is List && img.isNotEmpty) {
        path = img[0]['product_images']?.toString() ?? img[0]['image']?.toString();
      } else if (img is String) {
        path = img;
      }
    }
    path ??= p['image']?.toString() ?? p['img']?.toString();
    return AppConfig.getFullUrl(path);
  }

  List<String> _allProductImages(Map<String, dynamic> p) {
    final images = <String>[];
    final img = p['product_image'];
    if (img is List) {
      for (final item in img) {
        final path = item['product_images']?.toString() ?? item['image']?.toString();
        final full = AppConfig.getFullUrl(path);
        if (full != null && full.isNotEmpty && !images.contains(full)) {
          images.add(full);
        }
      }
    } else if (img is String) {
      final full = AppConfig.getFullUrl(img);
      if (full != null && full.isNotEmpty) images.add(full);
    }
    final fallback = AppConfig.getFullUrl(p['image']?.toString() ?? p['img']?.toString());
    if (fallback != null && fallback.isNotEmpty && !images.contains(fallback)) {
      images.add(fallback);
    }
    return images;
  }

  List<String> _extractCategories() {
    final set = <String>{'All'};
    for (final item in widget.products) {
      final cat = (item['category_name'] ?? item['category'] ?? '').toString().trim();
      if (cat.isNotEmpty) set.add(cat);
    }
    return set.toList();
  }

  List<dynamic> _filteredProducts() {
    return widget.products.where((p) {
      final name = (p['title'] ?? p['product_name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category_name'] ?? p['category'] ?? '').toString();
      final tags = (p['tags'] ?? '').toString().toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          tags.contains(_searchQuery);

      final matchesCat = _selectedCategory == 'All' ||
          cat.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesQuery && matchesCat;
    }).toList();
  }

  void _openCartModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cartEntries = _cartQuantities.entries.toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1F51E5), size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Shopping Cart ($_cartTotalCount)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (cartEntries.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _clearCart();
                              setModalState(() {});
                              setState(() {});
                            },
                            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Cart Item List
                  Expanded(
                    child: cartEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey[500]),
                                const SizedBox(height: 12),
                                Text(
                                  'Your cart is empty',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Add products to place an order via WhatsApp',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: cartEntries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = cartEntries[index];
                              final id = entry.key;
                              final qty = entry.value;
                              final p = _cartProducts[id] ?? {};

                              final rawTitle = (p['title'] ?? p['product_name'] ?? 'Product').toString();
                              final title = rawTitle == rawTitle.toLowerCase()
                                  ? rawTitle.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ')
                                  : rawTitle;
                              final rawPrice = (p['price'] ?? p['product_price'] ?? '0').toString();
                              final price = _formatPrice(rawPrice);
                              final itemTotal = _parsePrice(rawPrice) * qty;
                              final imageUrl = _pImg(p);

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF262636) : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: AppNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹$price each • Total: ₹${_formatPrice(itemTotal.toStringAsFixed(2))}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF25D366),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          onPressed: () {
                                            _decreaseQuantity(id);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$qty',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: colorScheme.primary,
                                          onPressed: () {
                                            _addToCart(p);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _removeFromCart(id);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Summary & WhatsApp Checkout
                  if (cartEntries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              Text(
                                '₹${_formatPrice(_cartTotalPrice.toStringAsFixed(2))}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _sendCartOrderOnWhatsApp();
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Send Order via WhatsApp',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openProductDetailsModal(Map<String, dynamic> p, [int? fallbackIndex]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final id = _getProdId(p, fallbackIndex);
    final rawTitle = (p['title'] ?? p['product_name'] ?? 'Product').toString();
    final title = rawTitle == rawTitle.toLowerCase()
        ? rawTitle
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
            .join(' ')
        : rawTitle;
    final rawPrice = (p['price'] ?? p['product_price'] ?? '0').toString();
    final price = _formatPrice(rawPrice);
    final desc = (p['description'] ?? '').toString().trim();
    final sku = (p['sku'] ?? '').toString().trim();
    final stock = p['stock'];
    final category = (p['category_name'] ?? p['category'] ?? '').toString().trim();
    final images = _allProductImages(p);
    final List links = p['product_link'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int activeImgIndex = 0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inCartQty = _cartQuantities[id] ?? 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  SizedBox(
                                    height: 260,
                                    width: double.infinity,
                                    child: AppNetworkImage(
                                      imageUrl: images[activeImgIndex],
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: 260,
                                    ),
                                  ),
                                  if (category.isNotEmpty)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (images.length > 1) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (ctx, i) {
                                    final isSelected = i == activeImgIndex;
                                    return GestureDetector(
                                      onTap: () =>
                                          setModalState(() => activeImgIndex = i),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AppNetworkImage(
                                            imageUrl: images[i],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '₹$price',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        color: Colors.green, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      stock != null && stock > 0
                                          ? 'In Stock ($stock)'
                                          : 'Available to Order',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (sku.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'SKU: $sku',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          if (desc.isNotEmpty) ...[
                            Text(
                              'About this item',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (links.isNotEmpty) ...[
                            Text(
                              'Product Links',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: links.map<Widget>((link) {
                                final lTitle = (link['title'] ?? 'Open Link').toString();
                                final lUrl = (link['links'] ?? '').toString();
                                return ActionChip(
                                  avatar: const Icon(Icons.link, size: 16),
                                  label: Text(lTitle),
                                  onPressed: () => _launchURL(lUrl),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar: Add to Cart + WhatsApp Buy Now
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Add to Cart Button
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _addToCart(p, fallbackIndex);
                                setModalState(() {});
                                setState(() {});
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                              label: Text(
                                inCartQty > 0 ? 'In Cart ($inCartQty)' : 'Add to Cart',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(color: colorScheme.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Direct Order via WhatsApp
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _orderOnWhatsApp(title, price, sku: sku);
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Order Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final onSurface = isDark ? Colors.white : Colors.black87;

    final profile = widget.profile;
    final userObj = profile['user'] as Map<String, dynamic>?;
    final storeName = (profile['company_name'] ??
            profile['business_name'] ??
            profile['full_name'] ??
            userObj?['name'] ??
            'Store')
        .toString();
    final categories = _extractCategories();
    final filtered = _filteredProducts();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121A) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  storeName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified,
                  color: Color(0xFF1F51E5),
                  size: 16,
                ),
              ],
            ),
            Text(
              '${widget.products.length} Products Available',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          // Cart Button in AppBar with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Shopping Cart',
                icon: const Icon(Icons.shopping_bag_outlined, size: 24),
                onPressed: _openCartModal,
              ),
              if (_cartTotalCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        '$_cartTotalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Share Store',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final userName = userObj?['user_name'] ?? widget.profile['user_id'] ?? 'user';
              final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
              Share.share('Check out $storeName online store: $baseUrl/u/$userName');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: _cartTotalCount > 0
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A24) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _openCartModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_cartTotalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'View Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Total: ₹${_formatPrice(_cartTotalPrice.toStringAsFixed(2))}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Order Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // Store banner & search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                            : [const Color(0xFF1F51E5), const Color(0xFF4338CA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F51E5).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Official Product Catalog',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Instant WhatsApp Ordering',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search products by name or tag...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Categories Filter
                  if (categories.length > 1) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            selectedColor: colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF1E1E28)
                                : Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? colorScheme.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.grey.withValues(alpha: 0.2)),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),

          // Product Grid
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 56,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try searching with different keywords'
                            : 'No products in this category yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.63,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = filtered[index];
                    final prodId = _getProdId(p, index);
                    final rawTitle =
                        (p['title'] ?? p['product_name'] ?? 'Product').toString();
                    final title = rawTitle == rawTitle.toLowerCase()
                        ? rawTitle
                            .split(' ')
                            .map((w) => w.isNotEmpty
                                ? w[0].toUpperCase() + w.substring(1)
                                : '')
                            .join(' ')
                        : rawTitle;
                    final rawPrice =
                        (p['price'] ?? p['product_price'] ?? '0').toString();
                    final price = _formatPrice(rawPrice);
                    final desc = (p['description'] ?? '').toString().trim();
                    final imageUrl = _pImg(p);
                    final isFav = _favoriteProductIds.contains(prodId);
                    final cartQty = _cartQuantities[prodId] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _openProductDetailsModal(p, index),
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image & Favorite Icon
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(17)),
                                  child: SizedBox(
                                    height: 135,
                                    width: double.infinity,
                                    child: AppNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 135,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isFav) {
                                          _favoriteProductIds.remove(prodId);
                                        } else {
                                          _favoriteProductIds.add(prodId);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: isFav ? Colors.redAccent : Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Product details & Add to Cart button
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                            letterSpacing: -0.2,
                                            color: onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (desc.isNotEmpty)
                                          Text(
                                            desc,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₹$price',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF25D366),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Cart Action: Stepper if in cart, otherwise "Add to Cart" button
                                        if (cartQty > 0)
                                          Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: colorScheme.primary.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () => _decreaseQuantity(prodId),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    child: Icon(Icons.remove, size: 16, color: colorScheme.primary),
                                                  ),
                                                ),
                                                Text(
                                                  '$cartQty',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _addToCart(p, index),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    child: Icon(Icons.add, size: 16, color: colorScheme.primary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            width: double.infinity,
                                            height: 32,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _addToCart(p, index),
                                              icon: const Icon(
                                                Icons.add_shopping_cart_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Add to Cart',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1F51E5),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
