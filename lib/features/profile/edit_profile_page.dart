import 'package:flutter/material.dart';
import './profile_tab.dart';
import './links_tab.dart';
import './keywords_tab.dart';
import './business_info_tab.dart';
import './product/products_tab.dart';
import './review/review_tab.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails;
  final int initialTabIndex;
  const EditProfilePage(
      {super.key, this.userDetails, this.initialTabIndex = 0});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasChanges = false;

  void _onChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint("🟢 EDIT PAGE DATA: ${widget.userDetails}");
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isDark ? colorScheme.surfaceContainerHighest : null,
          foregroundColor: colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          title: Text(
            "Edit Profile",
            style: TextStyle(color: colorScheme.onSurface),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: "Profile"),
              Tab(text: "Links"),
              Tab(text: "Keywords"),
              Tab(text: "Business Info"),
              Tab(text: "Products"),
              Tab(text: "Review"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            ProfileTab(userDetails: widget.userDetails, onSaved: _onChanged),
            LinksTab(userDetails: widget.userDetails, onSaved: _onChanged),
            KeywordsTab(userDetails: widget.userDetails, onSaved: _onChanged),
            BusinessInfoTab(
                userDetails: widget.userDetails, onSaved: _onChanged),
            ProductsTab(userDetails: widget.userDetails, onSaved: _onChanged),
            ReviewTab(userDetails: widget.userDetails, onSaved: _onChanged),
          ],
        ),
      ),
    );
  }
}
