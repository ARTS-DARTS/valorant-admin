import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class BadgeType {
  static const pioneer = 'pioneer';
  static const youtuber = 'youtuber';
  static const twitch = 'twitch';
  static const tiktok = 'tiktok';
  static const sponsor = 'sponsor';
}

class UserBadge {
  final String type;
  final String? url;
  final DateTime? grantedAt;

  const UserBadge({required this.type, this.url, this.grantedAt});

  factory UserBadge.fromMap(Map<String, dynamic> map) => UserBadge(
    type: map['type'] as String,
    url: map['url'] as String?,
    grantedAt: (map['granted_at'] as dynamic)?.toDate(),
  );

  String get emoji {
    switch (type) {
      case BadgeType.pioneer: return '🚀';
      case BadgeType.youtuber: return '🎥';
      case BadgeType.twitch: return '🟣';
      case BadgeType.tiktok: return '🎵';
      case BadgeType.sponsor: return '💎';
      default: return '⭐';
    }
  }

  String get label {
    switch (type) {
      case BadgeType.pioneer: return 'Пионер';
      case BadgeType.youtuber: return 'YouTube';
      case BadgeType.twitch: return 'Twitch';
      case BadgeType.tiktok: return 'TikTok';
      case BadgeType.sponsor: return 'Спонсор';
      default: return type;
    }
  }

  Color get color {
    switch (type) {
      case BadgeType.pioneer: return const Color(0xFFFF4655);
      case BadgeType.youtuber: return const Color(0xFFFF0000);
      case BadgeType.twitch: return const Color(0xFF9147FF);
      case BadgeType.tiktok: return const Color(0xFF69C9D0);
      case BadgeType.sponsor: return const Color(0xFFFFD700);
      default: return Colors.white54;
    }
  }
}

class BadgeService {
  static const _col = 'user_badges';

  static final Map<String, List<UserBadge>> _cache = {};

  static Future<List<UserBadge>> getBadges(String uid) async {
    if (_cache.containsKey(uid)) return _cache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance.collection(_col).doc(uid).get();
      if (!doc.exists) return _cache[uid] = [];
      final raw = List<Map<String, dynamic>>.from(doc.data()?['badges'] ?? []);
      return _cache[uid] = raw.map(UserBadge.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static void invalidateCache(String uid) => _cache.remove(uid);

  static bool hasSponsor(List<UserBadge> badges) =>
      badges.any((b) => b.type == BadgeType.sponsor);

  static Future<bool> currentUserIsSponsor() async {
    final uid = AuthService.userId;
    if (uid == null) return false;
    final badges = await getBadges(uid);
    return hasSponsor(badges);
  }
}
