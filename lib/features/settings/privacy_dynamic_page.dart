import 'package:flutter/material.dart';

class PrivacyDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const PrivacyDynamicPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    final content = pageData['content'];
    final hero = content['hero'];
    final sections = content['sections'];
    final footer = content['footer'];

    final gradient = hero['background_gradient'];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [

            // 🔥 HEADER
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 70, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(int.parse("0xff${gradient[0].substring(1)}")),
                        Color(int.parse("0xff${gradient[1].substring(1)}")),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          hero['heading'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hero['subheading'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 🔥 CONTENT
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Last Updated
                  if (content['meta'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(
                        "Last Updated: ${content['meta']['last_updated']}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  ...sections.map<Widget>((section) {

                    // 🔹 TEXT SECTION
                    if (section['type'] == 'text') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section['title'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4f46e5),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              section['content'],
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 🔹 LIST SECTION
                    if (section['type'] == 'list') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section['title'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4f46e5),
                              ),
                            ),
                            if (section['content'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 10),
                                child: Text(
                                  section['content'],
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black87),
                                ),
                              ),
                            ...List.generate(section['items'].length, (index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6, left: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text("• ",
                                        style: TextStyle(fontSize: 16)),
                                    Expanded(
                                      child: Text(
                                        section['items'][index],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }

                    // 🔹 CONTACT SECTION
                    if (section['type'] == 'contact') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section['title'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4f46e5),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              section['content'],
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section['email'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return const SizedBox();
                  }).toList(),
                ],
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
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}