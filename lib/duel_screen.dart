import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'auth_service.dart';
import 'duel_model.dart';
import 'duel_service.dart';
import 'notification_service.dart';

class DuelScreen extends StatefulWidget {
  final String duelId;
  const DuelScreen({super.key, required this.duelId});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  Map<String, dynamic>? _lineup1;
  Map<String, dynamic>? _lineup2;
  int? _voted;
  bool _voting = false;
  bool _lineupsLoaded = false;
  Duel? _currentDuel;

  Future<void> _loadLineups(String id1, String id2) async {
    if (_lineupsLoaded) return;
    _lineupsLoaded = true;
    final fs = FirebaseFirestore.instance;
    final results = await Future.wait([
      fs.collection('lineups').doc(id1).get(),
      fs.collection('lineups').doc(id2).get(),
      DuelService.hasVoted(widget.duelId),
    ]);
    if (!mounted) return;
    setState(() {
      _lineup1 = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
      _lineup2 = (results[1] as DocumentSnapshot).data() as Map<String, dynamic>?;
      _voted = results[2] as int?;
    });
  }

  Future<void> _vote(int choice) async {
    if (AuthService.userId == null) {
      AppSnackBar.show(context, 'Войди в аккаунт, чтобы голосовать');
      return;
    }
    setState(() => _voting = true);
    final duelSnapshot = _currentDuel;
    try {
      await DuelService.vote(widget.duelId, choice);
      if (!mounted) return;
      setState(() => _voted = choice);
      AppSnackBar.show(context, 'Спасибо за твой голос — вместе делаем лайнапы лучше! ⚔️');
      // Schedule a local notification when the duel ends
      if (duelSnapshot != null && duelSnapshot.endsAt.isAfter(DateTime.now())) {
        NotificationService.scheduleLocalNotification(
          widget.duelId.hashCode,
          '⚔️ Дуэль завершена',
          'Дуэль, в которой ты участвовал, завершена. Посмотри результат!',
          duelSnapshot.endsAt,
          payload: 'duel',
        ).ignore();
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          '⚔️ Дуэль',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        elevation: 0,
      ),
      body: StreamBuilder<Duel?>(
        stream: DuelService.getDuel(widget.duelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !_lineupsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final duel = snap.data;
          if (duel == null) {
            return Center(
              child: Text('Дуэль не найдена', style: TextStyle(color: t.textSecondary)),
            );
          }

          _currentDuel = duel;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _loadLineups(duel.lineup1Id, duel.lineup2Id),
          );

          final voted = _voted;
          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _LineupPanel(
                        lineup: _lineup1,
                        label: 'Лайнап #1',
                        chosen: voted == 1,
                      ),
                    ),
                    Container(width: 1, color: t.border),
                    Expanded(
                      child: _LineupPanel(
                        lineup: _lineup2,
                        label: 'Лайнап #2',
                        chosen: voted == 2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: t.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: voted != null
                    ? _ResultsRow(duel: duel, voted: voted)
                    : _VoteButtons(voting: _voting, onVote: _vote),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VoteButtons extends StatelessWidget {
  final bool voting;
  final void Function(int) onVote;
  const _VoteButtons({required this.voting, required this.onVote});

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Color(0xFFFF4655)),
      foregroundColor: WidgetStatePropertyAll(Colors.white),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      )),
    );
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: style,
            onPressed: voting ? null : () => onVote(1),
            child: const Text('Голосую за этот', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('⚔️', style: TextStyle(fontSize: 22)),
        ),
        Expanded(
          child: ElevatedButton(
            style: style,
            onPressed: voting ? null : () => onVote(2),
            child: const Text('Голосую за этот', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ResultsRow extends StatelessWidget {
  final Duel duel;
  final int voted;
  const _ResultsRow({required this.duel, required this.voted});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    const green = Color(0xFF22C55E);

    Widget side(double pct, bool isVoted) => Column(
          children: [
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isVoted ? green : t.textSecondary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isVoted)
              const Text('✓ твой выбор', style: TextStyle(color: green, fontSize: 11)),
          ],
        );

    return Row(
      children: [
        Expanded(child: side(duel.percent1, voted == 1)),
        Text(
          '${duel.totalVotes} голосов',
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        Expanded(child: side(duel.percent2, voted == 2)),
      ],
    );
  }
}

class _LineupPanel extends StatelessWidget {
  final Map<String, dynamic>? lineup;
  final String label;
  final bool chosen;

  const _LineupPanel({this.lineup, required this.label, required this.chosen});

  static const _mapAssets = {
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

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    const green = Color(0xFF22C55E);

    if (lineup == null) {
      return Container(
        color: t.surface,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final title = lineup!['title'] as String? ?? label;
    final mapName = lineup!['map'] as String? ?? '';
    final asset = _mapAssets[mapName];
    final px = (lineup!['position_x'] as num?)?.toDouble();
    final py = (lineup!['position_y'] as num?)?.toDouble();
    final rawTraj = lineup!['trajectory'];
    final trajectory = rawTraj is List
        ? rawTraj.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return Container(
      decoration: chosen
          ? BoxDecoration(border: Border.all(color: green, width: 2))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: chosen ? green.withValues(alpha: 0.15) : t.surface,
            child: Text(
              chosen ? '✓ $title' : title,
              style: TextStyle(
                color: chosen ? green : t.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: asset != null
                ? LayoutBuilder(
                    builder: (ctx, constraints) => Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Image.asset(asset, fit: BoxFit.contain),
                        if (trajectory.length >= 2)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _TrajectoryPainter(
                                points: trajectory,
                                color: const Color(0xFFFF4655),
                              ),
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                            ),
                          ),
                        if (px != null && py != null)
                          Positioned(
                            left: px * constraints.maxWidth - 10,
                            top: py * constraints.maxHeight - 10,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: t.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFF4655), width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      'Карта недоступна',
                      style: TextStyle(color: t.textSecondary, fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final Color color;

  const _TrajectoryPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final pts = points
        .map((p) => Offset(
              (p['x'] as num).toDouble() * size.width,
              (p['y'] as num).toDouble() * size.height,
            ))
        .toList();

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    canvas.drawCircle(pts.first, 4, Paint()..color = color);

    if (pts.length >= 2) {
      _drawArrow(canvas, pts[pts.length - 2], pts.last, Paint()..color = color);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.01) return;
    final ux = dx / len;
    final uy = dy / len;
    const s = 7.0;
    const hw = 3.5;
    final bx = to.dx - s * ux;
    final by = to.dy - s * uy;
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(bx - hw * uy, by + hw * ux)
        ..lineTo(bx + hw * uy, by - hw * ux)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) => false;
}
