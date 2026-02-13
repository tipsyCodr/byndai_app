import 'package:flutter/material.dart';
import './profile_tab.dart';
import './links_tab.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userDetails; 
  const EditProfilePage({super.key, this.userDetails});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    // const Center(child: Text("Links Page Content")),
    const Center(child: Text("Keywords Page Content")),
    const Center(child: Text("Business Info Page Content")),
    const Center(child: Text("Product Page Content")),
    const Center(child: Text("Review Page Content")),
  ],
),
    );
  }
}
