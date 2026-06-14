import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'guide_screen.dart';
import 'level_system.dart';
import 'level_badge.dart';
import 'likes_service.dart';
import 'badge_widget.dart';

class UserProfileScreen extends StatefulWidget {
  final String uid;
  final String name;

  const UserProfileScreen({super.key, required this.uid, required this.name});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _lineups = [];
  bool _loading = true;
  bool _error = false;
  String _sortMode = 'new'; // 'new' | 'popular'

  // Pioneer tooltip
  final _badgeKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _tooltipAnim;
  late Animation<double> _tooltipFade;
  late Animation<double> _tooltipScale;

  @override
  void initState() {
    super.initState();
    _tooltipAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _tooltipFade =
        CurvedAnimation(parent: _tooltipAnim, curve: Curves.easeOut);
    _tooltipScale = Tween(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _tooltipAnim, curve: Curves.easeOut));
    _loadData();
  }

  @override
  void dispose() {
    _removeTooltipImmediate();
    _tooltipAnim.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(widget.uid).get(),
        FirebaseFirestore.instance
            .collection('lineups')
            .where('user_id', isEqualTo: widget.uid)
            .where('status', isEqualTo: 'approved')
            .orderBy('submitted_at', descending: true)
            .get(),
        FirebaseFirestore.instance
            .collection('lineups')
            .where('submitted_by', isEqualTo: widget.name)
            .where('status', isEqualTo: 'approved')
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final byUserIdSnap = results[1] as QuerySnapshot;
      final byNameSnap = results[2] as QuerySnapshot;

      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      final allDocs = <String, Map<String, dynamic>>{};
      for (final doc in byUserIdSnap.docs) {
        allDocs[doc.id] = {...doc.data() as Map<String, dynamic>, 'id': doc.id};
      }
      for (final doc in byNameSnap.docs) {
        allDocs.putIfAbsent(
            doc.id, () => {...doc.data() as Map<String, dynamic>, 'id': doc.id});
      }
      final merged = allDocs.values.toList()
        ..sort((a, b) {
          final aT = a['submitted_at'];
          final bT = b['submitted_at'];
          if (aT is Timestamp && bT is Timestamp) return bT.compareTo(aT);
          return 0;
        });

      if (mounted) {
        setState(() {
          _userData = data;
          _lineups = merged;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  String get _displayName {
    final d = _userData ?? {};
    return (d['name'] ?? d['username'] ?? d['displayName'] ?? widget.name)
        .toString();
  }

  String get _role {
    final role = ((_userData ?? {})['role'] ?? '').toString().toLowerCase();
    if (role == 'admin') return 'ADMIN';
    if (role == 'moderator') return 'MOD';
    return 'USER';
  }

  String get _roleEmoji {
    if (_role == 'ADMIN') return '👑';
    if (_role == 'MOD') return '🛡️';
    return '👤';
  }

  int get _approvedLineups {
    if (_lineups.isNotEmpty) return _lineups.length;
    final d = _userData ?? {};
    final v = d['approved_lineups'] ?? d['lineups_count'] ?? d['lineups'] ?? 0;
    return (v as num).toInt();
  }

  int get _totalLikes {
    if (_lineups.isEmpty) return 0;
    return _lineups.fold(0, (acc, l) {
      final v = l['likes'] ?? l['likes_count'] ?? 0;
      return acc + (v as num).toInt();
    });
  }

  int get _totalViews {
    if (_lineups.isEmpty) return 0;
    return _lineups.fold(0, (acc, l) {
      final v = l['views_count'] ?? 0;
      return acc + (v as num).toInt();
    });
  }

  String? get _dateStr {
    final createdAt = (_userData ?? {})['created_at'];
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }
    return null;
  }

  List<Map<String, dynamic>> get _sortedLineups {
    final list = List<Map<String, dynamic>>.from(_lineups);
    if (_sortMode == 'popular') {
      list.sort((a, b) {
        final aLikes = (a['likes_count'] ?? a['likes'] ?? 0) as int;
        final bLikes = (b['likes_count'] ?? b['likes'] ?? 0) as int;
        return bLikes.compareTo(aLikes);
      });
    }
    return list;
  }

  bool get _isPioneer {
    final createdAt = (_userData ?? {})['created_at'];
    if (createdAt is Timestamp) {
      return createdAt.toDate().isBefore(DateTime(2026, 6, 1));
    }
    return false;
  }

  // ── Pioneer tooltip ───────────────────────────────────────────────────────

  void _removeTooltipImmediate() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _removeTooltip() async {
    if (_overlayEntry == null) return;
    await _tooltipAnim.reverse();
    _removeTooltipImmediate();
  }

  void _showPioneerTooltip() {
    _removeTooltipImmediate();
    _tooltipAnim.reset();

    final rb = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;

    final badgeSize = rb.size;
    final badgePos = rb.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;

    const tooltipW = 260.0;
    const arrowH = 8.0;
    const margin = 8.0;
    const gap = 4.0;

    final centerX = badgePos.dx + badgeSize.width / 2;
    final left =
        (centerX - tooltipW / 2).clamp(margin, screen.width - tooltipW - margin);
    final arrowCenterX = centerX - left;

    // Show above if badge is in the lower half of the screen, else below
    final showAbove = badgePos.dy > screen.height * 0.5;

    Timer? autoClose;

    _overlayEntry = OverlayEntry(builder: (ctx) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dismiss on tap anywhere
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  autoClose?.cancel();
                  _removeTooltip();
                },
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            // Tooltip (absorbs taps so it doesn't dismiss itself)
            Positioned(
              left: left,
              top: showAbove
                  ? null
                  : badgePos.dy + badgeSize.height + gap,
              bottom: showAbove
                  ? screen.height - badgePos.dy + gap
                  : null,
              child: GestureDetector(
                onTap: () {},
                child: FadeTransition(
                  opacity: _tooltipFade,
                  child: ScaleTransition(
                    scale: _tooltipScale,
                    alignment: showAbove
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    child: _PioneerTooltipBubble(
                      width: tooltipW,
                      arrowCenterX: arrowCenterX,
                      arrowHeight: arrowH,
                      arrowAtBottom: showAbove,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });

    Overlay.of(context).insert(_overlayEntry!);
    _tooltipAnim.forward(from: 0);

    autoClose = Timer(const Duration(seconds: 4), () {
      if (_overlayEntry != null) _removeTooltip();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(_displayName.toUpperCase(),
            style: TextStyle(
                color: t.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 13)),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary))
          : _error
              ? _buildError(t)
              : _buildBody(t),
    );
  }

  Widget _buildError(AppThemeData t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Не удалось загрузить профиль',
              style: TextStyle(color: Colors.red.shade400, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: t.primary),
            child: const Text('Повторить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppThemeData t) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(t),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStats(t),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildLineups(t),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeader(AppThemeData t) {
    final date = _dateStr;

    final levelData = LevelSystem.getLevel(_approvedLineups);
    final levelColor = Color(levelData['color'] as int);
    final levelIcon = levelData['icon'] as String;
    final isAnimated = levelData['animated'] as bool;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.surface, t.surface2],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Level-based avatar (matches own profile design)
          Stack(
            alignment: Alignment.center,
            children: [
              if (isAnimated)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.05),
                  duration: const Duration(seconds: 2),
                  builder: (ctx, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: levelColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: levelColor.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 4),
                      ],
                    ),
                  ),
                ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: levelColor, width: 2),
                ),
                child: Center(
                  child: Text(levelIcon,
                      style: const TextStyle(fontSize: 32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              UserBadgeRow(uid: widget.uid, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          LevelBadge(
            approvedLineups: _approvedLineups,
            animated: isAnimated,
            large: true,
          ),
          if (_isPioneer) ...[
            const SizedBox(height: 6),
            GestureDetector(
              key: _badgeKey,
              onTap: _showPioneerTooltip,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C3FE8), Color(0xFF00D4FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3FE8).withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Text(
                  '⚡ PIONEER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (date != null) ...[
            const SizedBox(height: 4),
            Text('С нами с $date',
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(AppThemeData t) {
    return Row(
      children: [
        Expanded(child: _statCard(t, _roleEmoji, _role, 'Роль')),
        const SizedBox(width: 10),
        Expanded(child: _statCard(t, '🎯', '$_approvedLineups', 'Лайнапов')),
        const SizedBox(width: 10),
        Expanded(child: _statCard(t, '❤️', '$_totalLikes', 'Лайков')),
        const SizedBox(width: 10),
        Expanded(child: _statCard(t, '👁️', '$_totalViews', 'Просмотров')),
      ],
    );
  }

  Widget _statCard(AppThemeData t, String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLineups(AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Лайнапы',
                style: TextStyle(
                    color: t.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const Spacer(),
            _sortChip(t, 'new', 'Новые'),
            const SizedBox(width: 6),
            _sortChip(t, 'popular', 'Популярные'),
          ],
        ),
        const SizedBox(height: 12),
        if (_lineups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Нет одобренных лайнапов',
                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
            ),
          )
        else
          ..._sortedLineups.map((lineup) => _LineupCard(lineup: lineup, t: t)),
      ],
    );
  }

  Widget _sortChip(AppThemeData t, String mode, String label) {
    final active = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? t.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? t.primary : Colors.grey),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Pioneer tooltip bubble ────────────────────────────────────────────────────

class _PioneerTooltipBubble extends StatelessWidget {
  final double width;
  final double arrowCenterX;
  final double arrowHeight;
  final bool arrowAtBottom;

  const _PioneerTooltipBubble({
    required this.width,
    required this.arrowCenterX,
    required this.arrowHeight,
    required this.arrowAtBottom,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0B3B), Color(0xFF0D1F3C)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C3FE8).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FE8).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚡',
              style: TextStyle(fontSize: 20, color: Color(0xFF00D4FF))),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6C3FE8), Color(0xFF00D4FF)],
            ).createShader(bounds),
            child: const Text('PIONEER',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),
          const SizedBox(height: 10),
          Text(
            'Этот игрок стоял у истоков. Один из немногих, кто был призван в закрытое тестирование ещё до того, как мир узнал об этом приложении.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Выдаётся навсегда · Нельзя получить сейчас',
            style: TextStyle(
                color: const Color(0xFF6C3FE8).withValues(alpha: 0.7),
                fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final arrow = SizedBox(
      width: width,
      height: arrowHeight,
      child: CustomPaint(
        painter: _ArrowPainter(
          centerX: arrowCenterX,
          pointingDown: arrowAtBottom,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: arrowAtBottom
          ? [bubble, arrow]
          : [arrow, bubble],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double centerX;
  final bool pointingDown;

  const _ArrowPainter({required this.centerX, required this.pointingDown});

  @override
  void paint(Canvas canvas, Size size) {
    const half = 8.0;
    final cx = centerX.clamp(half + 4, size.width - half - 4);

    final borderPaint = Paint()
      ..color = const Color(0xFF6C3FE8).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final fillPaint = Paint()
      ..color = const Color(0xFF0D1F3C)
      ..style = PaintingStyle.fill;

    if (pointingDown) {
      // Arrow at bottom of bubble pointing down
      canvas.drawPath(
        Path()
          ..moveTo(cx - half, 0)
          ..lineTo(cx + half, 0)
          ..lineTo(cx, size.height),
        borderPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - half + 1.5, 0)
          ..lineTo(cx + half - 1.5, 0)
          ..lineTo(cx, size.height - 2),
        fillPaint,
      );
    } else {
      // Arrow at top of bubble pointing up
      canvas.drawPath(
        Path()
          ..moveTo(cx, 0)
          ..lineTo(cx - half, size.height)
          ..lineTo(cx + half, size.height),
        borderPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx, 2)
          ..lineTo(cx - half + 1.5, size.height)
          ..lineTo(cx + half - 1.5, size.height),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.centerX != centerX || old.pointingDown != pointingDown;
}

// ── Lineup card ───────────────────────────────────────────────────────────────

class _LineupCard extends StatelessWidget {
  final Map<String, dynamic> lineup;
  final AppThemeData t;

  const _LineupCard({required this.lineup, required this.t});

  @override
  Widget build(BuildContext context) {
    final isExclusive = lineup['is_exclusive'] as bool? ?? false;
    final lineupId = lineup['id'] as String? ?? '';
    final initialLikes =
        (lineup['likes_count'] ?? lineup['likes'] ?? lineup['total_likes'] ?? 0)
            as int;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuideScreen(
            lineupId: lineupId,
            title: lineup['title'] ?? '',
            description: lineup['description'] ?? '',
            ability: lineup['ability'] ?? '',
            mapName: lineup['map'] ?? '',
            agentName: lineup['agent'] ?? '',
            videoUrl: lineup['video_url'],
            screenshots: List<String>.from(lineup['screenshots'] ?? []),
            category: lineup['category'] ?? '',
            isExclusive: isExclusive,
            authorName: lineup['submitted_by'] as String?,
            authorId: lineup['user_id'] as String?,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isExclusive ? Colors.amber : t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lineup['title'] ?? '',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(lineup['map'] ?? '',
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·',
                      style: TextStyle(color: t.border, fontSize: 12)),
                ),
                Text(lineup['agent'] ?? '',
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·',
                      style: TextStyle(color: t.border, fontSize: 12)),
                ),
                Expanded(
                  child: Text(lineup['ability'] ?? '',
                      style:
                          TextStyle(color: t.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                StreamBuilder<bool>(
                  stream: LikesService.isLiked(lineupId),
                  initialData: false,
                  builder: (_, snapLiked) => StreamBuilder<int>(
                    stream: LikesService.getLikesCount(lineupId),
                    initialData: initialLikes,
                    builder: (_, snapCount) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (snapLiked.data ?? false)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 12,
                          color: const Color(0xFFFF4655),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${snapCount.data ?? initialLikes}',
                          style: const TextStyle(
                              color: Color(0xFFFF4655),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
