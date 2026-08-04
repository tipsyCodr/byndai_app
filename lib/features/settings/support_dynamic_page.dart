import 'package:flutter/material.dart';
import 'package:gridcard/widgets/glass_box.dart';
import 'package:gridcard/core/theme/app_theme.dart';

class SupportDynamicPage extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const SupportDynamicPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    final content = pageData['content'];
    final hero = content['hero'];
    final sections = content['sections'];
    final footer = content['footer'];

    final colorScheme = Theme.of(context).colorScheme;
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
              /// 🔥 HERO SECTION
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 80, horizontal: 20),
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
                        context,
                        title: section['title'],
                        child: Text(
                          section['content'],
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    }

                    /// FAQ SECTION
                    if (section['type'] == 'faq') {
                      return _buildCard(
                        context,
                        title: section['title'],
                        child: Column(
                          children: List.generate(
                            section['items'].length,
                            (index) {
                              final item = section['items'][index];
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  iconColor: colorScheme.primary,
                                  collapsedIconColor: colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  title: Text(
                                    item['question'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16.0),
                                      child: Text(
                                        item['answer'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }

                    /// CONTACT FORM
                    if (section['type'] == 'contact_form') {
                      return _buildCard(
                        context,
                        title: section['title'],
                        child: Column(
                          children: [
                            TextField(
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration:
                                  _inputDecoration(context, "Your Name"),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration:
                                  _inputDecoration(context, "Your Email"),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              maxLines: 4,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration(
                                  context, "Describe your issue..."),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.onSurface,
                                  foregroundColor: colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {},
                                child: const Text(
                                  "Submit Request",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Or email us at: ${section['support_email']}",
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
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

  Widget _buildCard(BuildContext context,
      {required String title, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            child
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}