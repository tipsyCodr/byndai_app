import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'package:gridcard/core/utils/error_formatter.dart';

class AddProductPage extends StatefulWidget {
  final Map<String, dynamic>? product; // ✅ Add/Edit ke liye

  const AddProductPage({super.key, this.product});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final categoryCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final tagsCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  String existingImageUrl = "";

  List<Map<String, String>> productLinks = [];

  final linkTitleCtrl = TextEditingController();
  final linkUrlCtrl = TextEditingController();

  XFile? productImage;

  bool isLoading = false;

  static const String _baseUrl = AppConfig.apiBaseUrl;

  bool get isEdit => widget.product != null;

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();

    return {
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  @override
  void initState() {
    super.initState();

    // ✅ Prefill fields in Edit Mode
    if (isEdit) {
      final p = widget.product!;
      print("Product Data:");
      print(widget.product);
      categoryCtrl.text = (p["category_name"] ?? "").toString();
      nameCtrl.text = (p["product_name"] ?? "").toString();
      priceCtrl.text = (p["product_price"] ?? "").toString();
      descriptionCtrl.text = (p["description"] ?? "").toString();
      skuCtrl.text = (p["sku"] ?? "").toString();
      tagsCtrl.text = (p["tags"] ?? "").toString();
      stockCtrl.text = (p["stock"] ?? "").toString();

      /// ✅ Load existing product links
      if (p["product_link"] != null && p["product_link"] is List) {
        productLinks = List<Map<String, String>>.from(
          (p["product_link"] as List).map((link) => {
                "title": (link["title"] ?? "").toString(),
                "links": (link["links"] ?? "").toString(),
              }),
        );
      }

      print("Loaded Links:");
      print(productLinks);

      if (p["product_image"] != null &&
          (p["product_image"] as List).isNotEmpty) {
        String path = p["product_image"][0]["product_images"] ?? "";

        if (path.isNotEmpty) {
          String base = _baseUrl;

          if (base.endsWith('/api')) {
            base = base.substring(0, base.length - 4);
          }

          if (path.startsWith('/')) {
            path = path.substring(1);
          }

          existingImageUrl = "$base/$path";
        }
      }
    }
  }

  void _openAddLinkModal() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Link",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkTitleCtrl,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkUrlCtrl,
                decoration: const InputDecoration(
                  labelText: "Link",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (linkTitleCtrl.text.trim().isEmpty ||
                        linkUrlCtrl.text.trim().isEmpty) {
                      return;
                    }

                    setState(() {
                      productLinks.add({
                        "title": linkTitleCtrl.text.trim(),
                        "links": linkUrlCtrl.text.trim(),
                      });
                    });

                    linkTitleCtrl.clear();
                    linkUrlCtrl.clear();

                    Navigator.pop(context);
                  },
                  child: const Text("Add Link"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEditLinkModal(int index) {
    final colorScheme = Theme.of(context).colorScheme;

    linkTitleCtrl.text = productLinks[index]["title"] ?? "";
    linkUrlCtrl.text = productLinks[index]["links"] ?? "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Edit Link",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkTitleCtrl,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkUrlCtrl,
                decoration: const InputDecoration(
                  labelText: "Link",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      productLinks[index] = {
                        "title": linkTitleCtrl.text.trim(),
                        "links": linkUrlCtrl.text.trim(),
                      };
                    });

                    linkTitleCtrl.clear();
                    linkUrlCtrl.clear();

                    Navigator.pop(context);
                  },
                  child: const Text("Update Link"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickProductImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => productImage = picked);
    }
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          // labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
          labelStyle: TextStyle(
            color: isDark
                ? colorScheme.onSurface.withOpacity(0.6)
                : colorScheme.primary,
          ),
          filled: true,
          fillColor:
              isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (isLoading) return;

    print("Product Links:");
    print(productLinks);

    if (nameCtrl.text.trim().isEmpty) {
      TopAlert.show(context, "Product name required", isError: true);
      return;
    }

    if (priceCtrl.text.trim().isEmpty) {
      TopAlert.show(context, "Product price required", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();

      // ✅ Add / Edit API
      final Uri url = isEdit
          ? Uri.parse("$_baseUrl/products-update/${widget.product!['id']}")
          : Uri.parse("$_baseUrl/products");

      final request = http.MultipartRequest("POST", url);
      request.headers.addAll(headers);

      // ✅ Fields
      request.fields["category_name"] = categoryCtrl.text.trim();
      request.fields["product_name"] = nameCtrl.text.trim();
      request.fields["product_price"] = priceCtrl.text.trim();
      request.fields["description"] = descriptionCtrl.text.trim();
      request.fields["sku"] = skuCtrl.text.trim();
      request.fields["tags"] = tagsCtrl.text.trim();
      request.fields["stock"] = stockCtrl.text.trim();
      request.fields["status"] = "1";

      // ✅ Send Product Links
      if (productLinks.isNotEmpty) {
        request.fields["links"] = jsonEncode(productLinks);
      }

      // ✅ Image (only if selected new one)
      if (productImage != null) {
        if (kIsWeb) {
          final bytes = await productImage!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              "product_image",
              bytes,
              filename: productImage!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              "product_image",
              productImage!.path,
              filename: productImage!.name,
            ),
          );
        }
      }

      // ✅ Send Request
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      final jsonData = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final msg = jsonData["message"] ??
            (isEdit
                ? "Product updated successfully"
                : "Product created successfully");

        if (!mounted) return;

        TopAlert.show(context, msg.toString(), isSuccess: true);

        await Future.delayed(const Duration(milliseconds: 700));

        if (mounted) {
          Navigator.pop(context, true); // ✅ refresh trigger
        }
      } else {
        final msg = jsonData["message"] ?? "Something went wrong";
        throw msg.toString();
      }
    } catch (e) {
      if (!mounted) return;
      TopAlert.show(context, ErrorFormatter.format(e), isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    categoryCtrl.dispose();
    nameCtrl.dispose();
    priceCtrl.dispose();
    descriptionCtrl.dispose();
    skuCtrl.dispose();
    tagsCtrl.dispose();
    stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Product" : "Add Product"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _inputField(label: "Category Name", controller: categoryCtrl),
              _inputField(label: "Product Name", controller: nameCtrl),
              _inputField(
                label: "Product Price",
                controller: priceCtrl,
                keyboardType: TextInputType.number,
              ),
              _inputField(
                label: "Description",
                controller: descriptionCtrl,
                maxLines: 3,
              ),
              _inputField(label: "SKU", controller: skuCtrl),
              _inputField(label: "Tags", controller: tagsCtrl),
              _inputField(
                label: "Stock",
                controller: stockCtrl,
                keyboardType: TextInputType.number,
              ),

              // ✅ Product Image Upload + Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Product Image",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    // if (productImage != null)
                    //   ClipRRect(
                    //     borderRadius: BorderRadius.circular(12),
                    //     child: kIsWeb
                    //         ? Image.network(
                    //             productImage!.path,
                    //             height: 160,
                    //             width: double.infinity,
                    //             fit: BoxFit.contain,
                    //           )
                    //         : Image.file(
                    //             File(productImage!.path),
                    //             height: 160,
                    //             width: double.infinity,
                    //             fit: BoxFit.contain,
                    //           ),
                    //   )
                    // else
                    //   Container(
                    //     height: 140,
                    //     width: double.infinity,
                    //     decoration: BoxDecoration(
                    //       color: isDark
                    //           ? colorScheme.surfaceContainerHighest
                    //           : Colors.grey.shade100,
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     child: Center(
                    //       child: Text(
                    //         isEdit
                    //             ? "No new image selected (old image will remain)"
                    //             : "No image selected",
                    //         textAlign: TextAlign.center,
                    //         style: TextStyle(
                    //           color: colorScheme.onSurface.withOpacity(0.7),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    if (productImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                productImage!.path,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(productImage!.path),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                      )
                    else if (existingImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          existingImageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        child: Center(
                          child: Text("No image selected"),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickProductImage,
                        icon: const Icon(Icons.image),
                        label: Text(isEdit
                            ? "Change Product Image"
                            : "Upload Product Image"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _openAddLinkModal,
                  icon: const Icon(Icons.add_link),
                  label: const Text("Add Links"),
                ),
              ),

              const SizedBox(height: 12),

              if (productLinks.isNotEmpty)
                // Column(
                //   children: productLinks.map((link) {
                //     return Card(
                //       margin: const EdgeInsets.only(bottom: 8),
                //       child: ListTile(
                //         title: Text(link["title"] ?? ""),
                //         subtitle: Text(link["links"] ?? ""),
                //         leading: const Icon(Icons.link),
                //       ),
                //     );
                //   }).toList(),
                // ),

                Column(
                  children: productLinks.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, String> link = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(link["title"] ?? ""),
                        subtitle: Text(link["links"] ?? ""),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == "edit") {
                              _openEditLinkModal(index);
                            } else if (value == "delete") {
                              setState(() {
                                productLinks.removeAt(index);
                              });
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: "edit",
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: "delete",
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? "Update Product" : "Save Product"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
