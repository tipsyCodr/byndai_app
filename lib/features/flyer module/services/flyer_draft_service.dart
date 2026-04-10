import 'package:shared_preferences/shared_preferences.dart';
import '../models/flyer_editor_state.dart';

class FlyerDraftService {
  static const String _draftPrefix = 'flyer_draft_v1_';

  String _keyFor(String imageUrl) => '$_draftPrefix${imageUrl.hashCode}';

  Future<void> saveDraft(String imageUrl, FlyerEditorState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(imageUrl), state.toJson());
  }

  Future<FlyerEditorState?> loadDraft(String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(imageUrl));
    if (raw == null || raw.isEmpty) return null;
    try {
      return FlyerEditorState.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft(String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(imageUrl));
  }
}
