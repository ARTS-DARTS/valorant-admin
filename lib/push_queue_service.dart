import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'config/constants.dart';

/// Слушает коллекцию push_queue в Firestore.
/// Когда admin_panel.html добавляет документ — первое устройство,
/// которое его захватит, отправит push через OneSignal REST API.
/// CORS не мешает: мобильный HTTP не ограничен браузерной политикой.
class PushQueueService {
  static const _apiUrl = 'https://api.onesignal.com/notifications';

  static StreamSubscription<QuerySnapshot>? _sub;
  static Timer? _batchTimer;

  static void startListening() {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('push_queue')
        .where('processed', isEqualTo: false)
        .snapshots()
        .listen(_onSnapshot, onError: (_) {});

    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkBatches(),
    );
    _checkBatches();
  }

  static void stopListening() {
    _sub?.cancel();
    _sub = null;
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  static Future<void> _onSnapshot(QuerySnapshot snap) async {
    for (final doc in snap.docs) {
      _processDoc(doc);
    }
  }

  static Future<void> _processDoc(QueryDocumentSnapshot doc) async {
    // Атомарно захватываем документ — только первое устройство выиграет
    bool claimed = false;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        if (!fresh.exists) return;
        final data = fresh.data() as Map<String, dynamic>;
        if (data['processed'] == true) return;
        tx.update(doc.reference, {
          'processed': true,
          'processed_at': FieldValue.serverTimestamp(),
        });
        claimed = true;
      });
    } catch (_) {
      return; // транзакция проиграна другому устройству
    }
    if (!claimed) return;

    final data = doc.data() as Map<String, dynamic>;
    final title     = (data['title']      as String?) ?? '';
    final body      = (data['body']       as String?) ?? '';
    final type      = (data['type']       as String?) ?? '';
    final targetUid = (data['target_uid'] as String?)?.isNotEmpty == true
        ? data['target_uid'] as String
        : null;
    if (title.isEmpty || body.isEmpty) return;

    final notifBody = <String, dynamic>{
      'app_id': AppConstants.oneSignalAppId,
      'headings': {'en': title},
      'contents': {'en': body},
      'data': {'type': type},
      'priority': 10,
    };
    if (targetUid != null) {
      notifBody['include_aliases'] = {'external_id': [targetUid]};
      notifBody['target_channel']  = 'push';
    } else {
      notifBody['included_segments'] = ['All'];
    }

    try {
      await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Key ${AppConstants.oneSignalRestApiKey}',
        },
        body: jsonEncode(notifBody),
      );
    } catch (_) {}
  }

  // ─── Batch summary processing ─────────────────────────────────────────────

  static Future<void> _checkBatches() async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final snap = await FirebaseFirestore.instance
          .collectionGroup('notification_batches')
          .where('sent', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        if (doc.id != 'pending') continue;
        final data = doc.data();
        final scheduledAt = data['scheduled_at'] as Timestamp?;
        if (scheduledAt == null) continue;
        if (scheduledAt.millisecondsSinceEpoch > nowMs) continue;
        _processBatch(doc);
      }
    } catch (_) {}
  }

  static Future<void> _processBatch(QueryDocumentSnapshot doc) async {
    Map<String, dynamic>? batchData;
    bool claimed = false;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        if (!fresh.exists) return;
        final data = fresh.data() as Map<String, dynamic>;
        if (data['sent'] == true) return;
        final scheduledAt = data['scheduled_at'] as Timestamp?;
        if (scheduledAt == null) return;
        if (scheduledAt.millisecondsSinceEpoch >
            DateTime.now().millisecondsSinceEpoch) {
          return;
        }

        batchData = Map<String, dynamic>.from(data);
        tx.update(doc.reference, {
          'sent': true,
          'likes': {'count': 0, 'lineup_titles': []},
          'lineup_approved': {'count': 0},
          'lineup_rejected': {'count': 0},
          'duel_won': {'count': 0},
          'scheduled_at': FieldValue.delete(),
        });
        claimed = true;
      });
    } catch (_) {
      return;
    }
    if (!claimed || batchData == null) return;

    final segments = doc.reference.path.split('/');
    if (segments.length < 2) return;
    final uid = segments[1];

    final likesCount =
        (batchData!['likes'] as Map?)?['count'] as int? ?? 0;
    final approvedCount =
        (batchData!['lineup_approved'] as Map?)?['count'] as int? ?? 0;
    final rejectedCount =
        (batchData!['lineup_rejected'] as Map?)?['count'] as int? ?? 0;
    final duelWonCount =
        (batchData!['duel_won'] as Map?)?['count'] as int? ?? 0;

    final lines = <String>[];
    if (likesCount > 0) {
      lines.add('❤️ +$likesCount ${_pluralizeLikes(likesCount)} на твои лайнапы');
    }
    if (approvedCount > 0) {
      lines.add('✅ Одобрено лайнапов: $approvedCount');
    }
    if (rejectedCount > 0) {
      lines.add('🚫 Отклонено лайнапов: $rejectedCount');
    }
    if (duelWonCount > 0) {
      lines.add('⚔️ Побед в дуэлях: $duelWonCount');
    }
    if (lines.isEmpty) return;

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
          'headings': {'en': 'Valorant Lineups'},
          'contents': {'en': lines.join('\n')},
          'data': {'type': 'batch_summary'},
          'priority': 10,
        }),
      );
    } catch (_) {}
  }

  static String _pluralizeLikes(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'лайков';
    if (mod10 == 1) return 'лайк';
    if (mod10 >= 2 && mod10 <= 4) return 'лайка';
    return 'лайков';
  }
}
