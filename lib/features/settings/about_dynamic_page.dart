import 'package:flutter/material.dart';

class AboutDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const AboutDynamicPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    final content = pageData['content'];
    final hero = content['content']['hero'];
    final sections = content['content']['sections'];
    final footer = content['content']['footer'];

    final gradient = content['styles']['header']['gradient'];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔥 HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(int.parse("0xff${gradient[0].substring(1)}")),
                    Color(int.parse("0xff${gradient[1].substring(1)}")),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    hero['heading'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    hero['subheading'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // 🔥 CONTENT
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: sections.map<Widget>((section) {
                  if (section['type'] == 'text') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['title'],
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4f46e5)),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            section['description'],
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }

                  if (section['type'] == 'cards') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['title'],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff4f46e5),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ✅ Replaced GridView with Column
                          Column(
                            children: List.generate(
                              section['items'].length,
                              (index) {
                                final item = section['items'][index];

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 15),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff9333ea),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['description'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox();
                }).toList(),
              ),
            ),

            // 🔥 FOOTER
            Container(
              width: double.infinity,
              color: const Color(0xff111827),
              padding: const EdgeInsets.all(25),
              child: Center(
                child: Text(
                  footer['text'],
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
