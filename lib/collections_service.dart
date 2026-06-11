import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class CollectionsService {
  CollectionsService._();

  static final _db = FirebaseFirestore.instance;

  static String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Коллекции текущего пользователя ─────────────────────────────────────

  static Stream<QuerySnapshot> myCollections() {
    final uid = AuthService.userId;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('collections')
        .where('owner_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static void _validateCollectionFields(String title, String description) {
    if (title.trim().isEmpty || title.length > 100) throw ArgumentError('Название: 1–100 символов');
    if (description.length > 500) throw ArgumentError('Описание: макс. 500 символов');
  }

  static Future<String> createCollection({
    required String title,
    String description = '',
  }) async {
    _validateCollectionFields(title, description);
    final uid = AuthService.userId;
    if (uid == null) throw Exception('Не авторизован');
    final code = _generateShareCode();
    final ref = await _db.collection('collections').add({
      'title': title,
      'description': description,
      'owner_uid': uid,
      'lineup_ids': <String>[],
      'created_at': FieldValue.serverTimestamp(),
      'share_code': code,
    });
    return ref.id;
  }

  static Future<void> updateCollection({
    required String collectionId,
    required String title,
    String description = '',
  }) async {
    _validateCollectionFields(title, description);
    await _db.collection('collections').doc(collectionId).update({
      'title': title,
      'description': description,
    });
  }

  static Future<void> deleteCollection(String collectionId) async {
    await _db.collection('collections').doc(collectionId).delete();
  }

  static Future<void> addLineupToCollection({
    required String collectionId,
    required String lineupId,
  }) async {
    await _db.collection('collections').doc(collectionId).update({
      'lineup_ids': FieldValue.arrayUnion([lineupId]),
    });
  }

  static Future<void> removeLineupFromCollection({
    required String collectionId,
    required String lineupId,
  }) async {
    await _db.collection('collections').doc(collectionId).update({
      'lineup_ids': FieldValue.arrayRemove([lineupId]),
    });
  }

  // ─── Найти коллекцию по share_code ───────────────────────────────────────

  static Future<DocumentSnapshot?> findByShareCode(String code) async {
    final snap = await _db
        .collection('collections')
        .where('share_code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  // ─── Скопировать чужую коллекцию себе ────────────────────────────────────

  static Future<void> copyCollection(DocumentSnapshot source) async {
    final uid = AuthService.userId;
    if (uid == null) throw Exception('Не авторизован');
    final data = source.data() as Map<String, dynamic>;
    await _db.collection('collections').add({
      'title': '${data['title'] ?? 'Коллекция'} (копия)',
      'description': data['description'] ?? '',
      'owner_uid': uid,
      'lineup_ids': List<String>.from(data['lineup_ids'] ?? []),
      'created_at': FieldValue.serverTimestamp(),
      'share_code': _generateShareCode(),
    });
  }

  // ─── Коллекции, в которых есть данный лайнап ─────────────────────────────

  static Future<List<Map<String, dynamic>>> collectionsContaining(
      String lineupId) async {
    final uid = AuthService.userId;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('collections')
          .where('owner_uid', isEqualTo: uid)
          .where('lineup_ids', arrayContains: lineupId)
          .get();
      return snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
    } catch (_) {
      return [];
    }
  }
}
