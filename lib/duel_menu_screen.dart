import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'duel_model.dart';
import 'duel_service.dart';
import 'duel_screen.dart';

class DuelMenuScreen extends StatefulWidget {
  const DuelMenuScreen({super.key});

  @override
  State<DuelMenuScreen> createState() => _DuelMenuScreenState();
}

class _DuelMenuScreenState extends State<DuelMenuScreen> {
  Color get _red => AppThemeNotifier.of(context).primary;

  bool _duelNotifs = false;
  bool _notifsLoading = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      p.setInt('duels_last_seen_at', DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        setState(() => _duelNotifs = p.getBool('duel_notifications') ?? false);
      }
    });
  }

  Future<void> _toggleNotifs(bool value) async {
    setState(() => _notifsLoading = true);
    try {
      if (value) {
        await OneSignal.User.addTagWithKey('duel_notifications', '1');
      } else {
        await OneSignal.User.removeTag('duel_notifications');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('duel_notifications', value);
      if (mounted) setState(() => _duelNotifs = value);
    } finally {
      if (mounted) setState(() => _notifsLoading = false);
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
          '⚔️ Дуэли лайнапов',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        elevation: 0,
      ),
      body: StreamBuilder<List<Duel>>(
        stream: DuelService.getActiveDuels(),
        builder: (context, snap) {
          final duels = snap.data ?? [];
          final loading =
              snap.connectionState == ConnectionState.waiting && duels.isEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Приветствие ──────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _red.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('⚔️', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Добро пожаловать в дуэль лайнапов!',
                            style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Два лайнапа на одну позицию — сообщество голосует за лучший. '
                      'Голосование помогает отобрать самые эффективные решения '
                      'и улучшить качество контента.',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (!loading) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _red.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department,
                                color: _red, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              duels.isEmpty
                                  ? 'Активных дуэлей нет'
                                  : '${duels.length} ${_duelWord(duels.length)} сейчас активно',
                              style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Уведомления о дуэлях ─────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _duelNotifs
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: _duelNotifs ? _red : t.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Уведомления о дуэлях',
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _duelNotifs
                                ? 'Ты узнаешь о новых дуэлях первым'
                                : 'Получай уведомления о новых дуэлях',
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_notifsLoading)
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _red))
                    else
                      Switch(
                        value: _duelNotifs,
                        onChanged: _toggleNotifs,
                        activeThumbColor: _red,
                        inactiveThumbColor: Colors.white38,
                        inactiveTrackColor: Colors.white12,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ),

              // ── Заголовок списка ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Активные дуэли',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // ── Список / пусто / загрузка ─────────────────────────────────
              Expanded(
                child: loading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: t.primary))
                    : duels.isEmpty
                        ? _buildEmpty(context, t)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: duels.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) =>
                                _DuelCard(duel: duels[i]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppThemeData t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const Text('😴', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Дуэлей пока нет',
            style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы уже готовим новые поединки — возвращайся позже!',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!_duelNotifs)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('🔔', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 10),
                  Text(
                    'Включи уведомления',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Мы пришлём тебе уведомление как только появится новая дуэль',
                    style: TextStyle(
                        color: t.textSecondary, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _notifsLoading ? null : () => _toggleNotifs(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.notifications_active, size: 18),
                      label: const Text('Включить уведомления',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _duelWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'дуэль';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дуэли';
    }
    return 'дуэлей';
  }
}

// ─── Карточка дуэли в списке ──────────────────────────────────────────────────

class _DuelCard extends StatefulWidget {
  final Duel duel;
  const _DuelCard({required this.duel});

  @override
  State<_DuelCard> createState() => _DuelCardState();
}

class _DuelCardState extends State<_DuelCard>
    with SingleTickerProviderStateMixin {
  static const _amber = Color(0xFFF5A623);
  static const _green = Color(0xFF22C55E);

  String _title1 = '…';
  String _title2 = '…';
  int? _voted;
  bool _loading = true;
  bool _showHint = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _load();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fs = FirebaseFirestore.instance;
    final results = await Future.wait([
      fs.collection('lineups').doc(widget.duel.lineup1Id).get(),
      fs.collection('lineups').doc(widget.duel.lineup2Id).get(),
      DuelService.hasVoted(widget.duel.id),
    ]);
    if (!mounted) return;
    setState(() {
      _title1 =
          ((results[0] as DocumentSnapshot).data() as Map<String, dynamic>?)?[
                  'title'] ??
              'Лайнап #1';
      _title2 =
          ((results[1] as DocumentSnapshot).data() as Map<String, dynamic>?)?[
                  'title'] ??
              'Лайнап #2';
      _voted = results[2] as int?;
      _loading = false;
    });
  }

  void _onTap() {
    if (_voted != null) {
      // Уже голосовал — шейк + подсказка
      _shakeCtrl.forward(from: 0);
      setState(() => _showHint = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showHint = false);
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => DuelScreen(duelId: widget.duel.id)),
    ).then((_) {
      // Перезагружаем статус голосования после возврата
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    final d = widget.duel;
    final alreadyVoted = _voted != null;
    final shakeX = _shakeAnim.value;

    return GestureDetector(
      onTap: _onTap,
      child: Transform.translate(
        offset: Offset(shakeX, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Жёлтая подсказка «уже голосовал»
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _showHint
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _amber.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: _amber, size: 14),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Ты уже проголосовал в этой дуэли',
                              style: TextStyle(
                                  color: _amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Карточка дуэли
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: alreadyVoted
                    ? _amber.withValues(alpha: 0.06)
                    : t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: alreadyVoted
                      ? _amber.withValues(alpha: 0.45)
                      : t.border,
                  width: alreadyVoted ? 1.5 : 1.0,
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 60,
                      child: Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('🗺 ${d.mapName}',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 12)),
                            const Spacer(),
                            if (alreadyVoted)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('✓ Проголосовал',
                                    style: TextStyle(
                                        color: _green, fontSize: 10)),
                              ),
                            Text('⏱ ${d.timeLeftLabel}',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _VsSide(
                                title: _title1,
                                percent: d.percent1,
                                chosen: _voted == 1,
                                align: CrossAxisAlignment.start,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  color: t.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _VsSide(
                                title: _title2,
                                percent: d.percent2,
                                chosen: _voted == 2,
                                align: CrossAxisAlignment.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VsSide extends StatelessWidget {
  final String title;
  final double percent;
  final bool chosen;
  final CrossAxisAlignment align;

  const _VsSide({
    required this.title,
    required this.percent,
    required this.chosen,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    const green = Color(0xFF22C55E);
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: align == CrossAxisAlignment.end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (chosen)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text('✓',
                    style: TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            color: chosen ? green : t.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
