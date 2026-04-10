import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/auth_provider.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:gridcard/widgets/core/core_widgets.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:gridcard/widgets/glass_box.dart';
import './add_product_page.dart';
import './product_details_page.dart';

class ProductsTab extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final VoidCallback? onSaved;

  const ProductsTab({super.key, this.userDetails, this.onSaved});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool isLoading = false;
  List products = [];

  // Static cache for products
  static List _cachedProducts = [];
  static int? _cachedUserId;
  static DateTime? _lastFetchTime;

  bool get _shouldRefresh {
    if (_cachedProducts.isEmpty || _lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) >
        const Duration(minutes: 60);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _getFullImageUrl(Map<String, dynamic> product) {
    try {
      if (product['product_image'] != null &&
          (product['product_image'] as List).isNotEmpty) {
        var imagePath =
            product['product_image'][0]['product_images'] as String?;
        return AppConfig.getFullUrl(imagePath) ?? '';
      }
    } catch (e) {
      debugPrint('Error constructing image URL: $e');
    }
    return '';
  }

  Future<void> _fetchProducts() async {
    final userIdId = await UserStorageService().getUserId();
    if (!_shouldRefresh &&
        _cachedProducts.isNotEmpty &&
        _cachedUserId == userIdId) {
      if (mounted) setState(() => products = List.from(_cachedProducts));
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();
      final userId = userIdId;
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
        _cachedProducts = List.from(products);
        _cachedUserId = userIdId;
        if (mounted) setState(() {});
      } else {
        throw (jsonData["message"] ?? "Products load failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    }
  }

  Future<void> _deleteProduct(int productId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/products-delete/$productId");
      final res = await http.delete(url, headers: headers);
      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        setState(() {
          products.removeWhere((p) => p['id'] == productId);
          _cachedProducts = List.from(products);
        });
        TopAlert.show(context, "Product deleted successfully", isSuccess: true);
        widget.onSaved?.call();
      } else {
        throw (jsonData["message"] ?? "Delete failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, "Error deleting product: $e", isError: true);
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
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(product['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authUserId = context.read<AuthProvider>().user?.id;
      if (authUserId != null) {
        context.read<ProfileProvider>().fetchUserVideos(authUserId);
      }
    });
  }

  void _onAddVideoPressed() async {
    final provider = context.read<ProfileProvider>();
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Short Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormInput(
              controller: titleCtrl,
              labelText: 'Title',
              hintText: 'e.g. Product Demo',
            ),
            const SizedBox(height: 12),
            AppFormInput(
              controller: urlCtrl,
              labelText: 'YouTube URL',
              hintText: 'Paste the url here',
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (url.isEmpty) {
                TopAlert.show(context, "URL is required", isError: true);
                return;
              }
              final success = await provider.addUserVideo({
                'title': title.isEmpty ? 'Short Video' : title,
                'video_url': url,
              });
              if (success && context.mounted) {
                Navigator.pop(context);
                TopAlert.show(context, "Video added successfully",
                    isSuccess: true);
                widget.onSaved?.call();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _onEditVideoPressed(Map<String, dynamic> video) async {
    final provider = context.read<ProfileProvider>();
    final titleCtrl = TextEditingController(text: video['title']?.toString());
    final urlCtrl = TextEditingController(text: (video['video_url'] ?? video['url'])?.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Short Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormInput(
              controller: titleCtrl,
              labelText: 'Title',
              hintText: 'e.g. Product Demo',
            ),
            const SizedBox(height: 12),
            AppFormInput(
              controller: urlCtrl,
              labelText: 'YouTube URL',
              hintText: 'https://youtube.com/shorts/...',
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (url.isEmpty) {
                TopAlert.show(context, "URL is required", isError: true);
                return;
              }
              final success = await provider.updateUserVideo(video['id'], {
                'title': title.isEmpty ? 'Short Video' : title,
                'video_url': url,
              });
              if (success && context.mounted) {
                Navigator.pop(context);
                TopAlert.show(context, "Video updated successfully",
                    isSuccess: true);
                widget.onSaved?.call();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _onDeleteVideo(int id) async {
    final provider = context.read<ProfileProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteUserVideo(id);
      if (success && mounted) {
        TopAlert.show(context, "Video deleted", isSuccess: true);
        widget.onSaved?.call();
      }
    }
  }

  String? _extractYoutubeId(String url) {
    final u = url.trim();
    final shorts = RegExp(r'youtube\.com\/shorts\/([A-Za-z0-9_-]{6,})')
        .firstMatch(u)
        ?.group(1);
    if (shorts != null) return shorts;
    final watch = RegExp(r'(?:v=)([A-Za-z0-9_-]{6,})').firstMatch(u)?.group(1);
    if (watch != null) return watch;
    final shortLink =
        RegExp(r'youtu\.be\/([A-Za-z0-9_-]{6,})').firstMatch(u)?.group(1);
    return shortLink;
  }

  String? _thumbnailFromUrl(String url) {
    final id = _extractYoutubeId(url);
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<ProfileProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        "Products",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddProductPage()),
                          );
                          if (result == true) {
                            _lastFetchTime = null;
                            _fetchProducts();
                            widget.onSaved?.call();
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Product"),
                      ),
                    ],
                  ),
                ),
              ),
              isLoading
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : products.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text("No products found")),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final p = products[i] as Map<String, dynamic>;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildProductCard(
                                      p, isDark, colorScheme),
                                );
                              },
                              childCount: products.length,
                            ),
                          ),
                        ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        "Product Short Videos",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _onAddVideoPressed,
                        icon: const Icon(Icons.video_call, size: 18),
                        label: const Text("Add Video"),
                      ),
                    ],
                  ),
                ),
              ),
              provider.isLoadingVideos
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : provider.userVideos.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                                child: Text("No short videos added yet")),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(14),
                          sliver: SliverReorderableList(
                            itemCount: provider.userVideos.length,
                            onReorder: (oldIndex, newIndex) {
                              provider.reorderVideos(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final video = provider.userVideos[index];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(video['id'] ?? index),
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildVideoCard(
                                      video, isDark, colorScheme),
                                ),
                              );
                            },
                          ),
                        ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductCard(
      Map<String, dynamic> p, bool isDark, ColorScheme colorScheme) {
    return GlassBox(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: InkWell(
        onTap: () => _navigateToDetails(p),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildProductImage(p, colorScheme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p["product_name"] ?? "-",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹ ${p["product_price"] ?? "0"}",
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddProductPage(product: p)),
                    );
                    if (result == true) {
                      _lastFetchTime = null;
                      _fetchProducts();
                      widget.onSaved?.call();
                    }
                  } else if (value == 'delete') {
                    _confirmDelete(p);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(
                      value: 'delete',
                      child:
                          Text("Delete", style: TextStyle(color: colorScheme.error))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(
      Map<String, dynamic> video, bool isDark, ColorScheme colorScheme) {
    final title = (video['title'] ?? 'Video').toString();
    final url = (video['video_url'] ?? video['url'] ?? '').toString();
    final thumb = _thumbnailFromUrl(url);

    return GlassBox(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                height: 56,
                color: colorScheme.onSurface.withOpacity(0.1),
                child: thumb != null
                    ? Image.network(thumb, fit: BoxFit.cover)
                    : Icon(Icons.video_library, color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
              onSelected: (value) async {
                if (value == 'edit') {
                  _onEditVideoPressed(video);
                } else if (value == 'delete') {
                  _onDeleteVideo(video['id']);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text("Edit")),
                PopupMenuItem(
                    value: 'delete',
                    child: Text("Delete", style: TextStyle(color: colorScheme.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product, ColorScheme colorScheme) {
    final imageUrl = _getFullImageUrl(product);
    if (imageUrl.isEmpty) {
      return Container(
          width: 60,
          height: 60,
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Icon(Icons.image_not_supported, color: colorScheme.onSurfaceVariant));
    }
    return Image.network(
      imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
          width: 60,
          height: 60,
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant)),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
            width: 60,
            height: 60,
            color: colorScheme.surfaceContainer,
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary.withOpacity(0.5)))));
      },
    );
  }
}
