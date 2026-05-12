import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/flyer_service.dart';
import 'flyer_editor_page.dart';

class FlyerHomePage extends StatefulWidget {
  const FlyerHomePage({super.key});

  @override
  State<FlyerHomePage> createState() => _FlyerHomePageState();
}

class _FlyerHomePageState extends State<FlyerHomePage> {
  List<Map<String, dynamic>> upcomingFestivals = [];
  List<Map<String, dynamic>> miscCategories = [];
  bool isLoading = true;
  bool isOccasionsLoading = false;

  Map<String, dynamic>? selectedOccasion;
  Map<String, dynamic>? selectedMiscCategory;
  String search = "";
  DateTime selectedDate = DateTime.now();
  Set<String> occasionDates = {};
  List<DateTime> dateRange = List.generate(
    14,
    (index) => DateTime.now().add(Duration(days: index)),
  );

  @override
  void initState() {
    super.initState();
    loadData();
  }



  /// ✅ API CALL
  void loadData() async {
    try {
      final miscData = await FlyerService.fetchAll();
      final upcomingData = await FlyerService.fetchUpcoming(
        date: DateFormat('MM-dd').format(selectedDate),
      );

      setState(() {
        // Extract all dates that have an occasion/festival
        occasionDates = miscData
            .where((cat) => cat['date'] != null)
            .map((cat) => cat['date'].toString())
            .toSet();

        // Filter out festive categories from the Misc/Special section
        miscCategories = miscData.where((cat) => cat['type'] != 'festive').toList();
        upcomingFestivals = upcomingData;
        
        // Filter to only select the occasion that matches the current selected date
        final selectedDateStr = DateFormat('MM-dd').format(selectedDate);
        final currentOccasions = upcomingData.where((f) => f['date'] == selectedDateStr).toList();
        
        if (currentOccasions.isNotEmpty) {
          selectedOccasion = currentOccasions.first;
        } else {
          selectedOccasion = null;
        }
        
        // Ensure we select the first non-festive category
        if (miscCategories.isNotEmpty) {
          selectedMiscCategory = miscCategories.first;
        }
        
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchUpcomingForSelectedDate() async {
    setState(() => isOccasionsLoading = true);
    try {
      final data = await FlyerService.fetchUpcoming(
        date: DateFormat('MM-dd').format(selectedDate),
      );
      setState(() {
        upcomingFestivals = data;
        
        // Filter to only select the occasion that matches the current selected date
        final selectedDateStr = DateFormat('MM-dd').format(selectedDate);
        final currentOccasions = data.where((f) => f['date'] == selectedDateStr).toList();
        
        selectedOccasion = currentOccasions.isNotEmpty ? currentOccasions.first : null;
        isOccasionsLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching upcoming: $e");
      setState(() => isOccasionsLoading = false);
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMonthSection(),
                          _buildDateSelector(),
                          const SizedBox(height: 24),
                          _buildOccasionsSection(),
                          const SizedBox(height: 32),
                          _buildMiscSection(),
                          SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => search = val),
                decoration: InputDecoration(
                  hintText: "Search occasion...",
                  prefixIcon: const Icon(Icons.search, size: 22),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSection() {
    final monthName = DateFormat('MMMM yyyy').format(selectedDate);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        monthName,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dateRange.length,
        itemBuilder: (context, index) {
          final date = dateRange[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final dayName = DateFormat('E').format(date);
          final dayNum = DateFormat('d').format(date);

          return GestureDetector(
            onTap: () {
              setState(() => selectedDate = date);
              _fetchUpcomingForSelectedDate();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                              : Theme.of(context).disabledColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNum,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  if (occasionDates.contains(DateFormat('MM-dd').format(date)))
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOccasionsSection() {
    final selectedDateStr = DateFormat('MM-dd').format(selectedDate);
    final filteredFestivals = upcomingFestivals.where((f) {
      final name = f['name']?.toString().toLowerCase() ?? '';
      final festivalDate = f['date']?.toString() ?? '';
      return name.contains(search.toLowerCase()) && festivalDate == selectedDateStr;
    }).toList();

    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final sectionTitle = isToday ? "Today's Occasions" : "Occasions";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(sectionTitle),
        if (isOccasionsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _buildPillList(
            items: filteredFestivals.map((f) => f['name'].toString()).toList(),
            selectedItem: selectedOccasion?['name']?.toString() ?? "",
            onSelected: (name) {
              setState(() {
                selectedOccasion = upcomingFestivals.firstWhere((f) => f['name'] == name);
              });
            },
          ),
          _buildFlyerGrid(_extractFlyerUrls(selectedOccasion)),
        ],
      ],
    );
  }

  Widget _buildMiscSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Special Flyers"),
        _buildPillList(
          items: miscCategories.map((c) => c['name'].toString()).toList(),
          selectedItem: selectedMiscCategory?['name']?.toString() ?? "",
          onSelected: (name) {
            setState(() {
              selectedMiscCategory = miscCategories.firstWhere((c) => c['name'] == name);
            });
          },
        ),
        _buildFlyerGrid(_extractFlyerUrls(selectedMiscCategory), isHorizontal: true),
      ],
    );
  }

  List<String> _extractFlyerUrls(Map<String, dynamic>? data) {
    if (data == null || data['flyers'] == null) return [];
    final flyers = data['flyers'] as List;
    return flyers.map((f) => f['image_path'].toString()).toList();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Widget _buildPillList({
    required List<String> items,
    required String selectedItem,
    required Function(String) onSelected,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text("No categories available", style: TextStyle(color: Theme.of(context).disabledColor)),
      );
    }

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = selectedItem == item;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: FilterChip(
              label: Text(formatText(item)),
              selected: isSelected,
              onSelected: (_) => onSelected(item),
              backgroundColor: Theme.of(context).cardTheme.color,
              selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.secondary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlyerGrid(List<String> images, {bool isHorizontal = false}) {
    if (images.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_outlined, color: Theme.of(context).disabledColor, size: 32),
              const SizedBox(height: 8),
              Text("No flyers found in this category", style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (isHorizontal) {
      return SizedBox(
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final img = images[index];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 200,
                child: _buildFlyerCard(img),
              ),
            );
          },
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return _buildFlyerCard(images[index]);
      },
    );
  }

  Widget _buildFlyerCard(String img) {
    return GestureDetector(
      onTap: () {
        final fullUrl = AppConfig.getFullUrl(img) ?? img;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlyerEditorPage(imageUrl: fullUrl),
          ),
        );
      },
      child: Hero(
        tag: img,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            image: DecorationImage(
              image: NetworkImage(AppConfig.getFullUrl(img) ?? img),
              fit: BoxFit.cover,
            ),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
            padding: const EdgeInsets.all(12),
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
