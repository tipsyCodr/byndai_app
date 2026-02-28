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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Profile"),
            Tab(text: "Links"),
            Tab(text: "Keywords"),
            Tab(text: "Business Info"),
            Tab(text: "Product"),
            Tab(text: "Review"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ProfileTab(userDetails: widget.userDetails),
          LinksTab(userDetails: widget.userDetails),
          KeywordsTab(userDetails: widget.userDetails),
          BusinessInfoTab(userDetails: widget.userDetails),
          ProductsTab(userDetails: widget.userDetails),
          ReviewTab(userDetails: widget.userDetails),
        ],
      ),
    );
  }
}
