import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuideContentService {
  static const _prefix = 'guide_content_';
  static const _ttlMs = 86400000; // 24 часа

  static Future<Map<String, dynamic>?> getCategory(String categoryKey) async {
    final prefs = await SharedPreferences.getInstance();
    final tsKey = '$_prefix${categoryKey}_ts';
    final dataKey = '$_prefix$categoryKey';

    final ts = prefs.getInt(tsKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age < _ttlMs) {
      final json = prefs.getString(dataKey);
      if (json != null) {
        try {
          return jsonDecode(json) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('guide_content')
          .doc(categoryKey)
          .get();
      if (!doc.exists) return _getCached(prefs, dataKey);
      final data = doc.data()!;
      await prefs.setString(dataKey, jsonEncode(data));
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      return data;
    } catch (_) {
      return _getCached(prefs, dataKey);
    }
  }

  static Map<String, dynamic>? _getCached(SharedPreferences prefs, String key) {
    final json = prefs.getString(key);
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> invalidate(String categoryKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix${categoryKey}_ts');
  }
}
