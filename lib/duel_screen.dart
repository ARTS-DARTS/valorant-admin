import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'ad_banner_widget.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'auth_service.dart';
import 'duel_model.dart';
import 'duel_service.dart';
import 'notification_service.dart';
import 'valorant_api.dart';

// ─── Фазы дуэли ──────────────────────────────────────────────────────────────

enum _Phase { intro, lineup1, vsTransition, lineup2, vote, voted }

enum _SubPhase { map, video }

// ─── DuelScreen ───────────────────────────────────────────────────────────────

class DuelScreen extends StatefulWidget {
  final String duelId;
  const DuelScreen({super.key, required this.duelId});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  Color get _red => AppThemeNotifier.of(context).primary;
  static const _green = Color(0xFF22C55E);

  static const _mapAssets = {
    'Haven': 'assets/maps/Haven_minimap.png',
    'Bind': 'assets/maps/Bind_minimap.png',
    'Ascent': 'assets/maps/Ascent_minimap.png',
    'Split': 'assets/maps/Split_minimap.png',
    'Icebox': 'assets/maps/Icebox_minimap.png',
    'Breeze': 'assets/maps/Breeze_minimap.png',
    'Fracture': 'assets/maps/Fracture_minimap.png',
    'Pearl': 'assets/maps/Pearl_minimap.png',
    'Lotus': 'assets/maps/Lotus_minimap.png',
    'Sunset': 'assets/maps/Sunset_minimap.png',
    'Abyss': 'assets/maps/Abyss_minimap.png',
    'Corrode': 'assets/maps/Corrode_minimap.png',
  };

  // Данные
  Duel? _duel;
  Map<String, dynamic>? _lineup1;
  Map<String, dynamic>? _lineup2;
  bool _lineupsLoaded = false;
  int? _voted;
  bool _voting = false;

  // Иконки абилок и агентов
  String? _abilityIcon1;
  String? _abilityIcon2;
  String? _agentIcon1;
  String? _agentIcon2;

  // Предзагруженные видео-контроллеры
  VideoPlayerController? _preloadedCtrl1;
  VideoPlayerController? _preloadedCtrl2;

  // Пауза видео при просмотре скриншота
  bool _videoPausedByImage = false;

  // Фазы
  _Phase _phase = _Phase.intro;
  _SubPhase _subPhase = _SubPhase.map;
  // Шаги карты: 0=пустая карта, 1=карта+маркер, 2=карта+маркер+траектория
  int _mapStep = 0;

  // Реплей
  int? _replayLineup;
  _SubPhase _replaySubPhase = _SubPhase.map;
  int _replayMapStep = 0;

  // Генераторы для отмены цепочек Future.delayed
  int _mainAnimGen = 0;
  int _replayAnimGen = 0;

  // Анимации
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _particleCtrl;
  late AnimationController _trajCtrl;
  late AnimationController _wink1Ctrl; // мигание кнопки 1 на экране голосования
  late AnimationController _wink2Ctrl; // мигание кнопки 2

  // Таймеры
  Timer? _phaseTimer;
  Timer? _replayTimer;

  // Стрим
  StreamSubscription<Duel?>? _duelSub;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _trajCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _wink1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _wink2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _listenDuel();
  }

  void _listenDuel() {
    _duelSub?.cancel();
    _duelSub = DuelService.getDuel(widget.duelId).listen((duel) async {
      if (!mounted || duel == null) return;
      final isFirst = _duel == null;
      setState(() => _duel = duel);
      if (isFirst) {
        _loadLineups(duel.lineup1Id, duel.lineup2Id);
        _phaseTimer = Timer(const Duration(milliseconds: 5000), () {
          if (mounted) _advanceTo(_Phase.lineup1);
        });
      }
    });
  }

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
    final l1 = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final l2 = (results[1] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final voted = results[2] as int?;
    setState(() {
      _lineup1 = l1;
      _lineup2 = l2;
      _voted = voted;
    });
    // Уже голосовал в прошлый раз — сразу переходим к экрану результатов
    if (voted != null && _phase != _Phase.voted) {
      _phaseTimer?.cancel();
      _mainAnimGen++;
      setState(() => _phase = _Phase.voted);
    }
    _loadAbilityIcons(l1, l2);
    _preloadVideos(l1?['video_url'] as String?, l2?['video_url'] as String?);
  }

  Future<void> _loadAbilityIcons(
      Map<String, dynamic>? l1, Map<String, dynamic>? l2) async {
    final agents = await ValorantApi.getCached();
    if (agents == null || !mounted) return;

    String? abilityIconFor(Map<String, dynamic>? lineup) {
      if (lineup == null) return null;
      final agentName = lineup['agent'] as String? ?? '';
      final abilityName = lineup['ability'] as String? ?? '';
      if (agentName.isEmpty || abilityName.isEmpty) return null;
      try {
        final agent = agents.firstWhere((a) => a['displayName'] == agentName);
        final abilities =
            List<Map<String, dynamic>>.from(agent['abilities'] ?? []);
        final ability =
            abilities.firstWhere((a) => a['displayName'] == abilityName);
        return ability['displayIcon'] as String?;
      } catch (_) {
        return null;
      }
    }

    String? agentIconFor(Map<String, dynamic>? lineup) {
      if (lineup == null) return null;
      final agentName = lineup['agent'] as String? ?? '';
      if (agentName.isEmpty) return null;
      try {
        final agent = agents.firstWhere((a) => a['displayName'] == agentName);
        return agent['displayIcon'] as String?;
      } catch (_) {
        return null;
      }
    }

    if (mounted) {
      setState(() {
        _abilityIcon1 = abilityIconFor(l1);
        _abilityIcon2 = abilityIconFor(l2);
        _agentIcon1 = agentIconFor(l1);
        _agentIcon2 = agentIconFor(l2);
      });
    }
  }

  Future<void> _preloadVideos(String? url1, String? url2) async {
    if (url1 != null && url1.isNotEmpty) _preloadOneVideo(url1, 1);
    if (url2 != null && url2.isNotEmpty) _preloadOneVideo(url2, 2);
  }

  Future<void> _preloadOneVideo(String url, int num) async {
    VideoPlayerController? ctrl;
    try {
      if (_isYoutubeUrl(url)) {
        final yt = YoutubeExplode();
        final manifest =
            await yt.videos.streamsClient.getManifest(VideoId(url));
        final streamUrl = manifest.muxed.withHighestBitrate().url.toString();
        yt.close();
        ctrl = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      }
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      if (num == 1) {
        _preloadedCtrl1?.dispose();
        _preloadedCtrl1 = ctrl;
      } else {
        _preloadedCtrl2?.dispose();
        _preloadedCtrl2 = ctrl;
      }
      if (mounted) setState(() {});
    } catch (_) {
      ctrl?.dispose();
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _replayTimer?.cancel();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    _trajCtrl.dispose();
    _wink1Ctrl.dispose();
    _wink2Ctrl.dispose();
    _duelSub?.cancel();
    _preloadedCtrl1?.dispose();
    _preloadedCtrl2?.dispose();
    super.dispose();
  }

  // ─── Управление фазами ───────────────────────────────────────────────────

  void _advanceTo(_Phase phase) {
    _phaseTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _subPhase = _SubPhase.map;
      _mapStep = 0;
    });

    switch (phase) {
      case _Phase.lineup1:
      case _Phase.lineup2:
        _startLineupAnimation(main: true);
      case _Phase.vsTransition:
        _phaseTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) _advanceTo(_Phase.lineup2);
        });
      case _Phase.vote:
        // Запустить мигание кнопок с задержкой
        _wink1Ctrl.reset();
        _wink2Ctrl.reset();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _wink1Ctrl.forward();
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _wink2Ctrl.forward();
        });
      default:
        break;
    }
  }

  // Цепочка анимации карты: пустая → маркер → траектория → видео
  void _startLineupAnimation({required bool main}) {
    if (main) {
      _mainAnimGen++;
      final gen = _mainAnimGen;
      setState(() => _mapStep = 0);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _mainAnimGen != gen) return;
        setState(() => _mapStep = 1); // появляется маркер

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _mainAnimGen != gen) return;
          setState(() => _mapStep = 2); // начинается траектория
          _trajCtrl.reset();
          _trajCtrl.forward();

          // 2с траектория + 1с пауза, затем видео
          _phaseTimer?.cancel();
          _phaseTimer = Timer(const Duration(milliseconds: 4000), () {
            if (!mounted || _mainAnimGen != gen) return;
            setState(() => _subPhase = _SubPhase.video);
          });
        });
      });
    } else {
      _replayAnimGen++;
      final gen = _replayAnimGen;
      setState(() {
        _replayMapStep = 0;
        _replaySubPhase = _SubPhase.map;
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _replayAnimGen != gen) return;
        setState(() => _replayMapStep = 1);

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _replayAnimGen != gen) return;
          setState(() => _replayMapStep = 2);
          _trajCtrl.reset();
          _trajCtrl.forward();

          _replayTimer?.cancel();
          _replayTimer = Timer(const Duration(milliseconds: 4000), () {
            if (!mounted || _replayAnimGen != gen) return;
            setState(() => _replaySubPhase = _SubPhase.video);
          });
        });
      });
    }
  }

  void _onLineupNext() {
    switch (_phase) {
      case _Phase.lineup1:
        _advanceTo(_Phase.vsTransition);
      case _Phase.lineup2:
        _advanceTo(_Phase.vote);
      default:
        break;
    }
  }

  // ─── Реплей ──────────────────────────────────────────────────────────────

  void _startReplay(int lineupNum) {
    _replayAnimGen++;
    setState(() {
      _replayLineup = lineupNum;
      _replaySubPhase = _SubPhase.map;
      _replayMapStep = 0;
    });
    _startLineupAnimation(main: false);
  }

  void _closeReplay() {
    _replayTimer?.cancel();
    _replayAnimGen++;
    setState(() => _replayLineup = null);
  }

  // ─── Голосование ─────────────────────────────────────────────────────────

  Future<void> _vote(int choice) async {
    if (AuthService.userId == null) {
      AppSnackBar.show(context, 'Войди в аккаунт, чтобы голосовать');
      return;
    }
    setState(() => _voting = true);
    final duelSnapshot = _duel;
    try {
      await DuelService.vote(widget.duelId, choice);
      if (!mounted) return;
      setState(() {
        _voted = choice;
        _phase = _Phase.voted;
      });
      if (duelSnapshot != null &&
          duelSnapshot.endsAt.isAfter(DateTime.now())) {
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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    if (_duel == null) {
      return Scaffold(
        backgroundColor: t.background,
        appBar: _buildAppBar(t, '⚔️ Дуэль'),
        body: Center(child: CircularProgressIndicator(color: t.primary)),
      );
    }

    return Scaffold(
      backgroundColor: t.background,
      appBar: _buildAppBar(t, _appBarTitle()),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: _buildCurrentPhase(t),
            ),
          ),
          if (_replayLineup != null) _buildReplayOverlay(t),
        ],
      ),
    );
  }

  AppBar _buildAppBar(AppThemeData t, String title) {
    return AppBar(
      backgroundColor: t.surface,
      title: Text(title,
          style: TextStyle(
              color: t.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15)),
      iconTheme: IconThemeData(color: t.textPrimary),
      elevation: 0,
    );
  }

  String _appBarTitle() {
    switch (_phase) {
      case _Phase.intro:
        return '⚔️ Дуэль';
      case _Phase.lineup1:
        return 'Лайнап #1';
      case _Phase.vsTransition:
        return 'VS';
      case _Phase.lineup2:
        return 'Лайнап #2';
      case _Phase.vote:
        return 'Голосование';
      case _Phase.voted:
        return 'Готово';
    }
  }

  Widget _buildCurrentPhase(AppThemeData t) {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro(t);
      case _Phase.lineup1:
        return _buildLineupPhase(t,
            lineupNum: 1,
            lineup: _lineup1,
            abilityIcon: _abilityIcon1,
            agentIcon: _agentIcon1,
            subPhase: _subPhase,
            mapStep: _mapStep);
      case _Phase.vsTransition:
        return _buildVsTransition(t);
      case _Phase.lineup2:
        return _buildLineupPhase(t,
            lineupNum: 2,
            lineup: _lineup2,
            abilityIcon: _abilityIcon2,
            agentIcon: _agentIcon2,
            subPhase: _subPhase,
            mapStep: _mapStep);
      case _Phase.vote:
        return _buildVote(t);
      case _Phase.voted:
        return _buildVoted(t);
    }
  }

  // ─── Интро ───────────────────────────────────────────────────────────────

  Widget _buildIntro(AppThemeData t) {
    final mapName = _duel?.mapName ?? '';
    final agentName = _lineup1?['agent'] as String? ?? '';
    final title1 = _lineup1?['title'] as String? ?? '...';

    return Stack(
      children: [
        // Частицы на фоне
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, _) => CustomPaint(
                painter: _SparkPainter(
                  t: _particleCtrl.value,
                  color: t.primary,
                ),
              ),
            ),
          ),
        ),

        // Основной контент
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Иконка + заголовок
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: t.primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Text('⚔️', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 20),
                Text(
                  'ДУЭЛЬ ЛАЙНАПОВ',
                  style: TextStyle(
                    color: t.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                          color: t.primary.withValues(alpha: 0.4),
                          blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (mapName.isNotEmpty || agentName.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (mapName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: t.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined,
                                  color: t.primary, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                mapName,
                                style: TextStyle(
                                  color: t.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (agentName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: t.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_agentIcon1 != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: _agentIcon1!,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) =>
                                        const SizedBox(width: 18, height: 18),
                                    errorWidget: (_, _, _) => Icon(
                                        Icons.person_outline,
                                        color: t.textSecondary,
                                        size: 14),
                                  ),
                                )
                              else
                                Icon(Icons.person_outline,
                                    color: t.textSecondary, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                agentName,
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 36),

                // Карточка претендента — тот же стиль, что на экране VS
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: t.primary.withValues(
                            alpha: 0.3 + 0.7 * _glowAnim.value),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.primary.withValues(
                              alpha: 0.05 + 0.25 * _glowAnim.value),
                          blurRadius: 6 + 22 * _glowAnim.value,
                          spreadRadius: 1 + 3 * _glowAnim.value,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ПЕРВЫЙ ПРЕТЕНДЕНТ',
                          style: TextStyle(
                            color: t.primary.withValues(alpha: 0.7),
                            fontSize: 10,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_abilityIcon1 != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: t.primary.withValues(
                                    alpha: 0.4 + 0.5 * _glowAnim.value),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: t.primary.withValues(
                                      alpha: 0.1 + 0.25 * _glowAnim.value),
                                  blurRadius: 4 + 12 * _glowAnim.value,
                                ),
                              ],
                            ),
                            child: CachedNetworkImage(
                              imageUrl: _abilityIcon1!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              placeholder: (_, _) =>
                                  const SizedBox(width: 40, height: 40),
                              errorWidget: (_, _, _) =>
                                  const SizedBox(width: 40, height: 40),
                            ),
                          ),
                        Text(
                          title1,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (agentName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            agentName,
                            style: TextStyle(
                                color: t.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Сейчас начнётся...',
                      style: TextStyle(color: t.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Фаза лайнапа ────────────────────────────────────────────────────────

  Widget _buildLineupPhase(
    AppThemeData t, {
    required int lineupNum,
    required Map<String, dynamic>? lineup,
    required String? abilityIcon,
    required String? agentIcon,
    required _SubPhase subPhase,
    required int mapStep,
  }) {
    if (lineup == null) {
      return Center(child: CircularProgressIndicator(color: t.primary));
    }

    final title = lineup['title'] as String? ?? 'Лайнап #$lineupNum';
    final author = lineup['submitted_by'] as String? ?? '';
    final description = lineup['description'] as String? ?? '';
    final videoUrl = lineup['video_url'] as String?;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final inVideo = subPhase == _SubPhase.video && hasVideo;
    final mapName = lineup['map'] as String? ?? '';
    final agentName = lineup['agent'] as String? ?? '';
    final screenshots = List<String>.from(lineup['screenshots'] ?? []);
    final preloadedCtrl =
        lineupNum == 1 ? _preloadedCtrl1 : _preloadedCtrl2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: t.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (abilityIcon != null) ...[
                    CachedNetworkImage(
                      imageUrl: abilityIcon,
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const SizedBox(width: 30, height: 30),
                      errorWidget: (_, _, _) =>
                          const SizedBox(width: 30, height: 30),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _red.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Лайнап #$lineupNum',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (mapName.isNotEmpty || agentName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (mapName.isNotEmpty)
                      _tag(t, Icons.map_outlined, mapName),
                    if (agentName.isNotEmpty)
                      _agentTag(t, agentIcon, agentName),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (author.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
            child: Text('Автор: $author',
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ),

        // Скроллируемое тело: медиа + описание + баннер
        Expanded(
          child: LayoutBuilder(builder: (ctx, box) {
            final w = box.maxWidth;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Медиа с рамкой
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildGlowWrapper(
                      child: _buildMediaContent(
                        lineup: lineup,
                        subPhase: subPhase,
                        mapStep: mapStep,
                        abilityIcon: abilityIcon,
                        videoKey: ValueKey(
                            'main_$lineupNum${videoUrl ?? ''}'),
                        width: w - 20,
                        preloadedCtrl: preloadedCtrl,
                      ),
                    ),
                  ),

                  // Описание — появляется при видео
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: inVideo && description.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: t.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.border),
                              ),
                              child: Text(
                                description,
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Скриншоты — появляются при видео
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: inVideo && screenshots.isNotEmpty
                        ? _buildScreenshots(t, screenshots)
                        : const SizedBox.shrink(),
                  ),

                  // Баннерная реклама под скриншотами
                  if (inVideo)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: const Color(0xFF1A2433),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const AdBannerWidget(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          }),
        ),

        // Кнопка «Далее» (пикнута снизу, появляется при видео)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: inVideo
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onLineupNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            lineupNum == 1
                                ? 'Следующий лайнап'
                                : 'К голосованию',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(height: 0),
        ),
      ],
    );
  }

  Widget _buildScreenshots(AppThemeData t, List<String> urls) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + подсказка о свайпе
          Row(
            children: [
              Text(
                'Скриншоты',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (urls.length > 1) ...[
                const Spacer(),
                Icon(Icons.swipe_right_alt_outlined,
                    color: t.textSecondary, size: 13),
                const SizedBox(width: 4),
                Text(
                  'листай',
                  style: TextStyle(color: t.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Список с фейдом правого края
          Stack(
            children: [
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: urls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () async {
                      setState(() => _videoPausedByImage = true);
                      await _showScreenshot(ctx, urls, i);
                      if (mounted) setState(() => _videoPausedByImage = false);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: urls[i],
                        height: 130,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          width: 200,
                          height: 130,
                          color: t.surface2,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: t.primary, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: 200,
                          height: 130,
                          color: t.surface2,
                          child: Icon(Icons.broken_image,
                              color: t.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Фейд правого края — подсказка что есть ещё
              if (urls.length > 1)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            t.background.withValues(alpha: 0),
                            t.background.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Точки-индикаторы
          if (urls.length > 1) ...[
            const SizedBox(height: 6),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  urls.length,
                  (i) => Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: t.textSecondary.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showScreenshot(
      BuildContext ctx, List<String> urls, int initial) {
    return Navigator.push(
      ctx,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ScreenshotViewer(urls: urls, initial: initial),
      ),
    );
  }

  Widget _tag(AppThemeData t, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: t.textSecondary, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _agentTag(AppThemeData t, String? iconUrl, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CachedNetworkImage(
                imageUrl: iconUrl,
                width: 14,
                height: 14,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(width: 14, height: 14),
                errorWidget: (_, _, _) =>
                    Icon(Icons.person_outline, color: t.textSecondary, size: 11),
              ),
            )
          else
            Icon(Icons.person_outline, color: t.textSecondary, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Рамка с подсветкой и частицами ─────────────────────────────────────

  Widget _buildGlowWrapper({required Widget child}) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (ctx, c) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _red.withValues(alpha: 0.4 + 0.6 * _glowAnim.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.08 + 0.35 * _glowAnim.value),
                blurRadius: 8 + 22 * _glowAnim.value,
                spreadRadius: 1 + 3 * _glowAnim.value,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  // ─── Медиа-контент (карта → видео) ───────────────────────────────────────

  Widget _buildMediaContent({
    required Map<String, dynamic> lineup,
    required _SubPhase subPhase,
    required int mapStep,
    required Key videoKey,
    required double width,
    String? abilityIcon,
    VideoPlayerController? preloadedCtrl,
  }) {
    final mapName = lineup['map'] as String? ?? '';
    final asset = _mapAssets[mapName];
    final px = (lineup['position_x'] as num?)?.toDouble();
    final py = (lineup['position_y'] as num?)?.toDouble();
    final rawTraj = lineup['trajectory'];
    final trajectory = rawTraj is List
        ? rawTraj.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final videoUrl = lineup['video_url'] as String?;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    final mapH = width;
    final videoH = width * 9 / 16;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: width,
      height: subPhase == _SubPhase.video && hasVideo ? videoH : mapH,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Stack(
        children: [
          // Чёрный фон (всегда)
          const Positioned.fill(child: ColoredBox(color: Colors.black)),

          // Частицы — под картой, над фоном; гаснут во время видео
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: subPhase == _SubPhase.video ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 500),
                child: AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, _) => CustomPaint(
                    painter: _SparkPainter(
                      t: _particleCtrl.value,
                      color: _red,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Видео (предзагружается скрытым, воспроизводится только при video-фазе)
          if (hasVideo)
            Positioned.fill(
              child: Center(
                child: AnimatedOpacity(
                  opacity: subPhase == _SubPhase.video ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: IgnorePointer(
                    ignoring: subPhase != _SubPhase.video,
                    child: _DuelVideoPlayer(
                      key: videoKey,
                      videoUrl: videoUrl,
                      playing: subPhase == _SubPhase.video && !_videoPausedByImage,
                      preloadedCtrl: preloadedCtrl,
                    ),
                  ),
                ),
              ),
            ),

          // Карта (скрывается при переходе на видео)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: subPhase == _SubPhase.video ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: IgnorePointer(
                ignoring: subPhase == _SubPhase.video,
                child: asset != null
                    ? LayoutBuilder(
                        builder: (ctx2, c2) => Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Image.asset(asset, fit: BoxFit.contain),

                            // Траектория (только mapStep == 2)
                            if (trajectory.length >= 2 && mapStep >= 2)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _TrajectoryPainter(
                                    points: trajectory,
                                    progress: _trajCtrl.value,
                                    color: _red,
                                  ),
                                  size: Size(c2.maxWidth, c2.maxHeight),
                                ),
                              ),

                            // Маркер с иконкой абилки (появляется с mapStep >= 1)
                            if (px != null && py != null)
                              Positioned(
                                left: px * c2.maxWidth - 16,
                                top: py * c2.maxHeight - 16,
                                child: AnimatedOpacity(
                                  opacity: mapStep >= 1 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: _markerDot(abilityIcon),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'Карта недоступна',
                          style: TextStyle(
                              color: AppThemeNotifier.of(context).textSecondary,
                              fontSize: 12),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _markerDot(String? abilityIcon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(color: _red, width: 2),
        boxShadow: [
          BoxShadow(color: _red.withValues(alpha: 0.5), blurRadius: 6),
          const BoxShadow(color: Colors.black54, blurRadius: 3),
        ],
      ),
      child: abilityIcon != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: abilityIcon,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => Icon(Icons.circle,
                    color: _red, size: 16),
              ),
            )
          : Icon(Icons.my_location, color: _red, size: 16),
    );
  }

  // ─── VS переход ──────────────────────────────────────────────────────────

  Widget _buildVsTransition(AppThemeData t) {
    final title2 = _lineup2?['title'] as String? ?? '...';
    final agent2 = _lineup2?['agent'] as String? ?? '';

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, _) => CustomPaint(
                painter: _SparkPainter(
                  t: _particleCtrl.value,
                  color: t.primary,
                ),
              ),
            ),
          ),
        ),
        Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (ctx, v, _) => Transform.scale(
                scale: v,
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: t.primary,
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    shadows: [
                      Shadow(
                          color: t.primary.withValues(alpha: 0.5),
                          blurRadius: 24),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Теперь — второй претендент',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Карточка второго лайнапа с пульсирующей рамкой
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (ctx, _) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t.primary
                        .withValues(alpha: 0.3 + 0.7 * _glowAnim.value),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.primary.withValues(
                          alpha: 0.05 + 0.25 * _glowAnim.value),
                      blurRadius: 6 + 20 * _glowAnim.value,
                      spreadRadius: 1 + 3 * _glowAnim.value,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'ВТОРОЙ ПРЕТЕНДЕНТ',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_abilityIcon2 != null) ...[
                      // Иконка абилки тоже с пульсацией
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: t.primary.withValues(
                                alpha: 0.4 + 0.6 * _glowAnim.value),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.primary.withValues(
                                  alpha: 0.1 + 0.3 * _glowAnim.value),
                              blurRadius: 4 + 12 * _glowAnim.value,
                            ),
                          ],
                        ),
                        child: CachedNetworkImage(
                          imageUrl: _abilityIcon2!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const SizedBox(width: 36, height: 36),
                          errorWidget: (_, _, _) =>
                              const SizedBox(width: 36, height: 36),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      title2,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (agent2.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_agentIcon2 != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: _agentIcon2!,
                                width: 18,
                                height: 18,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    const SizedBox(width: 18, height: 18),
                                errorWidget: (_, _, _) =>
                                    const SizedBox(),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(agent2,
                              style: TextStyle(
                                  color: t.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      ],
    );
  }

  // ─── Экран голосования ───────────────────────────────────────────────────

  Widget _buildVote(AppThemeData t) {
    final title1 = _lineup1?['title'] as String? ?? 'Лайнап #1';
    final title2 = _lineup2?['title'] as String? ?? 'Лайнап #2';
    final alreadyVoted = _voted != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Какой лайнап тебе\nбольше понравился?',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Твой голос помогает сообществу',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Кнопка лайнапа 1 с миганием
          _winkWrapper(ctrl: _wink1Ctrl, child: _voteButton(t, choice: 1, title: title1, already: alreadyVoted)),
          const SizedBox(height: 12),

          // Кнопка лайнапа 2 с миганием
          _winkWrapper(ctrl: _wink2Ctrl, child: _voteButton(t, choice: 2, title: title2, already: alreadyVoted)),

          const SizedBox(height: 32),
          Divider(color: t.border),
          const SizedBox(height: 20),

          Text(
            'Хочешь пересмотреть?',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _replayButton(t,
                    lineupNum: 1, label: 'Пересмотреть\nлайнап #1'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _replayButton(t,
                    lineupNum: 2, label: 'Пересмотреть\nлайнап #2'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Разовая пульсация рамки + лёгкое масштабирование
  Widget _winkWrapper({
    required AnimationController ctrl,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (ctx, c) {
        final v = math.sin(ctrl.value * math.pi); // колокол 0→1→0
        final scale = 1.0 + 0.025 * v;
        return Transform.scale(
          scale: scale,
          child: Stack(
            children: [
              c!,
              if (v > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _red.withValues(alpha: v * 0.85),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _red.withValues(alpha: v * 0.3),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: child,
    );
  }

  Widget _voteButton(AppThemeData t,
      {required int choice, required String title, required bool already}) {
    final isMyChoice = _voted == choice;
    final icon = choice == 1 ? _abilityIcon1 : _abilityIcon2;

    return GestureDetector(
      onTap: already || _voting
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.2),
                builder: (ctx) => BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: AlertDialog(
                    backgroundColor: t.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    title: Text(
                      'Вы уверены?',
                      style: TextStyle(
                          color: t.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'Ты голосуешь за «$title».\nГолос нельзя изменить.',
                      style: TextStyle(color: t.textSecondary, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Отмена',
                            style: TextStyle(color: t.textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Проголосовать',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
              if (confirmed == true) _vote(choice);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isMyChoice ? _green.withValues(alpha: 0.12) : t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMyChoice
                ? _green
                : already
                    ? t.border
                    : _red.withValues(alpha: 0.5),
            width: isMyChoice ? 2 : 1.5,
          ),
          boxShadow: isMyChoice
              ? [
                  BoxShadow(
                      color: _green.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              CachedNetworkImage(
                imageUrl: icon,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(width: 28, height: 28),
                errorWidget: (_, _, _) =>
                    const SizedBox(width: 28, height: 28),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Лайнап #$choice',
                    style: TextStyle(
                      color: isMyChoice ? _green : t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: isMyChoice ? _green : t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMyChoice)
              const Icon(Icons.check_circle, color: _green, size: 24)
            else if (!already)
              Icon(Icons.how_to_vote_outlined, color: _red, size: 22)
            else
              Icon(Icons.radio_button_unchecked,
                  color: t.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _replayButton(AppThemeData t,
      {required int lineupNum, required String label}) {
    return GestureDetector(
      onTap: () => _startReplay(lineupNum),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.replay, color: t.primary, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Экран «Спасибо» ─────────────────────────────────────────────────────

  Widget _buildVoted(AppThemeData t) {
    final votedTitle = _voted == 1
        ? (_lineup1?['title'] as String? ?? 'Лайнап #1')
        : (_lineup2?['title'] as String? ?? 'Лайнап #2');
    final pct1 = _duel?.percent1 ?? 0;
    final pct2 = _duel?.percent2 ?? 0;
    final total = _duel?.totalVotes ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text('🎯', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Спасибо за голос!',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ты проголосовал за',
            style: TextStyle(color: t.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '«$votedTitle»',
            style: TextStyle(
              color: t.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Text(
              'Твой голос помогает сообществу отбирать лучшие лайнапы. '
              'Ты часть этого — вместе мы делаем контент лучше! 💪',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),

          if (total > 0) ...[
            Text(
              'Текущие результаты ($total голосов)',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _resultBar(t,
                label: _lineup1?['title'] ?? 'Лайнап #1',
                pct: pct1,
                color: _red,
                isVoted: _voted == 1),
            const SizedBox(height: 8),
            _resultBar(t,
                label: _lineup2?['title'] ?? 'Лайнап #2',
                pct: pct2,
                color: _green,
                isVoted: _voted == 2),
            const SizedBox(height: 28),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.surface2,
                foregroundColor: t.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: t.border),
              ),
              child: const Text('Вернуться к дуэлям',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _resultBar(AppThemeData t,
      {required String label,
      required double pct,
      required Color color,
      required bool isVoted}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isVoted)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: color, size: 14),
              ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isVoted ? color : t.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      isVoted ? FontWeight.bold : FontWeight.normal,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isVoted ? color : t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: t.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── Оверлей реплея ──────────────────────────────────────────────────────

  Widget _buildReplayOverlay(AppThemeData t) {
    final lineupNum = _replayLineup!;
    final lineup = lineupNum == 1 ? _lineup1 : _lineup2;
    final abilityIcon = lineupNum == 1 ? _abilityIcon1 : _abilityIcon2;
    final title = lineup?['title'] as String? ?? 'Лайнап #$lineupNum';

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Шапка оверлея
          Container(
            padding:
                const EdgeInsets.only(top: 8, left: 4, right: 16, bottom: 8),
            color: t.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  color: t.textPrimary,
                  onPressed: _closeReplay,
                ),
                if (abilityIcon != null) ...[
                  CachedNetworkImage(
                    imageUrl: abilityIcon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const SizedBox(width: 24, height: 24),
                    errorWidget: (_, _, _) =>
                        const SizedBox(width: 24, height: 24),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    'Пересмотр: $title',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Медиа с рамкой и частицами
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              final w = box.maxWidth;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: _buildGlowWrapper(
                        child: lineup != null
                            ? _buildMediaContent(
                                lineup: lineup,
                                subPhase: _replaySubPhase,
                                mapStep: _replayMapStep,
                                abilityIcon: abilityIcon,
                                videoKey: ValueKey(
                                    'replay_$lineupNum${lineup['video_url'] ?? ''}'),
                                width: w - 20,
                              )
                            : SizedBox(
                                width: w - 20,
                                height: w - 20,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: t.primary)),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          // Кнопка «Вернуться к голосованию»
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: _replaySubPhase == _SubPhase.video
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _closeReplay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.surface2,
                          foregroundColor: t.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: t.border),
                        ),
                        child: const Text('Вернуться к голосованию',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }
}

bool _isYoutubeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.replaceFirst('www.', '');
  return host == 'youtu.be' || host == 'youtube.com';
}

// ─── Частицы (искры) ──────────────────────────────────────────────────────────

class _SparkPainter extends CustomPainter {
  final double t;
  final Color color;

  static final _sparks = List.generate(22, (i) {
    final rng = math.Random(i * 31 + 7);
    return (
      x: rng.nextDouble(),
      phase: rng.nextDouble(),
      size: rng.nextDouble() * 2.5 + 1.0,
      speed: rng.nextDouble() * 0.4 + 0.7,
    );
  });

  const _SparkPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _sparks) {
      final life = ((t * s.speed + s.phase) % 1.0);
      final alpha = life < 0.25
          ? life / 0.25
          : (life < 0.65 ? 1.0 : (1.0 - life) / 0.35);
      final x = s.x * size.width;
      final y = size.height * (1 - life);
      canvas.drawCircle(
        Offset(x, y),
        s.size * (1 - life * 0.4),
        Paint()
          ..color = color.withValues(alpha: (alpha * 0.8).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}

// ─── Видео-плеер ─────────────────────────────────────────────────────────────

class _DuelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool playing;
  final VideoPlayerController? preloadedCtrl;
  const _DuelVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.playing,
    this.preloadedCtrl,
  });

  @override
  State<_DuelVideoPlayer> createState() => _DuelVideoPlayerState();
}

class _DuelVideoPlayerState extends State<_DuelVideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;
  bool _showControls = false; // скрыты по умолчанию, появляются по тапу
  bool _finished = false;
  bool _ownsCtrl = false;
  bool _shouldBePlaying = false; // намерение воспроизведения
  bool _wasBuffering = false;    // для детекции конца буферизации

  @override
  void initState() {
    super.initState();
    _shouldBePlaying = widget.playing;
    final pre = widget.preloadedCtrl;
    if (pre != null && pre.value.isInitialized) {
      _ctrl = pre;
      _ready = true;
      _ownsCtrl = false;
      _ctrl!.addListener(_onUpdate);
      if (widget.playing && !_finished) _ctrl!.play();
    } else {
      _ownsCtrl = true;
      _initPlayer();
    }
  }

  @override
  void didUpdateWidget(_DuelVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      _shouldBePlaying = widget.playing;
      if (widget.playing) {
        if (_ready && _ctrl != null && !_finished) _ctrl!.play();
      } else {
        _ctrl?.pause();
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onUpdate);
    if (_ownsCtrl) {
      _ctrl?.dispose();
    } else {
      // Предзагруженный контроллер принадлежит родителю — только пауза,
      // чтобы не слышать аудио при смене фазы
      _ctrl?.pause();
    }
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      VideoPlayerController ctrl;
      if (_isYoutubeUrl(widget.videoUrl)) {
        final yt = YoutubeExplode();
        final manifest =
            await yt.videos.streamsClient.getManifest(VideoId(widget.videoUrl));
        final streamUrl = manifest.muxed.withHighestBitrate().url.toString();
        yt.close();
        ctrl = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.addListener(_onUpdate);
      if (widget.playing) ctrl.play();
      setState(() {
        _ctrl = ctrl;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onUpdate() {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;

    final isBuffering = ctrl.value.isBuffering;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    // isFinished вычисляется ДО авторезюма, чтобы не запустить видео заново
    final isFinished = dur.inMilliseconds > 0 &&
        pos >= dur - const Duration(milliseconds: 200) &&
        !ctrl.value.isPlaying &&
        !isBuffering;

    // Авторезюм после буферизации — только если видео не закончилось
    if (_shouldBePlaying && !isFinished && _wasBuffering && !isBuffering && !ctrl.value.isPlaying) {
      ctrl.play();
    }
    _wasBuffering = isBuffering;

    // Сбрасываем намерение воспроизведения при завершении
    if (isFinished && !_finished) _shouldBePlaying = false;

    if (isFinished != _finished) {
      setState(() => _finished = isFinished);
    } else {
      if (!mounted) return;
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && (_ctrl?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlay() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (_finished) {
      ctrl.seekTo(Duration.zero);
      ctrl.play();
      _shouldBePlaying = true;
      setState(() {
        _finished = false;
        _showControls = true;
      });
      _scheduleHideControls();
      return;
    }
    final wasPlaying = ctrl.value.isPlaying || ctrl.value.isBuffering;
    if (wasPlaying) {
      ctrl.pause();
      _shouldBePlaying = false;
    } else {
      ctrl.play();
      _shouldBePlaying = true;
      _scheduleHideControls();
    }
    setState(() => _showControls = true);
  }

  void _showFullscreen(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(controller: ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Color(0xFF0d0f17),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white38, size: 36),
                SizedBox(height: 8),
                Text('Видео недоступно',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    if (!_ready || _ctrl == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: const Color(0xFF0d0f17),
          child: Center(
            child: Builder(builder: (ctx) => CircularProgressIndicator(color: AppThemeNotifier.of(ctx).primary)),
          ),
        ),
      );
    }

    final ctrl = _ctrl!;
    final isPlaying = ctrl.value.isPlaying;
    final isBuffering = ctrl.value.isBuffering;

    return AspectRatio(
      aspectRatio: ctrl.value.aspectRatio,
      child: GestureDetector(
        onTap: () {
          if (_finished) {
            _togglePlay();
          } else {
            final nowVisible = !_showControls;
            setState(() => _showControls = nowVisible);
            if (nowVisible && (isPlaying || isBuffering)) {
              _scheduleHideControls();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.bottomCenter,
          children: [
            ColoredBox(color: Colors.black, child: VideoPlayer(ctrl)),

            // Индикатор буферизации — всегда поверх, не зависит от контролов
            if (isBuffering && !_finished)
              IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),

            // Оверлей «Видео закончилось»
            if (_finished)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.replay,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Смотреть ещё раз',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Контролы — появляются только по тапу
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: isBuffering
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                    // Кнопка «На весь экран»
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _showFullscreen(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(
                        ctrl,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppThemeNotifier.of(context).primary,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white12,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
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

// ─── Полноэкранный видео-плеер ────────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideoPage({required this.controller});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    final ctrl = widget.controller;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    final isFinished = dur.inMilliseconds > 0 &&
        pos >= dur - const Duration(milliseconds: 200) &&
        !ctrl.value.isPlaying;
    if (isFinished) {
      ctrl.seekTo(Duration.zero);
      ctrl.play();
    } else {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    }
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && (widget.controller.value.isPlaying)) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isPlaying = ctrl.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Center(
          child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(ctrl),
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                      Center(
                        child: GestureDetector(
                          onTap: _toggle,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen_exit,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: VideoProgressIndicator(
                          ctrl,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: AppThemeNotifier.of(context).primary,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Рисовалка траектории ─────────────────────────────────────────────────────

class _TrajectoryPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final double progress;
  final Color color;

  const _TrajectoryPainter({
    required this.points,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || progress <= 0) return;

    final pts = points
        .map((p) => Offset(
              (p['x'] as num).toDouble() * size.width,
              (p['y'] as num).toDouble() * size.height,
            ))
        .toList();

    final segments = <double>[];
    double totalLen = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final d = (pts[i + 1] - pts[i]).distance;
      segments.add(d);
      totalLen += d;
    }
    if (totalLen < 0.01) return;

    final targetLen = totalLen * progress;
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    double drawn = 0;
    Offset currentEnd = pts.first;
    Offset segmentStart = pts.first;

    for (int i = 0; i < pts.length - 1; i++) {
      if (drawn >= targetLen) break;
      final segLen = segments[i];
      final remaining = targetLen - drawn;
      segmentStart = pts[i];
      if (remaining >= segLen) {
        canvas.drawLine(pts[i], pts[i + 1], linePaint);
        drawn += segLen;
        currentEnd = pts[i + 1];
      } else {
        final frac = remaining / segLen;
        currentEnd = Offset.lerp(pts[i], pts[i + 1], frac)!;
        canvas.drawLine(pts[i], currentEnd, linePaint);
        drawn = targetLen;
      }
    }

    double d = 0;
    for (int i = 0; i < pts.length; i++) {
      if (d <= targetLen) canvas.drawCircle(pts[i], 3.5, fillPaint);
      if (i < segments.length) d += segments[i];
    }

    if ((currentEnd - segmentStart).distance > 1) {
      _drawArrow(canvas, segmentStart, currentEnd, fillPaint);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.01) return;
    final ux = dx / len;
    final uy = dy / len;
    const s = 8.0;
    const hw = 4.0;
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
  bool shouldRepaint(_TrajectoryPainter old) =>
      old.progress != progress || old.points != points;
}

// ─── Просмотрщик скриншотов ───────────────────────────────────────────────────

class _ScreenshotViewer extends StatefulWidget {
  final List<String> urls;
  final int initial;
  const _ScreenshotViewer({required this.urls, required this.initial});

  @override
  State<_ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<_ScreenshotViewer> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _pageCtrl = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image,
                      color: Colors.white38,
                      size: 64),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (widget.urls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_current + 1} / ${widget.urls.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
