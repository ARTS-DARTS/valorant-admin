import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'fcm_service.dart';

class LikesService {
  static Future<void> toggleLike(String lineupId) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    final likeRef = db
        .collection('lineup_likes')
        .doc(lineupId)
        .collection('users')
        .doc(uid);
    final lineupRef = db.collection('lineups').doc(lineupId);

    bool wasLiked = false;
    String? authorId;
    String lineupTitle = '';

    await db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final lineupSnap = await tx.get(lineupRef);

      wasLiked = likeSnap.exists;
      authorId = lineupSnap.data()?['user_id'] as String?;
      lineupTitle = lineupSnap.data()?['title'] as String? ?? '';

      if (wasLiked) {
        tx.delete(likeRef);
        tx.update(lineupRef, {'likes_count': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'liked_at': FieldValue.serverTimestamp()});
        tx.update(lineupRef, {'likes_count': FieldValue.increment(1)});
      }
    });

    if (!wasLiked) {
      db.collection('analytics_events').add({
        'type': 'lineup_liked',
        'lineup_id': lineupId,
        'uid': uid,
        'ts': FieldValue.serverTimestamp(),
      }).ignore();

      if (authorId != null && authorId!.isNotEmpty && authorId != uid) {
        FcmService.notifyLineupLiked(authorId!, lineupTitle).ignore();
      }
    }
  }

  static Stream<bool> isLiked(String lineupId) {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value(false);
    return FirebaseFirestore.instance
        .collection('lineup_likes')
        .doc(lineupId)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  static Stream<int> getLikesCount(String lineupId) {
    return FirebaseFirestore.instance
        .collection('lineups')
        .doc(lineupId)
        .snapshots()
        .map((s) => s.data()?['likes_count'] as int? ?? 0);
  }
}

class NewsLikesService {
  static Future<void> toggleLike(String newsId) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    final likeRef = db
        .collection('changelog_likes')
        .doc(newsId)
        .collection('users')
        .doc(uid);
    final newsRef = db.collection('changelog').doc(newsId);

    await db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(newsRef, {'likes_count': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'liked_at': FieldValue.serverTimestamp()});
        tx.update(newsRef, {'likes_count': FieldValue.increment(1)});
      }
    });
  }

  static Stream<bool> isLiked(String newsId) {
    final uid = AuthService.userId;
    if (uid == null) return Stream.value(false);
    return FirebaseFirestore.instance
        .collection('changelog_likes')
        .doc(newsId)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists);
  }

  static Stream<int> getLikesCount(String newsId) {
    return FirebaseFirestore.instance
        .collection('changelog')
        .doc(newsId)
        .snapshots()
        .map((s) => s.data()?['likes_count'] as int? ?? 0);
  }
}
