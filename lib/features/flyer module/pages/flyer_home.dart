import 'package:flutter/material.dart';
import '../../../core/services/festival_service.dart'; // ✅ API service import
import 'flyer_editor_page.dart';

class FlyerHomePage extends StatefulWidget {
  const FlyerHomePage({super.key});

  @override
  State<FlyerHomePage> createState() => _FlyerHomePageState();
}

class _FlyerHomePageState extends State<FlyerHomePage> {
  Map<String, List<String>> festivalImages = {};
  bool isLoading = true;

  String selectedFestival = "RepublicDay";
  String search = "";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// ✅ API CALL
  void loadData() async {
    try {
      final data = await FestivalService.fetchFestivalImages();

      setState(() {
        festivalImages = data;
        selectedFestival = data.keys.isNotEmpty ? data.keys.first : "";
        isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  /// ✅ Text format (RepublicDay → Republic Day)
  String formatText(String text) {
    return text.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => "${match.group(1)} ${match.group(2)}",
    );
  }

  @override
  Widget build(BuildContext context) {
    /// ✅ LOADING STATE
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    /// ✅ FILTERED FESTIVALS
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
            child: festivals.isEmpty
                ? const Center(child: Text("No festivals found"))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: festivals.length,
                    itemBuilder: (_, i) {
                      final festival = festivals[i];

                      return Padding(
                        padding: const EdgeInsets.all(6),
                        child: ChoiceChip(
                          label: Text(formatText(festival)), // ✅ formatted text
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
            child: festivalImages[selectedFestival] == null
                ? const Center(child: Text("No images found"))
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: festivalImages[selectedFestival]!.map((img) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlyerEditorPage(imageUrl: img),
                            ),
                          );
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: MediaQuery.of(context).size.width * 0.4,
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color.fromARGB(255, 23, 17, 107),
                              width: 0.2,
                            ),
                            color: Colors.black,
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
