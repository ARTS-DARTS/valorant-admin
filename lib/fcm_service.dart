import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'config/constants.dart';

/// Push notification service — OneSignal REST API architecture.
///
/// Per-user pushes:
///   Writes to Firestore (in-app list) + sends push via OneSignal REST API.
///   Targeting is done by external_id = Firebase UID (set via OneSignal.login).
///
/// Broadcasts (changelog):
///   Sends to the OneSignal "All" segment — reaches all subscribed devices.
class FcmService {
  static const _apiUrl = 'https://api.onesignal.com/notifications';

  // ─── Internal senders ────────────────────────────────────────────────────

  static Future<void> _sendToUser(
      String uid, String title, String body, String type) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .add({
      'type': type,
      'title': title,
      'body': body,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    try {
      await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key ${AppConstants.oneSignalRestApiKey}',
        },
        body: jsonEncode({
          'app_id': AppConstants.oneSignalAppId,
          'include_aliases': {
            'external_id': [uid],
          },
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
          'data': {'type': type},
          'priority': 10,
        }),
      );
    } catch (_) {}
  }

  static Future<void> _sendToAll(
      String title, String body, String type) async {
    try {
      await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key ${AppConstants.oneSignalRestApiKey}',
        },
        body: jsonEncode({
          'app_id': AppConstants.oneSignalAppId,
          'included_segments': ['All'],
          'headings': {'en': title},
          'contents': {'en': body},
          'data': {'type': type},
          'priority': 10,
        }),
      );
    } catch (_) {}
  }

  // ─── Batch writer ────────────────────────────────────────────────────────

  // Writes an event into users/{uid}/notification_batches/pending.
  // On first event (or after reset), creates the doc with all counters at 0
  // and sets scheduled_at = now + 2h. Subsequent events just increment.
  static Future<void> _writeToBatch(
      String uid, String type, {String? lineupTitle}) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_batches')
        .doc('pending');

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final doc = await tx.get(ref);
        final data = doc.data();
        final needsReset = !doc.exists ||
            data?['sent'] == true ||
            data?['scheduled_at'] == null;

        if (needsReset) {
          final newDoc = <String, dynamic>{
            'likes': {'count': 0, 'lineup_titles': []},
            'lineup_approved': {'count': 0},
            'lineup_rejected': {'count': 0},
            'duel_won': {'count': 0},
            'last_updated': FieldValue.serverTimestamp(),
            'scheduled_at': Timestamp.fromDate(
                DateTime.now().add(const Duration(hours: 2))),
            'sent': false,
          };
          if (type == 'likes') {
            newDoc['likes'] = {
              'count': 1,
              'lineup_titles': lineupTitle != null ? [lineupTitle] : [],
            };
          } else {
            newDoc[type] = {'count': 1};
          }
          tx.set(ref, newDoc);
        } else {
          final updates = <String, dynamic>{
            '$type.count': FieldValue.increment(1),
            'last_updated': FieldValue.serverTimestamp(),
          };
          if (type == 'likes' && lineupTitle != null) {
            updates['likes.lineup_titles'] =
                FieldValue.arrayUnion([lineupTitle]);
          }
          tx.update(ref, updates);
        }
      });
    } catch (_) {}
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  static Future<void> notifyLineupApproved(
      String uid, String lineupTitle) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .add({
      'type': 'lineup_approved',
      'title': 'Лайнап одобрен! ✅',
      'body': 'Твой лайнап "$lineupTitle" опубликован',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _writeToBatch(uid, 'lineup_approved');
  }

  static Future<void> notifyLineupRejected(
      String uid, String lineupTitle) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .add({
      'type': 'lineup_rejected',
      'title': 'Лайнап отклонён ❌',
      'body': 'Твой лайнап "$lineupTitle" не прошёл модерацию',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _writeToBatch(uid, 'lineup_rejected');
  }

  static Future<void> notifyLineupLiked(
      String uid, String lineupTitle) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .add({
      'type': 'lineup_liked',
      'title': '❤️ Новый лайк',
      'body': 'Твой лайнап "$lineupTitle" нравится людям',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _writeToBatch(uid, 'likes', lineupTitle: lineupTitle);
  }

  static Future<void> notifyModeratorApplicationResult(
      String uid, bool approved) async {
    if (approved) {
      await _sendToUser(
        uid,
        'Поздравляем! 🎉',
        'Твоя заявка одобрена — ты теперь модератор приложения!',
        'moderator_approved',
      );
    } else {
      await _sendToUser(
        uid,
        'Заявка на модератора отклонена',
        'К сожалению, твоя заявка на роль модератора не была одобрена',
        'moderator_rejected',
      );
    }
  }

  static Future<void> notifyNewChangelog(String title, String body) async {
    await _sendToAll(title, body, 'changelog');
  }

  static Future<void> notifyFeedbackReply(String uid, String reply) async {
    final body = reply.length > 80 ? '${reply.substring(0, 80)}...' : reply;
    await _sendToUser(
      uid,
      'Новый ответ на отзыв 💬',
      body,
      'feedback_reply',
    );
  }
}
