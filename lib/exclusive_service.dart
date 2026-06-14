import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class ExclusiveService {
  ExclusiveService._();

  static final ValueNotifier<int> accessNotifier = ValueNotifier(0);

  static Future<bool> hasAccess() async {
    final uid = AuthService.userId;
    if (uid == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('exclusive_access')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return false;
      final expires = doc.data()?['access_expires_at'];
      if (expires == null) return false;
      final expiresAt = (expires as Timestamp).toDate();
      return DateTime.now().isBefore(expiresAt);
    } catch (_) {
      try {
        final cached = await FirebaseFirestore.instance
            .collection('exclusive_access')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (!cached.exists) return false;
        final expires = cached.data()?['access_expires_at'];
        if (expires == null) return false;
        final expiresAt = (expires as Timestamp).toDate();
        return DateTime.now().isBefore(expiresAt);
      } catch (_) {
        return false;
      }
    }
  }

  /// Выдать доступ на 1 час (вызывается после rewarded рекламы)
  static Future<void> grantAccess() async {
    final uid = AuthService.userId;
    if (uid == null) return;
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    await FirebaseFirestore.instance
        .collection('exclusive_access')
        .doc(uid)
        .set(
      {'access_expires_at': Timestamp.fromDate(expiresAt)},
      SetOptions(merge: true),
    );
    accessNotifier.value++;
    NotificationService.showLocalNotification(
      'exclusive_access'.hashCode,
      '🎁 Эксклюзивный контент доступен!',
      'У тебя есть доступ к эксклюзивным лайнапам на 1 час',
      payload: 'exclusive_access',
    ).ignore();
  }
}
