import 'package:flutter/material.dart';

class SupportDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const SupportDynamicPage({super.key, required this.pageData});

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
            /// 🔥 HERO SECTION
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
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
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
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
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            /// 🔥 CONTENT
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: sections.map<Widget>((section) {
                  /// TEXT SECTION
                  if (section['type'] == 'text') {
                    return _buildCard(
                      title: section['title'],
                      child: Text(
                        section['content'],
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black54,
                        ),
                      ),
                    );
                  }

                  /// FAQ SECTION
                  if (section['type'] == 'faq') {
                    return _buildCard(
                      title: section['title'],
                      child: Column(
                        children: List.generate(
                          section['items'].length,
                          (index) {
                            final item = section['items'][index];
                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                item['question'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12.0),
                                  child: Text(
                                    item['answer'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }

                  /// CONTACT FORM
                  if (section['type'] == 'contact_form') {
                    return _buildCard(
                      title: section['title'],
                      child: Column(
                        children: [
                          TextField(
                            decoration: _inputDecoration("Your Name"),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            decoration: _inputDecoration("Your Email"),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            maxLines: 4,
                            decoration:
                                _inputDecoration("Describe your issue..."),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor:
                                    const Color(0xff4f46e5),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {},
                              child: const Text("Submit Request"),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Or email us at: ${section['support_email']}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          )
                        ],
                      ),
                    );
                  }

                  return const SizedBox();
                }).toList(),
              ),
            ),

            /// 🔥 FOOTER
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

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff4f46e5))),
          const SizedBox(height: 15),
          child
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}