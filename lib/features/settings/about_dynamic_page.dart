import 'package:flutter/material.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class AboutDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const AboutDynamicPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    final content = pageData['content'];
    final hero = content['content']['hero'];
    final sections = content['content']['sections'];
    final footer = content['content']['footer'];

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<AppThemeColors>();

    return Scaffold(
      backgroundColor: palette?.backgroundStart ?? colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette?.backgroundStart ?? colorScheme.surface,
              palette?.backgroundMid ?? colorScheme.surface,
              palette?.backgroundEnd ?? colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔥 HEADER WITH BACK BUTTON
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 70, horizontal: 20),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          Text(
                            hero['heading'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            hero['subheading'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.7),
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
                        backgroundColor:
                            colorScheme.onSurface.withValues(alpha: 0.1),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: colorScheme.onSurface),
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
                  children: sections.map<Widget>((section) {
                    if (section['type'] == 'text') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: GlassBox(
                          padding: const EdgeInsets.all(24),
                          borderRadius: 24,
                          opacity: isDark ? 0.05 : 0.08,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section['title'],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                section['description'],
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (section['type'] == 'cards') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8, bottom: 16),
                              child: Text(
                                section['title'],
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            Column(
                              children: List.generate(
                                section['items'].length,
                                (index) {
                                  final item = section['items'][index];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: GlassBox(
                                      padding: const EdgeInsets.all(20),
                                      borderRadius: 20,
                                      opacity: isDark ? 0.05 : 0.08,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.secondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item['description'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.5,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Text(
                  footer['text'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
