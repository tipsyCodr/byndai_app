import 'dart:convert';

class FlyerOverlayState {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  const FlyerOverlayState({
    required this.id,
    required this.type,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': data,
    };
  }

  factory FlyerOverlayState.fromMap(Map<String, dynamic> map) {
    return FlyerOverlayState(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }
}

class FlyerEditorState {
  final String activeCategory;
  final String? selectedId;
  final bool isFooterVisible;
  final bool isHeaderVisible;
  final bool headerShowLogo;
  final bool headerShowBg;
  final int footerStyleIndex;
  final double footerOpacity;
  final double headerOpacity;
  final double barFontSize;
  final int footerBgColorValue;
  final int footerTextColorValue;
  final int headerBgColorValue;
  final int headerTextColorValue;
  final List<FlyerOverlayState> overlays;

  const FlyerEditorState({
    required this.activeCategory,
    required this.selectedId,
    required this.isFooterVisible,
    required this.isHeaderVisible,
    required this.headerShowLogo,
    required this.headerShowBg,
    required this.footerStyleIndex,
    required this.footerOpacity,
    required this.headerOpacity,
    required this.barFontSize,
    required this.footerBgColorValue,
    required this.footerTextColorValue,
    required this.headerBgColorValue,
    required this.headerTextColorValue,
    required this.overlays,
  });

  Map<String, dynamic> toMap() {
    return {
      'activeCategory': activeCategory,
      'selectedId': selectedId,
      'isFooterVisible': isFooterVisible,
      'isHeaderVisible': isHeaderVisible,
      'headerShowLogo': headerShowLogo,
      'headerShowBg': headerShowBg,
      'footerStyleIndex': footerStyleIndex,
      'footerOpacity': footerOpacity,
      'headerOpacity': headerOpacity,
      'barFontSize': barFontSize,
      'footerBgColorValue': footerBgColorValue,
      'footerTextColorValue': footerTextColorValue,
      'headerBgColorValue': headerBgColorValue,
      'headerTextColorValue': headerTextColorValue,
      'overlays': overlays.map((e) => e.toMap()).toList(),
    };
  }

  factory FlyerEditorState.fromMap(Map<String, dynamic> map) {
    final rawOverlays = (map['overlays'] as List?) ?? const [];
    return FlyerEditorState(
      activeCategory: map['activeCategory']?.toString() ?? 'Brand',
      selectedId: map['selectedId']?.toString(),
      isFooterVisible: map['isFooterVisible'] == true,
      isHeaderVisible: map['isHeaderVisible'] == true,
      headerShowLogo: map['headerShowLogo'] == true,
      headerShowBg: map['headerShowBg'] == true,
      footerStyleIndex: (map['footerStyleIndex'] as num?)?.toInt() ?? 0,
      footerOpacity: (map['footerOpacity'] as num?)?.toDouble() ?? 0.9,
      headerOpacity: (map['headerOpacity'] as num?)?.toDouble() ?? 0.8,
      barFontSize: (map['barFontSize'] as num?)?.toDouble() ?? 14,
      footerBgColorValue: (map['footerBgColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      footerTextColorValue: (map['footerTextColorValue'] as num?)?.toInt() ?? 0xFF000000,
      headerBgColorValue: (map['headerBgColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      headerTextColorValue: (map['headerTextColorValue'] as num?)?.toInt() ?? 0xFF000000,
      overlays: rawOverlays
          .whereType<Map>()
          .map((e) => FlyerOverlayState.fromMap(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FlyerEditorState.fromJson(String source) =>
      FlyerEditorState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
