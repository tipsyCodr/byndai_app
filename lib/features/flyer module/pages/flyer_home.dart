import 'package:flutter/material.dart';
import '../data/festival_data.dart';
import 'editor_page.dart';

class FlyerHomePage extends StatefulWidget {
  const FlyerHomePage({super.key});

  @override
  State<FlyerHomePage> createState() => _FlyerHomePageState();
}

class _FlyerHomePageState extends State<FlyerHomePage> {
  String selectedFestival = "Diwali";
  String search = "";

  @override
  Widget build(BuildContext context) {
    final festivals = festivalImages.keys
        .where((e) => e.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Flyer Builder")),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (val) => setState(() => search = val),
              decoration: InputDecoration(
                hintText: "Search festival...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          /// 🎉 FESTIVAL CHIPS
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: festivals.length,
              itemBuilder: (_, i) {
                final festival = festivals[i];

                return Padding(
                  padding: const EdgeInsets.all(6),
                  child: ChoiceChip(
                    label: Text(festival),
                    selected: selectedFestival == festival,
                    onSelected: (_) {
                      setState(() => selectedFestival = festival);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          /// 🖼 IMAGES LIST
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: festivalImages[selectedFestival]!.map((img) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorPage(imageUrl: img),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(img),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}