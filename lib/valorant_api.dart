import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ValorantApi {
  static const _baseUrl = 'https://valorant-api.com/v1';
  static const _cacheKey = 'agents_cache_v4';
  static const _mapsCacheKey = 'maps_splashes_cache_v2';

  /// Загружает агентов из сети с retry. При успехе обновляет кэш.
  static Future<List<Map<String, dynamic>>> getAgents({int maxRetries = 3}) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(
                '$_baseUrl/agents?isPlayableCharacter=true&language=ru-RU'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final agents = List<Map<String, dynamic>>.from(
              json.decode(response.body)['data']);
          await _saveCache(agents);
          return agents;
        }
        lastError = Exception('HTTP ${response.statusCode}');
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    throw lastError ?? Exception('Неизвестная ошибка');
  }

  /// Возвращает кэшированный список агентов или null если кэша нет.
  static Future<List<Map<String, dynamic>>?> getCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Удаляем все старые версии кэша
      await prefs.remove('agents_cache_v1');
      await prefs.remove('agents_cache_v2');
      await prefs.remove('agents_cache_v3');
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return List<Map<String, dynamic>>.from(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(List<Map<String, dynamic>> agents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(agents));
    } catch (_) {}
  }

  /// Возвращает (displayName → listViewIcon) для всех карт.
  static Future<Map<String, String>> getMaps() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/maps'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final maps = List<Map<String, dynamic>>.from(
            json.decode(response.body)['data']);
        final result = <String, String>{};
        for (final m in maps) {
          final name = m['displayName'] as String?;
          final icon = (m['splash'] ?? m['listViewIcon']) as String?;
          if (name != null && icon != null && icon.isNotEmpty) {
            result[name] = icon;
          }
        }
        _saveMapsCache(result);
        return result;
      }
    } catch (_) {}
    return getCachedMaps();
  }

  static Future<Map<String, String>> getCachedMaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mapsCacheKey);
      if (raw == null) return {};
      return Map<String, String>.from(json.decode(raw));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMapsCache(Map<String, String> maps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mapsCacheKey, json.encode(maps));
    } catch (_) {}
  }

  /// Clears all JSON caches so they are re-fetched from the network.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_mapsCacheKey);
    } catch (_) {}
  }
}
