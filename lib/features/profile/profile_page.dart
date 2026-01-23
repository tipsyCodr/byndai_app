import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/core/services/profile_provider.dart';
import 'package:gridcard/features/profile/business_info_page.dart';
import 'package:gridcard/features/profile/links_management_page.dart';
import 'package:gridcard/features/profile/products_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchAllProfileData();
    });
  }

  Future<void> _updateImage(bool isProfile) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final provider = context.read<ProfileProvider>();
      if (isProfile) {
        await provider.updateProfile(profilePic: File(image.path));
      } else {
        await provider.updateProfile(profileBanner: File(image.path));
      }
    }
  }

  void _showEditProfileDialog() {
    final profile = context.read<ProfileProvider>().profileData;
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(
        text: profile?['name'] ??
            profile?['fname'] ??
            profile?['master_user']?['fname'] ??
            '');
    final deptController = TextEditingController(text: profile?['dept'] ?? '');
    final desgController = TextEditingController(text: profile?['desg'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title:
            Text('Edit Profile', style: TextStyle(color: colorScheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle:
                      TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
            ),
            TextField(
              controller: deptController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                  labelText: 'Department',
                  labelStyle:
                      TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
            ),
            TextField(
              controller: desgController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                  labelText: 'Designation',
                  labelStyle:
                      TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await context.read<ProfileProvider>().updateProfile(
                    fname: nameController.text,
                    dept: deptController.text,
                    desg: desgController.text,
                  );
              if (mounted) Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profileData;
    final business = profileProvider.businessInfo;
    final links = profileProvider.links;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        centerTitle: true,
        title:
            Text('Your Profile', style: TextStyle(color: colorScheme.primary)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.primary),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: profileProvider.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: colorScheme.primary,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: isDark
                                    ? colorScheme.surfaceContainerHighest
                                    : Colors.blueGrey,
                                backgroundImage:
                                    (profile?['profile_pic'] != null)
                                        ? NetworkImage(profile!['profile_pic'])
                                        : null,
                                child: (profile?['profile_pic'] == null)
                                    ? Icon(CupertinoIcons.person_fill,
                                        size: 60, color: colorScheme.onPrimary)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _updateImage(true),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.camera_alt,
                                      size: 20, color: colorScheme.onPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile?['name'] ??
                              profile?['fname'] ??
                              profile?['master_user']?['fname'] ??
                              profile?['user']?['name'] ??
                              "User Name",
                          style: TextStyle(
                              color: isDark
                                  ? colorScheme.onSurface
                                  : colorScheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          profile?['email'] ??
                              profile?['user']?['email'] ??
                              "Email not set",
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Business Info Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(context, "Business Info"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const BusinessInfoPage()),
                          );
                        },
                        child: Text("Edit",
                            style: TextStyle(color: colorScheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(context, [
                    _buildInfoRow(context, CupertinoIcons.briefcase, "Company",
                        business?['company_name'] ?? "Not set"),
                    _buildInfoRow(context, CupertinoIcons.person_2,
                        "Department", profile?['dept'] ?? "Not set"),
                    _buildInfoRow(context, CupertinoIcons.tag, "Designation",
                        profile?['desg'] ?? "Not set"),
                  ]),

                  const SizedBox(height: 24),

                  // Social Links Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(context, "Social Links"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const LinksManagementPage()),
                          );
                        },
                        child: Text("Manage",
                            style: TextStyle(color: colorScheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  links.isEmpty
                      ? Text("No links added yet",
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.3)))
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: links.map((link) {
                            return Chip(
                              backgroundColor: isDark
                                  ? colorScheme.surfaceContainerHighest
                                  : Colors.grey[100],
                              avatar: Icon(CupertinoIcons.link,
                                  size: 16, color: colorScheme.primary),
                              label: Text(
                                  link['title'] ?? link['link_name'] ?? "Link",
                                  style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 12)),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 24),

                  // Products Section Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(context, "Products"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProductsPage()),
                          );
                        },
                        child: Text("Manage",
                            style: TextStyle(color: colorScheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withOpacity(0.5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12)),
                Text(value,
                    style:
                        TextStyle(color: colorScheme.onSurface, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
