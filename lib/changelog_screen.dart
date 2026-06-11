import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'auth_service.dart';
import 'likes_service.dart';

const _kLastSeenKey = 'changelog_last_seen_ts';

// ─── Утилита для бейджа ───────────────────────────────────────────────────────

class ChangelogService {
  ChangelogService._();

  static Future<bool> hasUnread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt(_kLastSeenKey) ?? 0;
      final snap = await FirebaseFirestore.instance
          .collection('changelog')
          .where('published_at',
              isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSeen))
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeenKey, DateTime.now().millisecondsSinceEpoch);
  }
}

// ─── Иконка новостей с красным бейджем ───────────────────────────────────────

class ChangelogNavIcon extends StatefulWidget {
  const ChangelogNavIcon({super.key});

  @override
  State<ChangelogNavIcon> createState() => _ChangelogNavIconState();
}

class _ChangelogNavIconState extends State<ChangelogNavIcon> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final v = await ChangelogService.hasUnread();
    if (mounted) setState(() => _hasUnread = v);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.newspaper_outlined),
        if (_hasUnread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

// ─── Экран новостей ───────────────────────────────────────────────────────────

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    ChangelogService.markAllRead();
    _recordScreenView();
  }

  void _recordScreenView() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    FirebaseFirestore.instance
        .collection('changelog_views')
        .doc(today)
        .set({
          'date': today,
          'count': FieldValue.increment(1),
        }, SetOptions(merge: true))
        .ignore();
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'update': return Colors.blue;
      case 'new':    return Colors.green;
      case 'fix':    return Colors.orange;
      case 'event':  return Colors.purple;
      case 'alert':  return Colors.red;
      default:       return Colors.grey;
    }
  }

  String _badgeLabel(String type, String? label) {
    if (label != null && label.isNotEmpty) return label;
    switch (type) {
      case 'update': return 'Обновление';
      case 'new':    return 'Новое';
      case 'fix':    return 'Исправление';
      case 'event':  return 'Событие';
      case 'alert':  return 'Важно';
      default:       return type;
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text('НОВОСТИ',
            style: TextStyle(
                color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('changelog')
            .orderBy('published_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper, size: 64, color: theme.textSecondary),
                  const SizedBox(height: 16),
                  Text('Пока нет новостей',
                      style: TextStyle(color: theme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final docId = docs[i].id;
              final data = docs[i].data() as Map<String, dynamic>;
              final type   = data['type']   as String? ?? '';
              final emoji  = data['emoji']  as String? ?? '📢';
              final title  = data['title']  as String? ?? '';
              final body   = data['body']   as String? ?? '';
              final label  = data['label']  as String?;
              final author = data['author'] as String?;
              final ts     = data['published_at'] as Timestamp?;
              final date   = ts != null ? _formatDate(ts.toDate()) : '';
              final color  = _badgeColor(type);
              final views  = data['views_count'] as int? ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangelogDetailScreen(
                          docId: docId,
                          data: data,
                          badgeColor: color,
                          badgeLabel: _badgeLabel(type, label),
                          date: date,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Заголовок ──
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ── Бейдж + дата ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: color.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _badgeLabel(type, label),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(date,
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: 11)),
                        ],
                      ),
                      // ── Тело (сокращённое) ──
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          body,
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                              height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (author != null && author.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('— $author',
                            style: TextStyle(
                                color:
                                    theme.textSecondary.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                      ],
                      // ── Просмотры + лайки ──
                      const SizedBox(height: 10),
                      Divider(height: 1, color: theme.border),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 13, color: theme.textSecondary),
                          const SizedBox(width: 3),
                          Text('$views',
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: 11)),
                          const SizedBox(width: 14),
                          _LikeButton(
                            docId: docId,
                            initialCount: data['likes_count'] as int? ?? 0,
                            theme: theme,
                            onUnauthorized: () => AppSnackBar.show(
                                context, 'Войдите чтобы лайкать новости'),
                          ),
                          const Spacer(),
                          Text('Подробнее',
                              style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 14, color: theme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
            },
          );
        },
      ),
    );
  }
}

// ─── Кнопка лайка ────────────────────────────────────────────────────────────

class _LikeButton extends StatefulWidget {
  final String docId;
  final int initialCount;
  final AppThemeData theme;
  final VoidCallback onUnauthorized;

  const _LikeButton({
    required this.docId,
    required this.initialCount,
    required this.theme,
    required this.onUnauthorized,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  bool? _liked;
  late int _count;
  bool _loading = false;
  // Флаг: пользователь уже нажал — не перезаписывать состояние запоздавшими async-ответами
  bool _hasInteracted = false;

  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.85), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));

    NewsLikesService.isLiked(widget.docId).first.then((v) {
      if (mounted && !_hasInteracted) setState(() => _liked = v);
    });
    NewsLikesService.getLikesCount(widget.docId).first.then((v) {
      if (mounted && !_hasInteracted) setState(() => _count = v);
    });
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = _liked ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loading ? null : () async {
        if (AuthService.userId == null) {
          widget.onUnauthorized();
          return;
        }
        final wasLiked = liked;
        setState(() {
          _hasInteracted = true;
          _liked = !wasLiked;
          _count += wasLiked ? -1 : 1;
          _loading = true;
        });
        _scaleCtrl.forward(from: 0);
        try {
          await NewsLikesService.toggleLike(widget.docId);
        } catch (_) {
          if (mounted) {
            setState(() {
              _liked = wasLiked;
              _count += wasLiked ? 1 : -1;
            });
          }
        } finally {
          if (mounted) {
            setState(() => _loading = false);
          }
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: liked
                ? Colors.red.withValues(alpha: 0.12)
                : widget.theme.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: liked
                  ? Colors.red.withValues(alpha: 0.5)
                  : widget.theme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(liked),
                  size: 16,
                  color: liked ? Colors.red : widget.theme.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '$_count',
                  key: ValueKey(_count),
                  style: TextStyle(
                    color: liked ? Colors.red : widget.theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Детальный экран новости ──────────────────────────────────────────────────

class ChangelogDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Color badgeColor;
  final String badgeLabel;
  final String date;

  const ChangelogDetailScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.badgeColor,
    required this.badgeLabel,
    required this.date,
  });

  @override
  State<ChangelogDetailScreen> createState() => _ChangelogDetailScreenState();
}

class _ChangelogDetailScreenState extends State<ChangelogDetailScreen> {
  @override
  void initState() {
    super.initState();
    _trackView();
  }

  Future<void> _trackView() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'changelog_viewed_${widget.docId}';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    FirebaseFirestore.instance
        .collection('changelog')
        .doc(widget.docId)
        .update({'views_count': FieldValue.increment(1)}).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final d = widget.data;
    final emoji  = d['emoji']  as String? ?? '📢';
    final title  = d['title']  as String? ?? '';
    final body   = d['body']   as String? ?? '';
    final author = d['author'] as String?;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text('НОВОСТЬ',
            style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Бейдж + дата
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: widget.badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    widget.badgeLabel,
                    style: TextStyle(
                        color: widget.badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(widget.date,
                    style:
                        TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                body,
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 14, height: 1.6),
              ),
            ],
            if (author != null && author.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('— $author',
                  style: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 24),
            Divider(color: theme.border),
            const SizedBox(height: 12),
            // Лайк на детальном экране
            Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: theme.textSecondary),
                const SizedBox(width: 4),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('changelog')
                      .doc(widget.docId)
                      .snapshots(),
                  builder: (ctx, snap) {
                    final views = snap.data?.get('views_count') as int? ??
                        (d['views_count'] as int? ?? 0);
                    return Text('$views',
                        style: TextStyle(
                            color: theme.textSecondary, fontSize: 12));
                  },
                ),
                const SizedBox(width: 16),
                _LikeButton(
                  docId: widget.docId,
                  initialCount: d['likes_count'] as int? ?? 0,
                  theme: theme,
                  onUnauthorized: () => AppSnackBar.show(
                      context, 'Войдите чтобы лайкать новости'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
