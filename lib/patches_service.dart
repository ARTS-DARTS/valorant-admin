import 'package:cloud_firestore/cloud_firestore.dart';

class PatchesService {
  PatchesService._();

  static Future<String?> getCurrentPatch() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('patches')
          .where('is_current', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCurrentPatch(String version) async {
    final db = FirebaseFirestore.instance;
    await db.collection('patches').doc(version).set({
      'version': version,
      'is_current': true,
      'released_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await markPreviousPatchOutdated(version);
  }

  static Future<void> markPreviousPatchOutdated(String newVersion) async {
    final db = FirebaseFirestore.instance;

    // Снять is_current у всех старых патчей
    final oldPatches = await db
        .collection('patches')
        .where('is_current', isEqualTo: true)
        .where('version', isNotEqualTo: newVersion)
        .get();

    final batch = db.batch();
    for (final doc in oldPatches.docs) {
      batch.update(doc.reference, {'is_current': false});
    }

    // Пометить лайнапы старого патча устаревшими
    // Второй фильтр по пустой строке — на стороне клиента, т.к. Firestore
    // не допускает два isNotEqualTo на одном поле в одном запросе.
    final oldLineups = await db
        .collection('lineups')
        .where('is_outdated', isEqualTo: false)
        .where('patch_version', isNotEqualTo: newVersion)
        .get();
    for (final doc in oldLineups.docs) {
      final pv = doc.data()['patch_version'] as String? ?? '';
      if (pv.isNotEmpty) {
        batch.update(doc.reference, {'is_outdated': true});
      }
    }

    await batch.commit();
  }
}
