import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class BusinessInfoPage extends StatefulWidget {
  const BusinessInfoPage({super.key});

  @override
  State<BusinessInfoPage> createState() => _BusinessInfoPageState();
}

class _BusinessInfoPageState extends State<BusinessInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyController;
  late TextEditingController _gstController;
  late TextEditingController _addressController;
  late TextEditingController _accNoController;
  late TextEditingController _ifscController;
  late TextEditingController _branchController;
  File? _paymentQr;

  @override
  void initState() {
    super.initState();
    final business = context.read<ProfileProvider>().businessInfo;
    _companyController =
        TextEditingController(text: business?['company_name'] ?? '');
    _gstController = TextEditingController(text: business?['gst_no'] ?? '');
    _addressController =
        TextEditingController(text: business?['address'] ?? '');
    _accNoController =
        TextEditingController(text: business?['bank_acc_no'] ?? '');
    _ifscController = TextEditingController(text: business?['ifsc_code'] ?? '');
    _branchController =
        TextEditingController(text: business?['branch_name'] ?? '');
  }

  Future<void> _pickQr() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _paymentQr = File(file.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<ProfileProvider>().updateBusinessInfo(
      fields: {
        'company_name': _companyController.text,
        'gst_no': _gstController.text,
        'address': _addressController.text,
        'bank_acc_no': _accNoController.text,
        'ifsc_code': _ifscController.text,
        'branch_name': _branchController.text,
      },
      paymentQr: _paymentQr,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business info updated successfully")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ProfileProvider>().isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text("Business Information",
            style: TextStyle(color: colorScheme.primary)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _save,
            icon: isLoading
                ? CupertinoActivityIndicator(color: colorScheme.primary)
                : Icon(Icons.check, color: colorScheme.primary),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, "Company Details"),
              _buildTextField(context, _companyController, "Company Name",
                  CupertinoIcons.briefcase),
              _buildTextField(
                  context, _gstController, "GST Number", CupertinoIcons.number),
              _buildTextField(context, _addressController, "Office Address",
                  CupertinoIcons.location,
                  maxLines: 2),
              const SizedBox(height: 24),
              _buildSectionTitle(context, "Banking & Payment"),
              _buildTextField(context, _accNoController, "Account Number",
                  CupertinoIcons.creditcard),
              _buildTextField(context, _ifscController, "IFSC Code",
                  CupertinoIcons.number_square),
              _buildTextField(context, _branchController, "Branch Name",
                  CupertinoIcons.house_fill),
              const SizedBox(height: 20),
              _buildQrPicker(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    );
  }

  Widget _buildTextField(BuildContext context, TextEditingController controller,
      String label, IconData icon,
      {int maxLines = 1}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: colorScheme.onSurface),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
          prefixIcon: Icon(icon,
              color: colorScheme.onSurface.withOpacity(0.3), size: 20),
          filled: true,
          fillColor:
              isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildQrPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment QR Code",
            style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickQr,
          child: Container(
            height: 180,
            width: 180,
            decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colorScheme.onSurface.withOpacity(0.05))),
            child: _paymentQr == null
                ? Center(
                    child: Icon(CupertinoIcons.qrcode,
                        color: colorScheme.onSurface.withOpacity(0.2),
                        size: 50))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_paymentQr!, fit: BoxFit.cover)),
          ),
        ),
      ],
    );
  }
}
