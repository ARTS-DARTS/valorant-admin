import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'duel_model.dart';

class DuelService {
  static final _fs = FirebaseFirestore.instance;

  static Stream<List<Duel>> getActiveDuels() {
    return _fs
        .collection('duels')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Duel.fromDoc).toList());
  }

  static Stream<Duel?> getDuel(String duelId) {
    return _fs
        .collection('duels')
        .doc(duelId)
        .snapshots()
        .map((s) => s.exists ? Duel.fromDoc(s) : null);
  }

  static Future<void> vote(String duelId, int lineupNumber) async {
    final uid = AuthService.userId;
    if (uid == null) throw Exception('Не авторизован');

    final duelRef = _fs.collection('duels').doc(duelId);
    final voterRef = duelRef.collection('voters').doc(uid);

    await _fs.runTransaction((tx) async {
      final voterSnap = await tx.get(voterRef);
      if (voterSnap.exists) throw Exception('Ты уже проголосовал в этой дуэли');

      tx.set(voterRef, {
        'choice': lineupNumber,
        'votedAt': FieldValue.serverTimestamp(),
      });
      tx.update(duelRef, {
        if (lineupNumber == 1) 'votes1': FieldValue.increment(1)
        else 'votes2': FieldValue.increment(1),
      });
    });
  }

  static Future<int?> hasVoted(String duelId) async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    final snap = await _fs
        .collection('duels')
        .doc(duelId)
        .collection('voters')
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    return (snap.data()?['choice'] as num?)?.toInt();
  }
}
