import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

Future<void> _logAnalytics(String type, String lineupId) async {
  try {
    await FirebaseFirestore.instance.collection('analytics_events').add({
      'type': type,
      'lineup_id': lineupId,
      'uid': AuthService.userId,
      'ts': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

class FavoritesService {
  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = AuthService.userId;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('favorites')
        .doc(uid)
        .collection('items');
  }

  static Future<void> toggleFavorite(String lineupId) async {
    final col = _col();
    if (col == null) return;
    final doc = col.doc(lineupId);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
    } else {
      await doc.set({'saved_at': FieldValue.serverTimestamp()});
      _logAnalytics('lineup_favorited', lineupId);
    }
  }

  static Stream<bool> isFavorite(String lineupId) {
    final col = _col();
    if (col == null) return Stream.value(false);
    return col.doc(lineupId).snapshots().map((s) => s.exists);
  }

  static Future<void> removeFavorite(String lineupId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(lineupId).delete();
  }

  static Stream<List<String>> getFavorites() {
    final col = _col();
    if (col == null) return Stream.value([]);
    return col
        .orderBy('saved_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
