import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus { none, soft, required }

class ForceUpdateService {
  static const _packageId = 'com.artsdarts.valorantlineups';

  /// Проверяет версию и возвращает статус обновления.
  /// В Firestore settings/app_version нужно только поле latest_version.
  /// Разница в 1 патч = мягкое, 2+ = обязательное.
  static Future<({UpdateStatus status, String? latestVersion})> checkUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_version')
          .get();
      if (!doc.exists) return (status: UpdateStatus.none, latestVersion: null);

      final latest = doc.data()?['latest_version'] as String?;
      if (latest == null || latest.isEmpty) {
        return (status: UpdateStatus.none, latestVersion: null);
      }

      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      if (!_isLessThan(current, latest)) {
        return (status: UpdateStatus.none, latestVersion: null);
      }

      final currentParts = _parse(current);
      final latestParts = _parse(latest);

      final diff =
          (latestParts[0] - currentParts[0]) * 100 +
          (latestParts[1] - currentParts[1]) * 10 +
          (latestParts[2] - currentParts[2]);

      if (diff >= 2) {
        return (status: UpdateStatus.required, latestVersion: latest);
      } else {
        return (status: UpdateStatus.soft, latestVersion: latest);
      }
    } catch (_) {
      return (status: UpdateStatus.none, latestVersion: null);
    }
  }

  // Обратная совместимость
  static Future<bool> isUpdateRequired() async {
    final result = await checkUpdate();
    return result.status == UpdateStatus.required;
  }

  static bool _isLessThan(String current, String min) {
    final c = _parse(current);
    final m = _parse(min);
    for (int i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(
        3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }

  static String get playStoreUrl => 'market://details?id=$_packageId';
  static String get playStoreFallbackUrl =>
      'https://play.google.com/store/apps/details?id=$_packageId';
}
