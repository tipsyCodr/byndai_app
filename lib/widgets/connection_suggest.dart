import 'package:flutter/material.dart';

class ConnectionSuggest extends StatelessWidget {
  const ConnectionSuggest({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: PageController(viewportFraction: .6),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : Colors.grey[100],
              border:
                  Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle,
                  size: 60,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Name',
                  style: TextStyle(
                      color:
                          isDark ? colorScheme.onSurface : colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Occupation',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
