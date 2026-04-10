import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gridcard/core/services/leads_provider.dart';

class LeadCategorySelector extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool isLoading;
  final int? currentUserId;

  const LeadCategorySelector({
    super.key,
    required this.categories,
    required this.isLoading,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Selector<LeadProviders, String?>(
      selector: (_, provider) => provider.selectedCategory,
      builder: (context, selectedCategory, child) {
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final categoryName = category["name"];
            final categoryId = category["id"].toString();
            final isSelected = selectedCategory == categoryId;

            return GestureDetector(
              onTap: () {
                if (currentUserId != null) {
                  context.read<LeadProviders>().setCategory(
                        categoryId,
                        currentUserId!,
                      );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
