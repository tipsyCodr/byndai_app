import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color glassTop;
  final Color glassBottom;
  final Color dockActive;
  final Color dockInactive;
  final Color heroStart;
  final Color heroEnd;
  final Color neonAccent;

  const AppThemeColors({
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.glassTop,
    required this.glassBottom,
    required this.dockActive,
    required this.dockInactive,
    required this.heroStart,
    required this.heroEnd,
    required this.neonAccent,
  });

  @override
  AppThemeColors copyWith({
    Color? backgroundStart,
    Color? backgroundMid,
    Color? backgroundEnd,
    Color? glassTop,
    Color? glassBottom,
    Color? dockActive,
    Color? dockInactive,
    Color? heroStart,
    Color? heroEnd,
    Color? neonAccent,
  }) {
    return AppThemeColors(
      backgroundStart: backgroundStart ?? this.backgroundStart,
      backgroundMid: backgroundMid ?? this.backgroundMid,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
      glassTop: glassTop ?? this.glassTop,
      glassBottom: glassBottom ?? this.glassBottom,
      dockActive: dockActive ?? this.dockActive,
      dockInactive: dockInactive ?? this.dockInactive,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      neonAccent: neonAccent ?? this.neonAccent,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    covariant ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t)!,
      backgroundMid: Color.lerp(backgroundMid, other.backgroundMid, t)!,
      backgroundEnd: Color.lerp(backgroundEnd, other.backgroundEnd, t)!,
      glassTop: Color.lerp(glassTop, other.glassTop, t)!,
      glassBottom: Color.lerp(glassBottom, other.glassBottom, t)!,
      dockActive: Color.lerp(dockActive, other.dockActive, t)!,
      dockInactive: Color.lerp(dockInactive, other.dockInactive, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      neonAccent: Color.lerp(neonAccent, other.neonAccent, t)!,
    );
  }
}

class AppTheme {
  static TextTheme _headlineTheme(Color textColor) {
    return GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: GoogleFonts.sora(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      displayMedium: GoogleFonts.sora(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      displaySmall: GoogleFonts.sora(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.sora(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.sora(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.sora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleLarge: GoogleFonts.sora(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D213D),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF1D213D),
      secondary: const Color(0xFF2F6DFF),
      surface: const Color(0xFFF5F8FF),
      onSurface: const Color(0xFF10213D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _headlineTheme(colorScheme.onSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.88),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1D213D), width: 1.5),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppThemeColors(
          backgroundStart: Color(0xFFF7FAFF),
          backgroundMid: Color(0xFFEEF4FF),
          backgroundEnd: Color(0xFFE5EEFF),
          glassTop: Color(0xFFFFFFFF),
          glassBottom: Color(0xFFF4F8FF),
          dockActive: Color(0xFF1D213D),
          dockInactive: Color(0xFF7680A0),
          heroStart: Color(0xFF1D213D),
          heroEnd: Color(0xFF2F6DFF),
          neonAccent: Color(0xFF30A8F8),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC4C7FF),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFC4C7FF),
      secondary: const Color(0xFF1BE7D3),
      onSecondary: const Color(0xFF061526),
      surface: const Color(0xFF060D2D),
      onSurface: const Color(0xFFE6E9FF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _headlineTheme(colorScheme.onSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF242D4A).withValues(alpha: 0.82),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFFC5CCFF).withValues(alpha: 0.18),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF273253).withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.primary.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: colorScheme.primary.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC4C7FF), width: 1.5),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppThemeColors(
          backgroundStart: Color(0xFF020618),
          backgroundMid: Color(0xFF0B0E2A),
          backgroundEnd: Color(0xFF16193D),
          glassTop: Color(0xFF2E3553),
          glassBottom: Color(0xFF252C46),
          dockActive: Color(0xFFF3F4FF),
          dockInactive: Color(0xFF9BA4CC),
          heroStart: Color(0xFFBFC4FF),
          heroEnd: Color(0xFF1BE7D3),
          neonAccent: Color(0xFF1BE7D3),
        ),
      ],
    );
  }
}
