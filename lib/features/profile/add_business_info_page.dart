

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddBusinessInfoPage extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? businessInfo;

  const AddBusinessInfoPage({
    super.key,
    this.isEdit = false,
    this.businessInfo,
  });

  @override
  State<AddBusinessInfoPage> createState() => _AddBusinessInfoPageState();
}

class _AddBusinessInfoPageState extends State<AddBusinessInfoPage> {
  // Controllers
  final legalNameCtrl = TextEditingController();
  final gstCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final bankAccCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final upiCtrl = TextEditingController();

  List<Map<String, dynamic>> industries = [];
  bool isIndustriesLoading = false;
  // Dropdown
  int? selectedIndustryId;

  // user_id from storage
  int? userId;

  // base url
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imgBaseUrl = AppConfig.apiProfileImg;

  // payment_qr image
  XFile? paymentQrImage;

  // existing qr from backend (edit mode)
  String? existingQrPath;

  bool isLoading = false;

  int? businessId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _prefillIfEdit();
    _fetchIndustries();
  }

  Future<void> _fetchIndustries() async {
    setState(() => isIndustriesLoading = true);

    try {
      final headers = await _getHeaders();
      final url = Uri.parse("$_baseUrl/industries");

      final res = await http.get(url, headers: headers);

      final jsonData = jsonDecode(res.body);

      if (res.statusCode == 200 && jsonData["status"] == true) {
        final List list = (jsonData["data"] ?? []) as List;

        industries = list.map((e) {
          return {
            "id": e["id"],
            "title": e["title"],
          };
        }).toList();

        // ✅ IMPORTANT: edit mode me agar selectedIndustryId list me exist nahi karta
        // to dropdown crash na ho
        if (selectedIndustryId != null &&
            !industries.any((x) => x["id"] == selectedIndustryId)) {
          selectedIndustryId = null;
        }

        if (mounted) setState(() {});
      } else {
        throw (jsonData["message"] ?? "Industries load failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Industries Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isIndustriesLoading = false);
    }
  }

  void _prefillIfEdit() {
    if (!widget.isEdit) return;
    if (widget.businessInfo == null) return;

    final data = widget.businessInfo!;

    businessId = int.tryParse(data["id"].toString());

    legalNameCtrl.text = (data["legal_name"] ?? "").toString();
    gstCtrl.text = (data["gst_no"] ?? "").toString();
    addressCtrl.text = (data["address"] ?? "").toString();
    descriptionCtrl.text = (data["description"] ?? "").toString();
    bankAccCtrl.text = (data["bank_acc_no"] ?? "").toString();
    ifscCtrl.text = (data["ifsc_code"] ?? "").toString();
    branchCtrl.text = (data["branch_name"] ?? "").toString();
    websiteCtrl.text = (data["website_url"] ?? "").toString();
    emailCtrl.text = (data["contact_email"] ?? "").toString();
    upiCtrl.text = (data["upi_id"] ?? "").toString();

    selectedIndustryId = int.tryParse((data["industry_id"] ?? "").toString());

    existingQrPath = (data["payment_qr"] ?? "").toString().trim();
  }

  Future<void> _loadUserId() async {
    try {
      final id = await UserStorageService().getUserId();
      setState(() {
        userId = id;
      });
    } catch (_) {}
  }

  // HEADERS
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _pickQrImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        paymentQrImage = picked;
      });
    }
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ================== SUBMIT (ADD / UPDATE) ==================
  Future<void> _submit() async {
    if (isLoading) return;

    if (legalNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Legal Name required")),
      );
      return;
    }

    if (selectedIndustryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Industry select karo")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final headers = await _getHeaders();

      late Uri url;

      // ✅ ADD
      if (!widget.isEdit) {
        url = Uri.parse("$_baseUrl/business-info");
      }
      // ✅ UPDATE
      else {
        if (businessId == null) {
          throw "Business ID missing";
        }
        url = Uri.parse("$_baseUrl/business-info-update/$businessId");
      }

      final request = http.MultipartRequest("POST", url);
      request.headers.addAll(headers);

      // Fields
      request.fields["legal_name"] = legalNameCtrl.text.trim();
      request.fields["industry_id"] = selectedIndustryId.toString();
      request.fields["gst_no"] = gstCtrl.text.trim();
      request.fields["address"] = addressCtrl.text.trim();
      request.fields["description"] = descriptionCtrl.text.trim();
      request.fields["bank_acc_no"] = bankAccCtrl.text.trim();
      request.fields["ifsc_code"] = ifscCtrl.text.trim();
      request.fields["branch_name"] = branchCtrl.text.trim();
      request.fields["website_url"] = websiteCtrl.text.trim();
      request.fields["contact_email"] = emailCtrl.text.trim();
      request.fields["upi_id"] = upiCtrl.text.trim();

      // File upload (optional)
      if (paymentQrImage != null) {
        if (kIsWeb) {
          final bytes = await paymentQrImage!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              "payment_qr",
              bytes,
              filename: paymentQrImage!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              "payment_qr",
              paymentQrImage!.path,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      final jsonData = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 200) {
        final message = jsonData["message"] ?? "Success";

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.toString())),
        );

        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        final msg = jsonData["message"] ?? "Something went wrong";

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString())),
        );
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

  @override
  void dispose() {
    legalNameCtrl.dispose();
    gstCtrl.dispose();
    addressCtrl.dispose();
    descriptionCtrl.dispose();
    bankAccCtrl.dispose();
    ifscCtrl.dispose();
    branchCtrl.dispose();
    websiteCtrl.dispose();
    emailCtrl.dispose();
    upiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? "Edit Business Info" : "Add Business Info";
    final buttonText =
        widget.isEdit ? "Update Business Info" : "Save Business Info";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _inputField(label: "Legal Name", controller: legalNameCtrl),              

              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<int>(
                  value: industries.any((e) => e["id"] == selectedIndustryId)
                      ? selectedIndustryId
                      : null,
                  decoration: InputDecoration(
                    labelText: "Industry",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: industries.map((industry) {
                    return DropdownMenuItem<int>(
                      value: industry["id"],
                      child: Text(industry["title"].toString()),
                    );
                  }).toList(),
                  onChanged: isIndustriesLoading
                      ? null
                      : (val) {
                          setState(() {
                            selectedIndustryId = val;
                          });
                        },
                ),
              ),

              _inputField(label: "GST No", controller: gstCtrl),

              _inputField(
                label: "Address",
                controller: addressCtrl,
                maxLines: 3,
              ),

              _inputField(
                label: "Description",
                controller: descriptionCtrl,
                maxLines: 3,
              ),

              _inputField(
                label: "Bank Account No",
                controller: bankAccCtrl,
                keyboardType: TextInputType.number,
              ),

              _inputField(label: "IFSC Code", controller: ifscCtrl),
              _inputField(label: "Branch Name", controller: branchCtrl),

              _inputField(
                label: "Website URL",
                controller: websiteCtrl,
                keyboardType: TextInputType.url,
              ),

              _inputField(
                label: "Contact Email",
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),

              _inputField(label: "UPI ID", controller: upiCtrl),

              // Payment QR Upload
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
                      "Payment QR",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    // ✅ NEW selected
                    if (paymentQrImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                paymentQrImage!.path,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(paymentQrImage!.path),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      )

                    // ✅ OLD image from backend
                    else if (existingQrPath != null &&
                        existingQrPath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          "$_imgBaseUrl/$existingQrPath",
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              height: 140,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("QR load failed"),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("No QR selected"),
                        ),
                      ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickQrImage,
                        icon: const Icon(Icons.image),
                        label: Text(widget.isEdit
                            ? "Change QR Image"
                            : "Upload QR Image"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Save / Update button
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
                      : Text(buttonText),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
