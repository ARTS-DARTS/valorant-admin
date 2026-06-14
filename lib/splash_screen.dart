import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'app_theme.dart';
import 'ad_service.dart';
import 'notification_service.dart';
import 'push_queue_service.dart';
import 'onboarding_screen.dart';
import 'force_update_service.dart';
import 'error_logging_service.dart';
import 'valorant_api.dart';
import 'services/image_cache_service.dart';

typedef SplashCompleteCallback = void Function({
  required bool registered,
  required bool onboardingShown,
  required bool hasSession,
  String? softUpdateVersion,
});

class SplashScreen extends StatefulWidget {
  final ValueNotifier<AppThemeData> themeNotifier;
  final SplashCompleteCallback onComplete;

  const SplashScreen({
    super.key,
    required this.themeNotifier,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  String? _softUpdateVersion;

  static const _bg = Color(0xFF1A1A2E);
  static const _accent = Color(0xFFFF4655);
  static const _sovaAsset = 'assets/agents/sova.png';
  static const _fadeAsset = 'assets/agents/fade.png';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _advance(double progress) async {
    if (!mounted) return;
    setState(() => _progress = progress);
    await Future.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    FlutterNativeSplash.remove();

    bool registered = false;
    bool onboardingShown = false;
    bool hasSession = false;
    bool updateRequired = false;

    try {
      await _advance(0.15);
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyA1ya7fO5ZSeeokEfRHikWwpBXeXYhm9ww',
          appId: '1:288103111419:android:4870bc496f63ffda996e5e',
          messagingSenderId: '288103111419',
          projectId: 'valorant-linemaps',
          storageBucket: 'valorant-linemaps.firebasestorage.app',
        ),
      );

      await _advance(0.25);
      await ErrorLoggingService.init();
      await _clearCacheIfUpdated();
      _warmImageCache(); // fire-and-forget, не блокирует сплэш

      await _advance(0.30);
      final initResults = await Future.wait<dynamic>([
        ForceUpdateService.checkUpdate(),
        AppThemes.loadSaved(),
        AdService.initialize(),
        NotificationService.initialize(),
      ]);
      final updateCheck = initResults[0] as ({UpdateStatus status, String? latestVersion});
      updateRequired = updateCheck.status == UpdateStatus.required;
      _softUpdateVersion = updateCheck.status == UpdateStatus.soft
          ? updateCheck.latestVersion
          : null;
      final savedThemeType = initResults[1] as AppThemeType;
      widget.themeNotifier.value = AppThemes.byType(savedThemeType);

      await _advance(0.72);
      registered = await AuthService.isRegistered();
      onboardingShown = !(await OnboardingScreen.shouldShow());
      hasSession = await AuthService.hasActiveSession();

      final uid = AuthService.userId;
      if (uid != null) {
        await Future.wait([
          AuthService.syncUsername(),
          AuthService.syncUserLevel(),
          NotificationService.loginUser(uid),
        ]);
        PushQueueService.startListening();
      }

      await _advance(1.0);
      // Пауза после звука вспышки — дать ему отыграть
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {
      if (mounted) setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;

    if (updateRequired) {
      _showForceUpdateDialog();
      return;
    }

    widget.onComplete(
      registered: registered,
      onboardingShown: onboardingShown,
      hasSession: hasSession,
      softUpdateVersion: _softUpdateVersion,
    );
  }

  // Clears image + API JSON caches when the app version changes.
  // Login keys (username, registered, user_email) are never touched.
  static Future<void> _clearCacheIfUpdated() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('cached_app_version');
      if (stored != current) {
        await Future.wait([
          AppImageCache.manager.emptyCache(),
          ValorantApi.clearCache(),
        ]);
        await prefs.setString('cached_app_version', current);
      }
    } catch (_) {}
  }

  Future<void> _warmImageCache() async {
    try {
      var agents = await ValorantApi.getCached();
      agents ??= await ValorantApi.getAgents();
      if (!mounted) return;
      for (final agent in agents) {
        if (!mounted) return;
        final icon = agent['displayIconSmall'] as String?;
        if (icon != null && icon.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(icon, cacheManager: AppImageCache.manager),
            context,
          ).ignore();
        }
        for (final ability in (agent['abilities'] as List? ?? [])) {
          if (!mounted) return;
          final abilIcon = (ability as Map)['displayIcon'] as String?;
          if (abilIcon != null && abilIcon.isNotEmpty) {
            precacheImage(
              CachedNetworkImageProvider(abilIcon, cacheManager: AppImageCache.manager),
              context,
            ).ignore();
          }
        }
      }
      // Warm map splash images
      var maps = await ValorantApi.getCachedMaps();
      if (maps.isEmpty) maps = await ValorantApi.getMaps();
      if (!mounted) return;
      for (final url in maps.values) {
        if (!mounted) return;
        if (url.isNotEmpty) {
          precacheImage(
            CachedNetworkImageProvider(url, cacheManager: AppImageCache.manager),
            context,
          ).ignore();
        }
      }
    } catch (_) {}
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A2530),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _accent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: _accent, size: 26),
              SizedBox(width: 10),
              Text('Доступно обновление',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Установи новую версию приложения, чтобы продолжить пользоваться Valorant Lineups.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openPlayStore,
                icon: const Icon(Icons.open_in_new,
                    color: Colors.white, size: 18),
                label: const Text('ОБНОВИТЬ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlayStore() async {
    final marketUri = Uri.parse(ForceUpdateService.playStoreUrl);
    final webUri = Uri.parse(ForceUpdateService.playStoreFallbackUrl);
    if (!await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final agentHeight = size.height * 0.65;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── Молнии ─────────────────────────────────────────────────
          Positioned.fill(
            child: _LightningLayer(progress: _progress),
          ),

          // ─── Агенты ─────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        _sovaAsset,
                        height: agentHeight,
                        fit: BoxFit.fitHeight,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(-1, 1, 1),
                        child: Image.asset(
                          _fadeAsset,
                          height: agentHeight,
                          fit: BoxFit.fitHeight,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Верхний градиент под заголовок ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size.height * 0.28,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.6, 1.0],
                  colors: [Color(0xDD1A1A2E), Color(0x881A1A2E), Colors.transparent],
                ),
              ),
            ),
          ),

          // ─── Заголовок ───────────────────────────────────────────────
          Positioned(
            top: 95,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VALORANT LINEUPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    shadows: [
                      Shadow(
                        color: _accent.withValues(alpha: 0.8),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LINEUP MAPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),

          // ─── Нижний градиент ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.42,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [Colors.transparent, Color(0xBB1A1A2E), _bg],
                ),
              ),
            ),
          ),

          // ─── Прогресс-бар ────────────────────────────────────────────
          Positioned(
            left: 32,
            right: 32,
            bottom: 52,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ЗАГРУЗКА...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _EnergyBar(progress: _progress),
                const SizedBox(height: 7),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lightning layer ──────────────────────────────────────────────────────────

class _LightningLayer extends StatefulWidget {
  final double progress;
  const _LightningLayer({required this.progress});

  @override
  State<_LightningLayer> createState() => _LightningLayerState();
}

class _LightningLayerState extends State<_LightningLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<_Bolt> _bolts = [];
  final Random _rng = Random();
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  Size _size = Size.zero;
  AudioPlayer? _zapPlayer;    // короткие искры / стримеры
  AudioPlayer? _arcPlayer;    // дуги между агентами
  AudioPlayer? _chargePlayer; // вспышка при 100%
  bool _zapPlayed    = false;
  bool _arcPlayed    = false;
  bool _chargePlayed = false;

  static const _sndZap    = 'sounds/electricity_us849kj.mp3';
  static const _sndArc1   = 'sounds/electricity_1FwUPLn.mp3';
  static const _sndCharge = 'sounds/electricity-charge-sound-effect.mp3';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )
      ..addListener(_tick)
      ..repeat();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _zapPlayer    = AudioPlayer()..setVolume(0.175);
      _arcPlayer    = AudioPlayer()..setVolume(0.25);
      _chargePlayer = AudioPlayer()..setVolume(0.325);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(_LightningLayer old) {
    super.didUpdateWidget(old);
    // При достижении 100% — вспышка из нескольких молний
    if (old.progress < 1.0 && widget.progress >= 1.0) _burst();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _repaint.dispose();
    _zapPlayer?.dispose();
    _arcPlayer?.dispose();
    _chargePlayer?.dispose();
    super.dispose();
  }

  void _tick() {
    if (_size == Size.zero) return;

    // Состаривание и удаление мёртвых молний
    for (int i = _bolts.length - 1; i >= 0; i--) {
      _bolts[i].frame++;
      if (_bolts[i].isDead) _bolts.removeAt(i);
    }

    // Вероятность спауна растёт вместе с прогрессом
    final chance = 0.028 + widget.progress * 0.065;
    if (_bolts.length < 14 && _rng.nextDouble() < chance) {
      final type = switch (_rng.nextDouble()) {
        < 0.30 => _BoltType.spark,
        < 0.52 => _BoltType.radial,
        < 0.68 => _BoltType.ground,
        < 0.83 => _BoltType.corona,
        _ => _BoltType.clash,
      };
      _bolts.add(_make(type));
      if (type == _BoltType.clash) _playArc();
      if (type != _BoltType.clash) _playZap();
    }

    _repaint.value++;
  }

  void _burst() {
    for (int i = 0; i < 16; i++) {
      final type = switch (_rng.nextDouble()) {
        < 0.28 => _BoltType.clash,
        < 0.52 => _BoltType.radial,
        < 0.68 => _BoltType.corona,
        < 0.84 => _BoltType.ground,
        _ => _BoltType.spark,
      };
      _bolts.add(_make(type));
    }
    _playCharge();
    _repaint.value++;
  }

  Future<void> _playArc() async {
    if (_arcPlayed) return;
    _arcPlayed = true;
    try {
      await _arcPlayer?.play(AssetSource(_sndArc1));
    } catch (_) {}
  }

  Future<void> _playZap() async {
    if (_zapPlayed) return;
    _zapPlayed = true;
    try {
      await _zapPlayer?.play(AssetSource(_sndZap));
    } catch (_) {}
  }

  Future<void> _playCharge() async {
    if (_chargePlayed) return;
    _chargePlayed = true;
    try {
      await _chargePlayer?.play(AssetSource(_sndCharge));
    } catch (_) {}
  }

  _Bolt _make(_BoltType type) {
    final w = _size.width;
    final h = _size.height;

    // Приблизительные координаты агентов (соответствуют лейауту виджета)
    final sovaX = w * 0.25;
    final fadeX = w * 0.75;
    final bodyTop = h * 0.22;
    final bodyBottom = h - 115.0;
    final centerY = (bodyTop + bodyBottom) * 0.5;

    switch (type) {
      // Луч, исходящий от тела агента в любую сторону
      case _BoltType.radial:
        final isLeft = _rng.nextBool();
        final cx = isLeft ? sovaX : fadeX;
        final cy = bodyTop + _rng.nextDouble() * (bodyBottom - bodyTop) * 0.72;
        final angle = _rng.nextDouble() * 2 * pi;
        final len = 38.0 + _rng.nextDouble() * 88;
        final col = _rng.nextDouble() < 0.65
            ? const Color(0xFF00CFFF)
            : const Color(0xFF4499FF);
        Path? branch;
        if (_rng.nextDouble() < 0.52) {
          final t = 0.38 + _rng.nextDouble() * 0.32;
          final mx = cx + cos(angle) * len * t;
          final my = cy + sin(angle) * len * t;
          final ba = angle + (_rng.nextDouble() - 0.5) * 1.3;
          final bl = len * (0.22 + _rng.nextDouble() * 0.28);
          branch = _zigzag(
              Offset(mx, my), Offset(mx + cos(ba) * bl, my + sin(ba) * bl), 5, 7);
        }
        return _Bolt(
          path: _zigzag(Offset(cx, cy),
              Offset(cx + cos(angle) * len, cy + sin(angle) * len), 9, 13),
          branch: branch,
          color: col,
          strokeWidth: 0.85 + _rng.nextDouble() * 1.15,
          totalFrames: 5 + _rng.nextInt(9),
        );

      // Дуга, огибающая силуэт агента (корона)
      case _BoltType.corona:
        final isLeft = _rng.nextBool();
        final cx = isLeft ? sovaX : fadeX;
        final r = 40.0 + _rng.nextDouble() * 55;
        final startA = _rng.nextDouble() * 2 * pi;
        final sweep = (0.45 + _rng.nextDouble() * 0.75) * pi;
        return _Bolt(
          path: _arc(Offset(cx, centerY), r, startA, startA + sweep, 9),
          color: Colors.white,
          strokeWidth: 0.55 + _rng.nextDouble() * 0.75,
          totalFrames: 6 + _rng.nextInt(9),
        );

      // Разряд, поднимающийся от ног агента
      case _BoltType.ground:
        final isLeft = _rng.nextBool();
        final cx = (isLeft ? sovaX : fadeX) + (_rng.nextDouble() - 0.5) * 55;
        final riseH = 55.0 + _rng.nextDouble() * 100;
        return _Bolt(
          path: _zigzag(
            Offset(cx, bodyBottom),
            Offset(cx + (_rng.nextDouble() - 0.5) * 28, bodyBottom - riseH),
            10, 8,
          ),
          color: const Color(0xFFFF4655),
          strokeWidth: 0.65 + _rng.nextDouble() * 0.85,
          totalFrames: 5 + _rng.nextInt(8),
        );

      // Разряд между двумя агентами
      case _BoltType.clash:
        final y = centerY + (_rng.nextDouble() - 0.5) * h * 0.22;
        final x1 = sovaX + 18 + _rng.nextDouble() * 22;
        final x2 = fadeX - 18 - _rng.nextDouble() * 22;
        Path? branch;
        if (_rng.nextDouble() < 0.62) {
          final bx = x1 + (x2 - x1) * (0.33 + _rng.nextDouble() * 0.34);
          branch = _zigzag(
            Offset(bx, y),
            Offset(bx + (_rng.nextDouble() - 0.5) * 55,
                y + 38 + _rng.nextDouble() * 65),
            7, 10,
          );
        }
        return _Bolt(
          path: _zigzag(Offset(x1, y), Offset(x2, y), 16, 24),
          branch: branch,
          color: const Color(0xFF00CFFF),
          strokeWidth: 1.5 + _rng.nextDouble() * 1.3,
          totalFrames: 9 + _rng.nextInt(11),
        );

      // Мелкие искры рядом с телами агентов
      case _BoltType.spark:
        final isLeft = _rng.nextBool();
        final cx = (isLeft ? sovaX : fadeX) + (_rng.nextDouble() - 0.5) * 65;
        final cy = bodyTop + _rng.nextDouble() * (bodyBottom - bodyTop) * 0.88;
        final angle = _rng.nextDouble() * 2 * pi;
        final len = 9.0 + _rng.nextDouble() * 35;
        return _Bolt(
          path: _zigzag(
            Offset(cx, cy),
            Offset(cx + cos(angle) * len, cy + sin(angle) * len),
            4, 7,
          ),
          color: const Color(0xFFAAEEFF),
          strokeWidth: 0.4 + _rng.nextDouble() * 0.55,
          totalFrames: 2 + _rng.nextInt(5),
        );
    }
  }

  // Зубчатая дуга по окружности (для короны)
  Path _arc(Offset center, double r, double startAngle, double endAngle,
      double spread) {
    const steps = 20;
    final p = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + (endAngle - startAngle) * t;
      final jitter =
          (i > 0 && i < steps) ? (_rng.nextDouble() - 0.5) * spread : 0.0;
      final rr = r + jitter;
      final x = center.dx + cos(angle) * rr;
      final y = center.dy + sin(angle) * rr;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p;
  }

  // Зигзаг по перпендикуляру к вектору a→b
  Path _zigzag(Offset a, Offset b, int segs, double spread) {
    final p = Path()..moveTo(a.dx, a.dy);
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return p..lineTo(b.dx, b.dy);
    // Единичный перпендикуляр
    final nx = -dy / len;
    final ny = dx / len;
    for (int i = 1; i < segs; i++) {
      final t = i / segs;
      final off = (_rng.nextDouble() - 0.5) * spread;
      p.lineTo(a.dx + dx * t + nx * off, a.dy + dy * t + ny * off);
    }
    return p..lineTo(b.dx, b.dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return CustomPaint(
          painter: _LightningPainter(bolts: _bolts, repaint: _repaint),
          size: Size.infinite,
        );
      },
    );
  }
}

// ─── Данные молнии ────────────────────────────────────────────────────────────

enum _BoltType { radial, corona, ground, clash, spark }

class _Bolt {
  final Path path;
  final Path? branch;
  final Color color;
  final double strokeWidth;
  int frame = 0;
  final int totalFrames;

  _Bolt({
    required this.path,
    this.branch,
    required this.color,
    required this.strokeWidth,
    required this.totalFrames,
  });

  bool get isDead => frame >= totalFrames;

  // Кривая яркости: быстрое появление, медленное затухание
  double get opacity {
    final t = frame / totalFrames;
    if (t < 0.15) return t / 0.15;
    if (t > 0.62) return (1.0 - t) / 0.38;
    return 1.0;
  }
}

// ─── Рендер молний (4 слоя: внешнее свечение, среднее, основная линия, белое ядро)

class _LightningPainter extends CustomPainter {
  final List<_Bolt> bolts;

  _LightningPainter({required this.bolts, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _drawAuras(canvas, size);
    for (final b in bolts) {
      _draw(canvas, b.path, b.color, b.strokeWidth, b.opacity);
      if (b.branch != null) {
        _draw(canvas, b.branch!, b.color, b.strokeWidth * 0.55, b.opacity * 0.65);
      }
    }
  }

  void _drawAuras(Canvas canvas, Size size) {
    final sovaX = size.width * 0.25;
    final fadeX = size.width * 0.75;
    final auraY = size.height * 0.50;
    final r = size.width * 0.34;
    for (final cx in [sovaX, fadeX]) {
      final center = Offset(cx, auraY);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF0066CC).withValues(alpha: 0.22),
              const Color(0xFF001133).withValues(alpha: 0.09),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  void _draw(Canvas canvas, Path path, Color color, double w, double op) {
    // 1) Широкое внешнее свечение
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: op * 0.25)
        ..strokeWidth = w * 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // 2) Среднее свечение
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: op * 0.55)
        ..strokeWidth = w * 2.2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // 3) Основная линия
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: op)
        ..strokeWidth = w
        ..style = PaintingStyle.stroke,
    );
    // 4) Белое раскалённое ядро
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: op * 0.88)
        ..strokeWidth = w * 0.22
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LightningPainter old) => true;
}

// ─── Прогресс-бар: прямоугольный, без скруглений ─────────────────────────────

class _EnergyBar extends StatelessWidget {
  final double progress;

  static const _accent = Color(0xFFFF4655);
  static const _barBg = Color(0xFF333333);

  const _EnergyBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Container(
          height: 7,
          color: _barBg,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: _accent,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.65),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
