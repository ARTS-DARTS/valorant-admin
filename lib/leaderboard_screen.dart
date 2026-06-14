import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'level_system.dart';
import 'level_badge.dart';
import 'app_theme.dart';

enum _Sort { lineups, likes }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _Sort _sort = _Sort.lineups;
  late final Future<QuerySnapshot> _usersFuture;
  Future<Map<String, int>>? _likesFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = FirebaseFirestore.instance
        .collection('users')
        .where('is_banned', isEqualTo: false)
        .limit(100)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text('ТОП АВТОРОВ',
            style: TextStyle(
                color: t.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: Column(
        children: [
          // Sort toggle
          Container(
            color: t.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _sortChip('По лайнапам', _Sort.lineups, t),
                const SizedBox(width: 8),
                _sortChip('По лайкам', _Sort.likes, t),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: t.primary));
                }

                if (_sort == _Sort.likes) {
                  return _likesLeaderboard(snapshot.data!.docs, t);
                }
                return _lineupsLeaderboard(snapshot.data!.docs, t);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, _Sort sort, AppThemeData t) {
    final active = _sort == sort;
    return GestureDetector(
      onTap: () => setState(() => _sort = sort),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primary : t.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.primary : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : t.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _lineupsLeaderboard(
      List<QueryDocumentSnapshot> docs, AppThemeData t) {
    final users = docs
        .map((doc) =>
            {...doc.data() as Map<String, dynamic>, 'uid': doc.id})
        .where((u) => (u['approved_lineups'] ?? 0) > 0)
        .toList()
      ..sort((a, b) =>
          (b['approved_lineups'] ?? 0).compareTo(a['approved_lineups'] ?? 0));
    final top = users.take(50).toList();

    if (top.isEmpty) return _emptyState(t);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: top.length,
      itemBuilder: (context, index) {
        final user = top[index];
        final approved = user['approved_lineups'] ?? 0;
        return _userTile(user, index + 1, approved, '$approved лайнапов', t);
      },
    );
  }

  Widget _likesLeaderboard(
      List<QueryDocumentSnapshot> docs, AppThemeData t) {
    _likesFuture ??= _loadLikesPerUser(docs.map((d) => d.id).toList());
    return FutureBuilder<Map<String, int>>(
      future: _likesFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: t.primary));
        }
        final likesMap = snap.data!;
        final users = docs
            .map((doc) =>
                {...doc.data() as Map<String, dynamic>, 'uid': doc.id})
            .where((u) => (likesMap[u['uid']] ?? 0) > 0)
            .toList()
          ..sort((a, b) => (likesMap[b['uid']] ?? 0)
              .compareTo(likesMap[a['uid']] ?? 0));
        final top = users.take(50).toList();

        if (top.isEmpty) return _emptyState(t);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: top.length,
          itemBuilder: (context, index) {
            final user = top[index];
            final likes = likesMap[user['uid']] ?? 0;
            return _userTile(user, index + 1,
                user['approved_lineups'] ?? 0, '❤️ $likes лайков', t);
          },
        );
      },
    );
  }

  Future<Map<String, int>> _loadLikesPerUser(List<String> uids) async {
    // Sum likes_count on approved lineups per user
    final snap = await FirebaseFirestore.instance
        .collection('lineups')
        .where('status', isEqualTo: 'approved')
        .limit(500)
        .get();
    final result = <String, int>{};
    for (final doc in snap.docs) {
      final uid = doc.data()['user_id'] as String? ?? '';
      if (uid.isEmpty) continue;
      result[uid] = (result[uid] ?? 0) + (doc.data()['likes_count'] as int? ?? 0);
    }
    return result;
  }

  Widget _userTile(Map<String, dynamic> user, int place, int approved,
      String subtitle, AppThemeData t) {
    final name = user['name'] ?? 'Аноним';
    final levelData = LevelSystem.getLevel(approved);
    final color = Color(levelData['color'] as int);
    final isAnimated = levelData['animated'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: place <= 3 ? color : t.border,
          width: place <= 3 ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: _placeWidget(place, color, t),
        title: Row(
          children: [
            Flexible(
              child: Text(name,
                  style: TextStyle(
                      color: t.textPrimary, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            LevelBadge(approvedLineups: approved, animated: isAnimated),
          ],
        ),
        subtitle: Text(
          '${levelData['icon']} ${levelData['name']} • $subtitle',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ),
    );
  }

  Widget _emptyState(AppThemeData t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, color: t.border, size: 56),
          const SizedBox(height: 12),
          Text('Пока никто не опубликовал лайнапы',
              style: TextStyle(color: t.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _placeWidget(int place, Color color, AppThemeData t) {
    if (place == 1) return const Text('🥇', style: TextStyle(fontSize: 28));
    if (place == 2) return const Text('🥈', style: TextStyle(fontSize: 28));
    if (place == 3) return const Text('🥉', style: TextStyle(fontSize: 28));
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: t.surface2, borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text('$place',
            style: TextStyle(
                color: t.textSecondary, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
