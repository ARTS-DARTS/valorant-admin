import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'level_badge.dart';
import 'app_theme.dart';
import 'fcm_service.dart';
import 'app_snack_bar.dart';
import 'video_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _allMapNames = [
    'Haven', 'Bind', 'Ascent', 'Split', 'Icebox',
    'Breeze', 'Fracture', 'Pearl', 'Lotus', 'Sunset', 'Abyss', 'Corrode',
  ];
  static const _allMapFiles = {
    'Haven':    'assets/maps/Haven_minimap.png',
    'Bind':     'assets/maps/Bind_minimap.png',
    'Ascent':   'assets/maps/Ascent_minimap.png',
    'Split':    'assets/maps/Split_minimap.png',
    'Icebox':   'assets/maps/Icebox_minimap.png',
    'Breeze':   'assets/maps/Breeze_minimap.png',
    'Fracture': 'assets/maps/Fracture_minimap.png',
    'Pearl':    'assets/maps/Pearl_minimap.png',
    'Lotus':    'assets/maps/Lotus_minimap.png',
    'Sunset':   'assets/maps/Sunset_minimap.png',
    'Abyss':    'assets/maps/Abyss_minimap.png',
    'Corrode':  'assets/maps/Corrode_minimap.png',
  };

  Set<String> _ratedPool = {
    'Ascent', 'Breeze', 'Fracture', 'Haven', 'Lotus', 'Pearl', 'Split'
  };
  bool _poolLoading = true;

  final _changelogTitleCtrl = TextEditingController();
  final _changelogBodyCtrl = TextEditingController();
  String _changelogType = 'update';
  bool _changelogPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadMapPool();
  }

  @override
  void dispose() {
    _changelogTitleCtrl.dispose();
    _changelogBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMapPool() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('map_pool')
          .get();
      if (doc.exists) {
        final maps = List<String>.from(doc.data()?['maps'] ?? []);
        if (maps.isNotEmpty && mounted) {
          setState(() => _ratedPool = Set.from(maps));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _poolLoading = false);
  }

  Future<void> _saveMapPool() async {
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('map_pool')
        .set({'maps': _ratedPool.toList()});
  }

  Future<void> _toggleMapPool(String mapName) async {
    final newSet = Set<String>.from(_ratedPool);
    if (newSet.contains(mapName)) {
      if (newSet.length <= 1) return;
      newSet.remove(mapName);
    } else {
      newSet.add(mapName);
    }
    setState(() => _ratedPool = newSet);
    await _saveMapPool();
  }

  Future<void> banUser(String userId, String username) async {
    final t = AppThemeNotifier.of(context);
    final ok = await _confirm(t, 'Заблокировать?', '$username\n\nПользователь не сможет отправлять лайнапы.');
    if (!ok) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'is_banned': true});
      _snack('$username заблокирован 🚫', Colors.red);
    } catch (e) {
      _snack('Что-то пошло не так. Попробуйте ещё раз', Colors.orange);
    }
  }

  Future<void> unbanUser(String userId, String username) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'is_banned': false});
      _snack('$username разблокирован ✅', Colors.green);
    } catch (e) {
      _snack('Что-то пошло не так. Попробуйте ещё раз', Colors.orange);
    }
  }

  Future<void> deleteUser(String uid, String username) async {
    final t = AppThemeNotifier.of(context);
    final ok = await _confirm(t, 'Удалить аккаунт?',
        '$username\n\nБудут удалены: аккаунт и pending лайнапы.\nОдобренные останутся.');
    if (!ok) return;
    try {
      final pending = await FirebaseFirestore.instance
          .collection('lineups')
          .where('user_id', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final d in pending.docs) {
        final videoUrl = d.data()['video_url'] as String?;
        if (videoUrl != null && videoUrl.isNotEmpty) {
          await VideoService.deleteByUrl(videoUrl);
        }
        await d.reference.delete();
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      _snack('Аккаунт $username удалён', Colors.red);
    } catch (e) {
      _snack('Что-то пошло не так. Попробуйте ещё раз', Colors.orange);
    }
  }

  Future<void> deleteFeedback(String id) async {
    try {
      await FirebaseFirestore.instance.collection('feedback').doc(id).delete();
    } catch (_) {}
  }

  Future<void> _sendReply(String id, {String? existingReply}) async {
    final t = AppThemeNotifier.of(context);
    final controller = TextEditingController(text: existingReply);
    final String? result;
    try {
    result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Ответить пользователю',
            style: TextStyle(color: t.primary, fontSize: 15)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: t.textPrimary),
          maxLines: 4,
          maxLength: 300,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Напиши ответ...',
            hintStyle: TextStyle(color: t.textSecondary),
            counterStyle: TextStyle(color: t.textSecondary),
            filled: true,
            fillColor: t.background,
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.border),
                borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.primary),
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: t.primary),
            child: const Text('Отправить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    } finally {
      controller.dispose();
    }
    if (result != null && result.isNotEmpty) {
      final feedbackDoc = await FirebaseFirestore.instance
          .collection('feedback')
          .doc(id)
          .get();
      final feedbackUserId = feedbackDoc.data()?['user_id'] as String?;
      await FirebaseFirestore.instance.collection('feedback').doc(id).update({
        'reply': result,
        'reply_read': false,
        'is_read': true,
      });
      if (feedbackUserId != null && feedbackUserId.isNotEmpty) {
        await FcmService.notifyFeedbackReply(feedbackUserId, result);
      }
      _snack('Ответ отправлен ✅', Colors.green);
    }
  }

  // ─── Хелперы ─────────────────────────────────────────────────────────────

  Future<bool> _confirm(AppThemeData t, String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: TextStyle(color: t.primary, fontSize: 16)),
        content: Text(body,
            style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Подтвердить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    final type = color == Colors.green
        ? SnackBarType.success
        : color == Colors.red
            ? SnackBarType.error
            : SnackBarType.warning;
    AppSnackBar.show(context, msg, type: type);
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          backgroundColor: t.surface,
          title: Text('АДМИН ПАНЕЛЬ',
              style: TextStyle(
                  color: t.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          centerTitle: true,
          iconTheme: IconThemeData(color: t.primary),
          bottom: TabBar(
            indicatorColor: t.primary,
            labelColor: t.primary,
            unselectedLabelColor: t.textSecondary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'ПОЛЬЗОВАТЕЛИ'),
              Tab(text: 'ОТЗЫВЫ'),
              Tab(text: 'МАППУЛ'),
              Tab(text: 'ЗАЯВКИ'),
              Tab(text: 'ЛОГИ'),
              Tab(text: 'МОДЕРАТОРЫ'),
              Tab(text: 'НОВОСТИ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _usersTab(t),
            _feedbackTab(t),
            _mapPoolTab(t),
            _applicationsTab(t),
            _logsTab(t),
            _moderatorsTab(t),
            _changelogTab(t),
          ],
        ),
      ),
    );
  }

  // ─── Вкладка Пользователи ─────────────────────────────────────────────────

  Widget _usersTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: t.primary));
        final sorted = [...snapshot.data!.docs];
        sorted.sort((a, b) {
          final aCount = (a.data() as Map)['approved_lineups'] ?? 0;
          final bCount = (b.data() as Map)['approved_lineups'] ?? 0;
          return (bCount as int).compareTo(aCount as int);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final data = sorted[i].data() as Map<String, dynamic>;
            final uid = sorted[i].id;
            final name = data['name'] ?? 'Аноним';
            final isBanned = data['is_banned'] ?? false;
            final approved = data['approved_lineups'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isBanned ? Colors.red : t.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(isBanned ? Icons.block : Icons.person,
                        color: isBanned ? Colors.red : t.textSecondary),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              style: TextStyle(
                                  color: isBanned ? Colors.red : t.textPrimary,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        LevelBadge(approvedLineups: approved),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBanned
                              ? '🚫 Заблокирован • $approved лайнапов'
                              : '✅ Активен • $approved лайнапов',
                          style: TextStyle(
                              color: isBanned ? Colors.red : Colors.green,
                              fontSize: 12),
                        ),
                        Builder(builder: (_) {
                          final createdAt =
                              (data['created_at'] as Timestamp?)?.toDate();
                          if (createdAt == null) return const SizedBox.shrink();
                          return Text(
                            'Зарег: ${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 11),
                          );
                        }),
                      ],
                    ),
                    trailing: isBanned
                        ? ElevatedButton(
                            onPressed: () => unbanUser(uid, name),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Разблок.',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          )
                        : ElevatedButton(
                            onPressed: () => banUser(uid, name),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('Блок.',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                    child: GestureDetector(
                      onTap: () => deleteUser(uid, name),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red, size: 14),
                            SizedBox(width: 6),
                            Text('Удалить аккаунт',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Вкладка Отзывы ───────────────────────────────────────────────────────

  Widget _feedbackTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: t.primary));
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.feedback_outlined, color: t.border, size: 48),
              const SizedBox(height: 12),
              Text('Отзывов пока нет', style: TextStyle(color: t.textSecondary, fontSize: 16)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final text = data['text'] ?? '';
            final category = data['category'] ?? 'другое';
            final username = data['username'] ?? 'Аноним';
            final isRead = data['is_read'] ?? false;
            final reply = data['reply'] as String?;

            Color catColor;
            IconData catIcon;
            switch (category) {
              case 'баг':         catColor = Colors.red;  catIcon = Icons.bug_report; break;
              case 'предложение': catColor = Colors.blue; catIcon = Icons.lightbulb_outline; break;
              default:            catColor = t.textSecondary; catIcon = Icons.chat_bubble_outline;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isRead ? t.border : catColor, width: isRead ? 1 : 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
                    child: Row(
                      children: [
                        Icon(catIcon, color: catColor, size: 20),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: catColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(category.toUpperCase(),
                              style: TextStyle(color: catColor, fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('👤 $username',
                              style: TextStyle(color: t.primary, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (!isRead)
                          Container(width: 7, height: 7,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                        if (!isRead)
                          _iconBtn(Icons.mark_email_read, Colors.green, () async {
                            await FirebaseFirestore.instance
                                .collection('feedback').doc(id).update({'is_read': true});
                          }),
                        if (reply == null)
                          _iconBtn(Icons.reply, Colors.green, () => _sendReply(id))
                        else
                          _iconBtn(Icons.edit, Colors.blue, () => _sendReply(id, existingReply: reply)),
                        _iconBtn(Icons.delete, Colors.red, () => deleteFeedback(id)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Text(text,
                        style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.4)),
                  ),
                  if (reply != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.admin_panel_settings, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(reply,
                                style: const TextStyle(color: Colors.green, fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Вкладка Маппул ───────────────────────────────────────────────────────

  Widget _mapPoolTab(AppThemeData t) {
    if (_poolLoading) {
      return Center(child: CircularProgressIndicator(color: t.primary));
    }

    return Column(
      children: [
        Container(
          color: t.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.star, color: t.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Маппул рейтинга',
                        style: TextStyle(color: t.primary,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Нажми на карту чтобы добавить/убрать из маппула',
                        style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.primary),
                ),
                child: Text('${_ratedPool.length} / 7',
                    style: TextStyle(color: t.primary,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _allMapNames.length,
            itemBuilder: (context, i) {
              final name = _allMapNames[i];
              final file = _allMapFiles[name]!;
              final inPool = _ratedPool.contains(name);

              return GestureDetector(
                onTap: () => _toggleMapPool(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inPool ? t.primary : t.border,
                      width: inPool ? 2.5 : 1,
                    ),
                    image: DecorationImage(
                      image: AssetImage(file),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: inPool ? 0.25 : 0.6),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            color: inPool ? Colors.white : Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                          ),
                        ),
                      ),
                      if (inPool)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: t.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      if (!inPool)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: t.border),
                            ),
                            child: Icon(Icons.remove,
                                color: t.textSecondary, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Вкладка Заявки ──────────────────────────────────────────────────────

  Widget _applicationsTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('moderator_applications')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: t.primary));
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, color: t.border, size: 48),
              const SizedBox(height: 12),
              Text('Заявок нет', style: TextStyle(color: t.textSecondary, fontSize: 15)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final username = data['username'] as String? ?? 'Аноним';
            final reason = data['reason'] as String? ?? '';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.primary),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: t.primary, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(username,
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (createdAt != null)
                          Text(
                            '${createdAt.day}.${createdAt.month}.${createdAt.year}',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(reason,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 13,
                            height: 1.4)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveApplication(uid, username),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Одобрить',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectApplication(uid),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Отклонить',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveApplication(String uid, String username) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': 'moderator'});
    await FirebaseFirestore.instance
        .collection('moderator_applications')
        .doc(uid)
        .update({'status': 'approved'});
    await FcmService.notifyModeratorApplicationResult(uid, true);
    _snack('$username назначен модератором ✅', Colors.green);
  }

  Future<void> _rejectApplication(String uid) async {
    await FirebaseFirestore.instance
        .collection('moderator_applications')
        .doc(uid)
        .update({'status': 'rejected'});
    FcmService.notifyModeratorApplicationResult(uid, false).ignore();
    _snack('Заявка отклонена', Colors.orange);
  }

  // ─── Вкладка Логи ─────────────────────────────────────────────────────────

  Widget _logsTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('moderator_logs')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: t.primary));
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history, color: t.border, size: 48),
              const SizedBox(height: 12),
              Text('Логов нет', style: TextStyle(color: t.textSecondary, fontSize: 15)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final moderatorName = data['moderator_name'] as String? ?? 'Аноним';
            final action = data['action'] as String? ?? '';
            final details = data['details'] as String? ?? '';
            final createdAt = (data['created_at'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
              child: ListTile(
                leading: Icon(Icons.history, color: t.textSecondary, size: 20),
                title: Text('$moderatorName → $action',
                    style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details.isNotEmpty)
                      Text(details,
                          style: TextStyle(
                              color: t.textSecondary, fontSize: 12)),
                    if (createdAt != null)
                      Text(
                        '${createdAt.day}.${createdAt.month}.${createdAt.year} '
                        '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Вкладка Модераторы ────────────────────────────────────────────────────

  Widget _moderatorsTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'moderator')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: t.primary));
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined, color: t.border, size: 48),
              const SizedBox(height: 12),
              Text('Нет модераторов',
                  style: TextStyle(color: t.textSecondary, fontSize: 15)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final name = data['name'] as String? ?? 'Аноним';
            final sessionActive = data['moderator_session_active'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.primary),
              ),
              child: ListTile(
                leading: Icon(Icons.shield, color: t.primary, size: 24),
                title: Text(name,
                    style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                  sessionActive ? '● Сессия активна' : '○ Нет активной сессии',
                  style: TextStyle(
                      color: sessionActive ? Colors.green : t.textSecondary,
                      fontSize: 12),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _removeModerator(uid, name),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Снять роль',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeModerator(String uid, String username) async {
    final t = AppThemeNotifier.of(context);
    final ok = await _confirm(
        t, 'Снять роль модератора?', '$username потеряет доступ к панели.');
    if (ok) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'role': 'user',
        'moderator_session_active': false,
        'moderator_session_expires': FieldValue.delete(),
      });
      _snack('Роль модератора снята с $username', Colors.orange);
    }
  }

  // ─── Вкладка Новости ──────────────────────────────────────────────────────

  Future<void> _publishChangelog(AppThemeData t) async {
    final title = _changelogTitleCtrl.text.trim();
    final body = _changelogBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Заполни заголовок и текст', Colors.orange);
      return;
    }
    setState(() => _changelogPublishing = true);
    try {
      await FirebaseFirestore.instance.collection('changelog').add({
        'type': _changelogType,
        'title': title,
        'body': body,
        'author': 'Admin',
        'published_at': FieldValue.serverTimestamp(),
        'views_count': 0,
        'likes_count': 0,
      });
      await FcmService.notifyNewChangelog('🔔 $title', body.length > 80 ? '${body.substring(0, 80)}...' : body);
      _changelogTitleCtrl.clear();
      _changelogBodyCtrl.clear();
      setState(() => _changelogType = 'update');
      _snack('Новость опубликована и отправлена всем ✅', Colors.green);
    } catch (_) {
      _snack('Ошибка публикации', Colors.orange);
    } finally {
      if (mounted) setState(() => _changelogPublishing = false);
    }
  }

  Widget _changelogTab(AppThemeData t) {
    const types = ['update', 'new', 'fix', 'meta', 'patch'];
    const typeLabels = {
      'update': 'Обновление',
      'new': 'Новое',
      'fix': 'Фикс',
      'meta': 'Мета',
      'patch': 'Патч',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign, color: t.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Публикация создаёт запись в Firestore и отправляет FCM всем подписчикам (топик all)',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Тип', style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: types.map((type) {
              final selected = _changelogType == type;
              return ChoiceChip(
                label: Text(typeLabels[type] ?? type),
                selected: selected,
                onSelected: (_) => setState(() => _changelogType = type),
                selectedColor: t.primary,
                backgroundColor: t.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : t.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: selected ? t.primary : t.border),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _changelogTitleCtrl,
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              labelText: 'Заголовок',
              labelStyle: TextStyle(color: t.textSecondary),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _changelogBodyCtrl,
            style: TextStyle(color: t.textPrimary),
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Текст новости',
              labelStyle: TextStyle(color: t.textSecondary),
              filled: true,
              fillColor: t.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _changelogPublishing ? null : () => _publishChangelog(t),
            icon: _changelogPublishing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 18),
            label: Text(
              _changelogPublishing ? 'Публикация...' : 'Опубликовать и отправить всем',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
