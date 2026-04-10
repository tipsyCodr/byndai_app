import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlyerBrandKit {
  final int footerBgColorValue;
  final int footerTextColorValue;
  final double footerOpacity;
  final int headerBgColorValue;
  final int headerTextColorValue;
  final double headerOpacity;
  final int footerStyleIndex;
  final bool headerShowLogo;
  final bool headerShowBg;

  const FlyerBrandKit({
    required this.footerBgColorValue,
    required this.footerTextColorValue,
    required this.footerOpacity,
    required this.headerBgColorValue,
    required this.headerTextColorValue,
    required this.headerOpacity,
    required this.footerStyleIndex,
    required this.headerShowLogo,
    required this.headerShowBg,
  });
}

class FlyerBrandKitService {
  static const _prefix = 'flyer_brand_kit_v1_';

  String _keyFor(String userId) => '$_prefix$userId';

  Future<void> save({
    required String userId,
    required FlyerBrandKit kit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_keyFor(userId)}_footerBg', kit.footerBgColorValue);
    await prefs.setInt('${_keyFor(userId)}_footerText', kit.footerTextColorValue);
    await prefs.setDouble('${_keyFor(userId)}_footerOpacity', kit.footerOpacity);
    await prefs.setInt('${_keyFor(userId)}_headerBg', kit.headerBgColorValue);
    await prefs.setInt('${_keyFor(userId)}_headerText', kit.headerTextColorValue);
    await prefs.setDouble('${_keyFor(userId)}_headerOpacity', kit.headerOpacity);
    await prefs.setInt('${_keyFor(userId)}_footerStyle', kit.footerStyleIndex);
    await prefs.setBool('${_keyFor(userId)}_headerLogo', kit.headerShowLogo);
    await prefs.setBool('${_keyFor(userId)}_headerBgEnabled', kit.headerShowBg);
  }

  Future<FlyerBrandKit?> load({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    if (!prefs.containsKey('${key}_footerBg')) return null;

    return FlyerBrandKit(
      footerBgColorValue: prefs.getInt('${key}_footerBg') ?? Colors.white.toARGB32(),
      footerTextColorValue: prefs.getInt('${key}_footerText') ?? Colors.black.toARGB32(),
      footerOpacity: prefs.getDouble('${key}_footerOpacity') ?? 0.9,
      headerBgColorValue: prefs.getInt('${key}_headerBg') ?? Colors.white.toARGB32(),
      headerTextColorValue: prefs.getInt('${key}_headerText') ?? Colors.black.toARGB32(),
      headerOpacity: prefs.getDouble('${key}_headerOpacity') ?? 0.8,
      footerStyleIndex: prefs.getInt('${key}_footerStyle') ?? 0,
      headerShowLogo: prefs.getBool('${key}_headerLogo') ?? false,
      headerShowBg: prefs.getBool('${key}_headerBgEnabled') ?? false,
    );
  }
}
