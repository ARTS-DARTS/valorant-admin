import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgentsConfigService {
  static const _prefix = 'agents_config_';
  static const _ttlMs = 3600000; // 1 hour

  static const _disabledKey   = 'agents_config_disabled_v1';
  static const _disabledTsKey = 'agents_config_disabled_v1_ts';

  static String _id(String agentName) => agentName.replaceAll('/', '_');

  /// Returns the set of agent displayNames hidden via admin panel.
  /// Cached for 1 hour. On any error returns empty set (show all agents).
  static Future<Set<String>> getDisabledAgents() async {
    final prefs = await SharedPreferences.getInstance();
    final ts  = prefs.getInt(_disabledTsKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age < _ttlMs) {
      final raw = prefs.getString(_disabledKey);
      if (raw != null) {
        try { return Set<String>.from(jsonDecode(raw) as List); } catch (_) {}
      }
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents_config')
          .doc('_disabled_agents')
          .get();
      final disabled = doc.exists
          ? List<String>.from(doc.data()?['disabled'] ?? [])
          : <String>[];
      await prefs.setString(_disabledKey, jsonEncode(disabled));
      await prefs.setInt(_disabledTsKey, DateTime.now().millisecondsSinceEpoch);
      return Set<String>.from(disabled);
    } catch (_) {
      final raw = prefs.getString(_disabledKey);
      if (raw == null) return {};
      try { return Set<String>.from(jsonDecode(raw) as List); } catch (_) { return {}; }
    }
  }

  /// Removes agents whose displayName is in [disabled] from [agents].
  static List<Map<String, dynamic>> applyDisabled(
      List<Map<String, dynamic>> agents, Set<String> disabled) {
    if (disabled.isEmpty) return agents;
    return agents
        .where((a) => !disabled.contains(a['displayName'] as String? ?? ''))
        .toList();
  }

  /// Returns map of abilityName → enabled for the given agent+category.
  /// Returns null if no config document exists (all abilities enabled by default).
  static Future<Map<String, bool>?> getAgentConfig(
      String agentName, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_prefix${_id(agentName)}_$category';
    final tsKey = '${cacheKey}_ts';

    final ts = prefs.getInt(tsKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age < _ttlMs) {
      final json = prefs.getString(cacheKey);
      if (json != null) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return map.map((k, v) => MapEntry(k, v as bool));
        } catch (_) {}
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents_config')
          .doc(_id(agentName))
          .collection('categories')
          .doc(category)
          .get();
      if (!doc.exists) return null;
      final abilities =
          (doc.data()?['abilities'] as Map<String, dynamic>?) ?? {};
      await prefs.setString(cacheKey, jsonEncode(abilities));
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      return abilities.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      final json = prefs.getString(cacheKey);
      if (json == null) return null;
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {
        return null;
      }
    }
  }

  /// Filters the abilities list by the agent+category config.
  /// If no config exists, returns the full list unchanged.
  static Future<List<Map<String, dynamic>>> filterAbilities(
      String agentName,
      String category,
      List<Map<String, dynamic>> abilities) async {
    final config = await getAgentConfig(agentName, category);
    if (config == null) return abilities;
    return abilities.where((a) {
      final name = a['displayName'] as String? ?? '';
      return config[name] != false;
    }).toList();
  }

  static Future<void> invalidate(String agentName, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_prefix${_id(agentName)}_$category';
    await prefs.remove('${cacheKey}_ts');
  }
}
