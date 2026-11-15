import 'package:flutter/material.dart';
import 'package:gridcard/core/services/ai_flyer_service.dart';
import 'package:gridcard/widgets/top_alert.dart';
import 'brand_kit_page.dart';
import 'ai_flyer_history_page.dart';
import 'ai_flyer_preview_page.dart';
import 'ai_flyer_progress_sheet.dart';

class AiFlyerStudioPage extends StatefulWidget {
  final String initialMode; // 'occasion' or 'special'
  final String? initialCategory;
  final Map<String, dynamic>? initialOccasion;

  const AiFlyerStudioPage({
    super.key,
    this.initialMode = 'occasion',
    this.initialCategory,
    this.initialOccasion,
  });

  @override
  State<AiFlyerStudioPage> createState() => _AiFlyerStudioPageState();
}

class _AiFlyerStudioPageState extends State<AiFlyerStudioPage> {
  late String _mode; // 'occasion' or 'special'
  bool _isLoading = true;
  bool _isGenerating = false;

  List<Map<String, dynamic>> _todayOccasions = [];
  Map<String, dynamic>? _selectedOccasion;

  final List<String> _specialCategories = [
    'Good Morning',
    'Good Night',
    'Motivational Quotes',
    'Inspirational Thoughts',
    'Success and Achievement',
    'Business Promotion',
    'Customer Appreciation',
    'Thank You',
    'Positive Thoughts',
    'Custom Flyer',
  ];
  String _selectedCategory = 'Good Morning';

  final List<String> _languages = ['Hindi', 'English', 'Hindi + English'];
  String _selectedLanguage = 'English';

  final List<String> _designStyles = [
    'Modern',
    'Minimal',
    'Premium',
    'Corporate',
    'Traditional',
    'Festive',
  ];
  String _selectedStyle = 'Festive';

  final List<Map<String, String>> _aspectRatios = [
    {'label': '1:1 Square', 'value': '1:1', 'icon': 'square'},
    {'label': '4:5 Portrait', 'value': '4:5', 'icon': 'portrait'},
    {'label': '9:16 Story', 'value': '9:16', 'icon': 'story'},
  ];
  String _selectedAspectRatio = '1:1';

  final TextEditingController _promptController = TextEditingController();

  // Branding Toggles
  final Map<String, bool> _brandingToggles = {
    'logo': true,
    'name': true,
    'phone': true,
    'whatsapp': true,
    'address': true,
    'website': true,
  };

  Map<String, dynamic>? _brandKit;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _selectedOccasion = widget.initialOccasion;
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final occasions = await AiFlyerService.fetchTodayOccasions();
      final kit = await AiFlyerService.getBrandKit();

      setState(() {
        _todayOccasions = occasions;
        _brandKit = kit;

        if (_mode == 'occasion') {
          if (_selectedOccasion == null && _todayOccasions.isNotEmpty) {
            _selectedOccasion = _todayOccasions.first;
          } else if (_todayOccasions.isEmpty) {
            // Default to festive or modern style for special
            _mode = 'special';
            _selectedCategory = 'Business Promotion';
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load initial studio data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGenerate() async {
    if (_mode == 'occasion') {
      if (_selectedOccasion == null && _todayOccasions.isNotEmpty) {
        _selectedOccasion = _todayOccasions.first;
      } else if (_todayOccasions.isEmpty) {
        TopAlert.show(context, 'No occasion today. Please switch to Special Flyers to create a flyer.', isError: true);
        return;
      }
    }

    setState(() => _isGenerating = true);
    try {
      final categoryName = _mode == 'occasion'
          ? (_selectedOccasion?['name'] ?? 'Festival Occasion')
          : _selectedCategory;

      final int? occId = (_mode == 'occasion' && _selectedOccasion != null)
          ? (_selectedOccasion!['id'] is int
              ? _selectedOccasion!['id'] as int
              : int.tryParse(_selectedOccasion!['id'].toString()))
          : null;

      final res = await AiFlyerService.generateFlyer(
        type: _mode,
        category: categoryName,
        occasionId: occId,
        language: _selectedLanguage,
        designStyle: _selectedStyle,
        aspectRatio: _selectedAspectRatio,
        customPrompt: _promptController.text,
        brandingToggles: _brandingToggles,
      );

      final genId = res['id'];
      if (mounted) {
        // Open polling bottom sheet
        final completedFlyer = await AiFlyerProgressSheet.show(
          context,
          generationId: genId,
          title: categoryName,
        );

        if (completedFlyer != null && mounted) {
          // Open preview
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiFlyerPreviewPage(flyer: completedFlyer),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) TopAlert.show(context, 'Generation error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Flyer Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Brand Identity',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrandKitPage()),
              );
              _initData();
            },
          ),
          IconButton(
            tooltip: 'My Generated Flyers',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiFlyerHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Selector Tabs (Today's Occasion vs Special Flyers)
                  _buildModeTabs(),
                  const SizedBox(height: 20),

                  // Occasion or Category Selection
                  if (_mode == 'occasion') _buildOccasionSection() else _buildCategorySection(),
                  const SizedBox(height: 24),

                  // Language Selection
                  _buildSectionTitle('Content Language'),
                  const SizedBox(height: 10),
                  _buildLanguageChips(),
                  const SizedBox(height: 24),

                  // Design Style
                  _buildSectionTitle('Design Style'),
                  const SizedBox(height: 10),
                  _buildStyleChips(),
                  const SizedBox(height: 24),

                  // Aspect Ratio
                  _buildSectionTitle('Aspect Ratio / Size'),
                  const SizedBox(height: 10),
                  _buildAspectRatioSelector(),
                  const SizedBox(height: 24),

                  // Optional Custom Prompt
                  _buildSectionTitle('Custom Instructions (Optional)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _promptController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Include vibrant fireworks, golden lamps, royal navy theme...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Business Branding & Toggles
                  _buildBrandingSection(),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _handleGenerate,
              icon: _isGenerating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating ? 'Synthesizing Flyer...' : 'Generate AI Flyer',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = 'occasion'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == 'occasion' ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      size: 18,
                      color: _mode == 'occasion' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Today's Occasion",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mode == 'occasion' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = 'special'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == 'special' ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 18,
                      color: _mode == 'special' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Special Flyers',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mode == 'special' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionSection() {
    final theme = Theme.of(context);
    if (_todayOccasions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 36, color: theme.disabledColor),
            const SizedBox(height: 8),
            const Text(
              'No festival or national occasion listed for today.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Switch to Special Flyers to create greetings, motivational quotes, or business ads.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.disabledColor),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _mode = 'special'),
              child: const Text('Browse Special Flyers'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Today\'s Occasion'),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _todayOccasions.length,
            itemBuilder: (context, i) {
              final occasion = _todayOccasions[i];
              final isSelected = _selectedOccasion?['id'] == occasion['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedOccasion = occasion),
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.festival_outlined, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              occasion['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        occasion['description'] ?? 'Festival greetings & wishes',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Flyer Category'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _specialCategories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageChips() {
    return Row(
      children: _languages.map((lang) {
        final isSelected = _selectedLanguage == lang;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Center(child: Text(lang)),
              selected: isSelected,
              onSelected: (v) => setState(() => _selectedLanguage = lang),
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStyleChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _designStyles.map((style) {
        final isSelected = _selectedStyle == style;
        return ChoiceChip(
          label: Text(style),
          selected: isSelected,
          onSelected: (val) => setState(() => _selectedStyle = style),
          selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.secondary : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAspectRatioSelector() {
    return Row(
      children: _aspectRatios.map((item) {
        final val = item['value']!;
        final isSelected = _selectedAspectRatio == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedAspectRatio = val),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    item['icon'] == 'square'
                        ? Icons.crop_square
                        : item['icon'] == 'portrait'
                            ? Icons.crop_portrait
                            : Icons.smartphone,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBrandingSection() {
    final theme = Theme.of(context);
    final bizName = _brandKit?['business_name'] ?? 'My Business';
    final hasLogo = _brandKit?['logo_url'] != null && _brandKit!['logo_url'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Business Branding',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BrandKitPage()),
                  );
                  _initData();
                },
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit Identity', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Text(
            'Branding is cleanly overlaid onto your flyer. Toggle what you want displayed:',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildBrandToggleChip('logo', 'Logo ${hasLogo ? '✓' : '(No logo)'}'),
              _buildBrandToggleChip('name', 'Name ($bizName)'),
              _buildBrandToggleChip('phone', 'Phone Number'),
              _buildBrandToggleChip('whatsapp', 'WhatsApp Badge'),
              _buildBrandToggleChip('website', 'Website URL'),
              _buildBrandToggleChip('address', 'Address'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandToggleChip(String key, String label) {
    final isSelected = _brandingToggles[key] ?? true;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _brandingToggles[key] = val;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
    );
  }
}
