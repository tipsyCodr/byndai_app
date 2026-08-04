import 'package:flutter/material.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class PrivacyDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const PrivacyDynamicPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    final content = pageData['content'];
    final hero = content['hero'];
    final sections = content['sections'];
    final footer = content['footer'];

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
              // 🔥 HEADER
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
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Last Updated
                    if (content['meta'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30, left: 8),
                        child: Text(
                          "Last Updated: ${content['meta']['last_updated']}",
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),

                    ...sections.map<Widget>((section) {
                      // 🔹 TEXT SECTION
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  section['content'],
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

                      // 🔹 LIST SECTION
                      if (section['type'] == 'list') {
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                if (section['content'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 10, bottom: 10),
                                    child: Text(
                                      section['content'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ...List.generate(section['items'].length,
                                    (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 8, left: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("• ",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: colorScheme.primary)),
                                        Expanded(
                                          child: Text(
                                            section['items'][index],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }

                      // 🔹 CONTACT SECTION
                      if (section['type'] == 'contact') {
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  section['content'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.email_outlined,
                                          size: 18, color: colorScheme.primary),
                                      const SizedBox(width: 12),
                                      Text(
                                        section['email'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return const SizedBox();
                    }).toList(),
                  ],
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