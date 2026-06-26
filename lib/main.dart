import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/constants.dart';
import 'config/map_data.dart';
import 'services/image_cache_service.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';
import 'admin_gate_screen.dart';
import 'submit_lineup_screen.dart';
import 'registration_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'auth_service.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'app_theme.dart';
import 'exclusive_service.dart';
import 'splash_screen.dart';
import 'force_update_service.dart';
import 'changelog_screen.dart';
import 'patches_service.dart';
import 'app_snack_bar.dart';
import 'services/locale_service.dart';
import 'duel_menu_screen.dart';
import 'notification_service.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  OneSignal.initialize(AppConstants.oneSignalAppId);

  await LocaleService.init();
  final themeNotifier = ValueNotifier<AppThemeData>(AppThemes.standard);
  runApp(MyApp(themeNotifier: themeNotifier));
}

class MyApp extends StatefulWidget {
  final ValueNotifier<AppThemeData> themeNotifier;
  const MyApp({super.key, required this.themeNotifier});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void _onSplashComplete({
    required bool registered,
    required bool onboardingShown,
    required bool hasSession,
    String? softUpdateVersion,
  }) {
    NotificationService.navigatorKey.currentState?.pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => AppEntry(
          preRegistered: registered,
          preOnboardingShown: onboardingShown,
          preHasSession: hasSession,
          softUpdateVersion: softUpdateVersion,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeNotifier(
      notifier: widget.themeNotifier,
      child: ValueListenableBuilder<AppThemeData>(
        valueListenable: widget.themeNotifier,
        builder: (context, theme, _) {
          return ValueListenableBuilder<Locale?>(
            valueListenable: LocaleService.localeNotifier,
            builder: (context, locale, _) {
              return MaterialApp(
                navigatorKey: NotificationService.navigatorKey,
                title: 'Valorant Lineups',
                debugShowCheckedModeBanner: false,
                theme: AppThemes.toMaterialTheme(theme),
                locale: locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'),
                  Locale('ru'),
                  Locale('tr'),
                  Locale('es'),
                  Locale('pt'),
                  Locale('ar'),
                  Locale('ko'),
                  Locale('ja'),
                ],
                localeResolutionCallback: (locale, supportedLocales) {
                  for (final supported in supportedLocales) {
                    if (supported.languageCode == locale?.languageCode) {
                      return supported;
                    }
                  }
                  return const Locale('en');
                },
                home: SplashScreen(
                  themeNotifier: widget.themeNotifier,
                  onComplete: _onSplashComplete,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  final bool? preRegistered;
  final bool? preOnboardingShown;
  final bool? preHasSession;
  final String? softUpdateVersion;

  const AppEntry({
    super.key,
    this.preRegistered,
    this.preOnboardingShown,
    this.preHasSession,
    this.softUpdateVersion,
  });

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _checking = true;
  bool _registered = false;
  bool _onboardingShown = false;
  bool _hasActiveSession = false;
  bool _deleted = false;
  bool _showLogin = false;
  int _savedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.preRegistered != null) {
      _registered = widget.preRegistered!;
      _onboardingShown = widget.preOnboardingShown ?? false;
      _hasActiveSession = widget.preHasSession ?? false;
      _loadTabIndex();
    } else {
      _check();
    }
  }

  Future<void> _loadTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt('home_tab_index') ?? 0;
      if (mounted) setState(() { _savedTabIndex = idx; _checking = false; });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _check() async {
    try {
      final registered = await AuthService.isRegistered();
      final shouldShowOnboarding = await OnboardingScreen.shouldShow();
      final hasSession = await AuthService.hasActiveSession();
      final prefs = await SharedPreferences.getInstance();
      final tabIdx = prefs.getInt('home_tab_index') ?? 0;
      if (mounted) {
        setState(() {
          _registered = registered;
          _onboardingShown = !shouldShowOnboarding;
          _hasActiveSession = hasSession;
          _savedTabIndex = tabIdx;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onRegistered() async {
    final shouldShow = await OnboardingScreen.shouldShow();
    if (mounted) {
      setState(() {
        _registered = true;
        _deleted = false;
        _onboardingShown = !shouldShow;
        _hasActiveSession = true;
      });
    }
  }

  void _onOnboardingDone() {
    if (mounted) setState(() => _onboardingShown = true);
  }

  void _onLoggedIn() {
    if (mounted) {
      setState(() {
        _registered = true;
        _onboardingShown = true;
        _hasActiveSession = true;
      });
    }
  }

  void _onCreateAccount() {
    if (mounted) {
      setState(() {
        _registered = false;
        _onboardingShown = false;
      });
    }
  }

  void _onSignedOut() {
    if (mounted) setState(() => _hasActiveSession = false);
  }

  void _onAccountDeleted() {
    if (mounted) {
      setState(() {
        _registered = false;
        _checking = false;
        _deleted = true;
        _hasActiveSession = false;
        _showLogin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    if (_checking) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1923),
        body: Center(
          child: CircularProgressIndicator(color: theme.primary),
        ),
      );
    }

    if (_deleted) {
      return _AccountDeletedScreen(onContinue: () => setState(() => _deleted = false));
    }

    if (!_registered) {
      if (_showLogin) {
        return LoginScreen(
          onLoggedIn: _onLoggedIn,
          onCreateAccount: () => setState(() => _showLogin = false),
          onRegistered: _onRegistered,
        );
      }
      return RegistrationScreen(
        onRegistered: _onRegistered,
        onLoginInstead: () => setState(() => _showLogin = true),
      );
    }

    if (!_onboardingShown) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }

    if (!_hasActiveSession) {
      return LoginScreen(
        onLoggedIn: _onLoggedIn,
        onCreateAccount: _onCreateAccount,
        onRegistered: _onRegistered,
      );
    }

    return HomeScreen(
      onAccountDeleted: _onAccountDeleted,
      onSignedOut: _onSignedOut,
      softUpdateVersion: widget.softUpdateVersion,
      initialTabIndex: _savedTabIndex,
    );
  }
}

class _AccountDeletedScreen extends StatelessWidget {
  final VoidCallback onContinue;
  const _AccountDeletedScreen({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade400, size: 80),
              const SizedBox(height: 24),
              Text(AppLocalizations.of(context)!.accountDeleted,
                  style: TextStyle(color: theme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.accountDeletedDesc,
                  style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(AppLocalizations.of(context)!.mainMenu,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Главный экран с BottomNavigationBar ──────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback onAccountDeleted;
  final VoidCallback onSignedOut;
  final String? softUpdateVersion;
  final int initialTabIndex;
  const HomeScreen({
    super.key,
    required this.onAccountDeleted,
    required this.onSignedOut,
    this.softUpdateVersion,
    this.initialTabIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _writeSession();
    NotificationService.pendingNotificationTap.addListener(_handleNotificationTap);
    final pending = NotificationService.pendingNotificationTap.value;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationTap());
    }
    if (widget.softUpdateVersion != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSoftUpdateBanner(context, widget.softUpdateVersion!),
      );
    }
  }

  @override
  void dispose() {
    NotificationService.pendingNotificationTap.removeListener(_handleNotificationTap);
    super.dispose();
  }

  void _handleNotificationTap() {
    final data = NotificationService.pendingNotificationTap.value;
    if (data == null || !mounted) return;
    NotificationService.pendingNotificationTap.value = null;
    final type = data['type'];
    switch (type) {
      case 'lineup_approved':
      case 'lineup_rejected':
      case 'lineup_liked':
      case 'moderator_approved':
      case 'moderator_rejected':
      case 'feedback_reply':
        setState(() => _selectedIndex = 2); // ProfileScreen
        break;
      case 'changelog':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChangelogScreen()),
        );
        break;
      default:
        break;
    }
  }

  static Future<void> _writeSession() async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return;
      if (AuthService.currentUser?.isAnonymous ?? true) return;
      final now = DateTime.now();
      final date = '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance.collection('user_sessions').add({
        'uid': uid,
        'ts': FieldValue.serverTimestamp(),
        'date': date,
      });
    } catch (_) {}
  }

  void _showSoftUpdateBanner(BuildContext context, String version) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppThemeNotifier.of(context).surface,
        content: Text(
          '🆕 Доступна версия $version — рекомендуем обновить',
          style: TextStyle(color: AppThemeNotifier.of(context).textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              final uri = Uri.parse(ForceUpdateService.playStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(
                  Uri.parse(ForceUpdateService.playStoreFallbackUrl),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: const Text('Обновить',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Позже', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _onTabTapped(int i) async {
    setState(() => _selectedIndex = i);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('home_tab_index', i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              'Выйти из приложения?',
              style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Вы уверены, что хотите выйти?',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Выйти',
                    style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldExit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _MapsTab(
              onAccountDeleted: widget.onAccountDeleted,
              onSignedOut: widget.onSignedOut,
            ),
            const FavoritesScreen(),
            ProfileScreen(
              onAccountDeleted: widget.onAccountDeleted,
              onSignedOut: widget.onSignedOut,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          selectedItemColor: theme.primary,
          unselectedItemColor: theme.textSecondary,
          backgroundColor: theme.surface,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.map_outlined),
              activeIcon: const Icon(Icons.map),
              label: AppLocalizations.of(context)!.tabMaps,
            ),
            BottomNavigationBarItem(
              icon: const _FavoritesNavIcon(),
              label: AppLocalizations.of(context)!.tabFavorites,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: AppLocalizations.of(context)!.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Иконка "Избранное" с зелёным бейджем (непрочитанные ответы) ─────────────

class _FavoritesNavIcon extends StatelessWidget {
  const _FavoritesNavIcon();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) return const Icon(Icons.star_border);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final hasUnread = snap.data?.docs.any((d) {
              final data = d.data() as Map;
              return data['reply'] != null &&
                  (data['reply_read'] == false || data['reply_read'] == null);
            }) ??
            false;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.star_border),
            if (hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Вкладка "Карты" ──────────────────────────────────────────────────────────

class _MapsTab extends StatefulWidget {
  final VoidCallback onAccountDeleted;
  final VoidCallback onSignedOut;
  const _MapsTab({required this.onAccountDeleted, required this.onSignedOut});

  @override
  State<_MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends State<_MapsTab> {
  bool _hasExclusiveAccess = false;
  bool _bannerDismissed = false;
  bool _hasDuelBadge = false;
  late final Future<String?> _patchFuture = PatchesService.getCurrentPatch();
  StreamSubscription<QuerySnapshot>? _duelSub;

  @override
  void initState() {
    super.initState();
    _loadExclusiveAccess();
    ExclusiveService.accessNotifier.addListener(_onAccessChanged);
    _subscribeDuelBadge();
    // Качаем изображения карт на диск пока пользователь на главном экране.
    // downloadFile — только HTTP→диск, без декодирования в GPU, поэтому не лагает.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarmMapImages());
  }

  static Future<void> _prewarmMapImages() async {
    // Фаза 1: splash-изображения для пикера карт (крупные, ~500KB каждый)
    for (final map in MapPickerScreen.allMaps) {
      try {
        await AppImageCache.manager.downloadFile(map['splash']!);
      } catch (_) {}
    }
    // Фаза 2: миниматы для экрана карты (маленькие, ~30KB) — чтобы при открытии
    // карты минимат уже лежал на диске и отображался мгновенно без чёрного экрана
    for (final mapCfg in MapData.all) {
      try {
        await AppImageCache.manager.downloadFile(mapCfg.minimapUrl);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _duelSub?.cancel();
    ExclusiveService.accessNotifier.removeListener(_onAccessChanged);
    super.dispose();
  }

  void _onAccessChanged() => _loadExclusiveAccess();

  void _subscribeDuelBadge() {
    _duelSub = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        if (mounted) setState(() => _hasDuelBadge = false);
        return;
      }
      final createdAt = snap.docs.first.data()['createdAt'];
      int createdMs = 0;
      if (createdAt is Timestamp) createdMs = createdAt.millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('duels_last_seen_at') ?? 0;
      if (mounted) setState(() => _hasDuelBadge = createdMs > lastSeen);
    }, onError: (_) {});
  }

  Future<void> _markDuelsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duels_last_seen_at', DateTime.now().millisecondsSinceEpoch);
    if (mounted) setState(() => _hasDuelBadge = false);
  }

  Future<void> _loadExclusiveAccess() async {
    final has = await ExclusiveService.hasAccess();
    if (mounted) {
      setState(() {
        _hasExclusiveAccess = has;
        if (has) _bannerDismissed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(
          'VALORANT LINEUPS',
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const ChangelogNavIcon(),
            tooltip: AppLocalizations.of(context)!.newsTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangelogScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.admin_panel_settings, color: theme.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminGateScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_main',
        backgroundColor: theme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(AppLocalizations.of(context)!.suggestLineup, style: const TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitLineupScreen()),
        ),
      ),
      body: Column(
        children: [
          // Баннер эксклюзивного доступа
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _hasExclusiveAccess && !_bannerDismissed
                ? _ExclusiveAccessBanner(
                    onClose: () => setState(() => _bannerDismissed = true),
                  )
                : const SizedBox.shrink(),
          ),
          FutureBuilder<String?>(
            future: _patchFuture,
            builder: (_, snap) {
              final patch = snap.data;
              if (patch == null || patch.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: theme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.update, color: theme.textSecondary, size: 14),
                    const SizedBox(width: 6),
                    Text('Патч $patch',
                        style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                _CategoryCard(
                  emoji: '🎯',
                  name: AppLocalizations.of(context)!.categoryLineups,
                  desc: AppLocalizations.of(context)!.categoryLineupsDesc,
                  color: AppThemeNotifier.of(context).primary,
                  locked: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPickerScreen(
                        category: 'lineup',
                        categoryName: AppLocalizations.of(context)!.categoryLineups,
                      ),
                    ),
                  ),
                ),
                _CategoryCard(
                  emoji: '⚡',
                  name: AppLocalizations.of(context)!.categoryCombo,
                  desc: AppLocalizations.of(context)!.categoryComboDesc,
                  color: const Color(0xFFFFA500),
                  locked: true,
                ),
                _CategoryCard(
                  emoji: '💨',
                  name: AppLocalizations.of(context)!.categorySmoky,
                  desc: AppLocalizations.of(context)!.categorySmokyDesc,
                  color: const Color(0xFF9B59B6),
                  locked: true,
                ),
                _CategoryCard(
                  emoji: '🛡',
                  name: AppLocalizations.of(context)!.categoryDefense,
                  desc: AppLocalizations.of(context)!.categoryDefenseDesc,
                  color: const Color(0xFF3498DB),
                  locked: true,
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _CategoryCard(
                      emoji: '⚔️',
                      name: 'Дуэли',
                      desc: 'Голосуй за лучший лайнап',
                      color: AppThemeNotifier.of(context).primary,
                      locked: false,
                      onTap: () {
                        _markDuelsSeen();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DuelMenuScreen()),
                        );
                      },
                    ),
                    if (_hasDuelBadge)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: NewBadge(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Баннер активного эксклюзивного доступа ───────────────────────────────────

class _ExclusiveAccessBanner extends StatelessWidget {
  final VoidCallback onClose;
  const _ExclusiveAccessBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800.withValues(alpha: 0.95), Colors.amber.shade600.withValues(alpha: 0.95)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade400),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.exclusiveAccessActive,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7), size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Бейдж "NEW" с пульсацией ─────────────────────────────────────────────────

class NewBadge extends StatefulWidget {
  const NewBadge({super.key});

  @override
  State<NewBadge> createState() => _NewBadgeState();
}

class _NewBadgeState extends State<NewBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.22).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Карточка категории ────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String desc;
  final Color color;
  final bool locked;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.emoji,
    required this.name,
    required this.desc,
    required this.color,
    this.locked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final effectiveColor = locked ? Colors.grey : color;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: locked ? Colors.grey.withValues(alpha: 0.25) : effectiveColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: effectiveColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: locked ? Colors.grey : effectiveColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          color: locked ? Colors.grey.withValues(alpha: 0.6) : theme.textSecondary,
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (locked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.grey, size: 12),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.comingSoon, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              )
            else
              Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Выбор карты ──────────────────────────────────────────────────────────────

class MapPickerScreen extends StatefulWidget {
  final String category;
  final String categoryName;
  const MapPickerScreen({super.key, required this.category, required this.categoryName});

  // Публичный список — используется для фонового прогрева кэша из _MapsTabState
  static const allMaps = <Map<String, String>>[
    {'name': 'Haven',    'splash': 'https://media.valorant-api.com/maps/2bee0dc9-4ffe-519b-1cbd-7fbe763a6047/splash.png'},
    {'name': 'Bind',     'splash': 'https://media.valorant-api.com/maps/2c9d57ec-4431-9c5e-2939-8f9ef6dd5cba/splash.png'},
    {'name': 'Ascent',   'splash': 'https://media.valorant-api.com/maps/7eaecc1b-4337-bbf6-6ab9-04b8f06b3319/splash.png'},
    {'name': 'Split',    'splash': 'https://media.valorant-api.com/maps/d960549e-485c-e861-8d71-aa9d1aed12a2/splash.png'},
    {'name': 'Icebox',   'splash': 'https://media.valorant-api.com/maps/e2ad5c54-4114-a870-9641-8ea21279579a/splash.png'},
    {'name': 'Breeze',   'splash': 'https://media.valorant-api.com/maps/2fb9a4fd-47b8-4e7d-a969-74b4046ebd53/splash.png'},
    {'name': 'Fracture', 'splash': 'https://media.valorant-api.com/maps/b529448b-4d60-346e-e89e-00a4c527a405/splash.png'},
    {'name': 'Pearl',    'splash': 'https://media.valorant-api.com/maps/fd267378-4d1d-484f-ff52-77821ed10dc2/splash.png'},
    {'name': 'Lotus',    'splash': 'https://media.valorant-api.com/maps/2fe4ed3a-450a-948b-6d6b-e89a78e680a9/splash.png'},
    {'name': 'Sunset',   'splash': 'https://media.valorant-api.com/maps/92584fbe-486a-b1b2-9faa-39b0f486b498/splash.png'},
    {'name': 'Abyss',    'splash': 'https://media.valorant-api.com/maps/224b0a95-48b9-f703-1bd8-67aca101a61f/splash.png'},
    {'name': 'Corrode',  'splash': 'https://media.valorant-api.com/maps/1c18ab1f-420d-0d8b-71d0-77ad3c439115/splash.png'},
    {'name': 'Summit',   'splash': 'https://media.valorant-api.com/maps/756da597-416b-c0f2-f47b-afbdf28670bc/splash.png'},
  ];

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with TickerProviderStateMixin {
  static const _pool = {'Ascent', 'Bind', 'Breeze', 'Haven', 'Lotus', 'Split', 'Summit', 'Sunset'};

  // Вход: 1800ms, stagger 55ms между элементами, каждый элемент занимает 280ms
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  bool _countsLoading = true;
  Map<String, int> _mapLineupCounts = {};
  List<String> _favoriteMaps = [];
  // Кэшированные списки — пересчитываются только при изменении избранного
  late List<Map<String, String>> _rated;
  late List<Map<String, String>> _other;

  void _rebuildLists() {
    final favNames = _favoriteMaps.where((n) => _pool.contains(n)).toList();
    final nonFavs = MapPickerScreen.allMaps
        .where((m) => _pool.contains(m['name']) && !_favoriteMaps.contains(m['name']))
        .toList();
    final favMaps = favNames
        .map((n) => MapPickerScreen.allMaps.firstWhere((m) => m['name'] == n, orElse: () => <String, String>{}))
        .where((m) => m.isNotEmpty)
        .toList();
    _rated = [...favMaps, ...nonFavs];
    _other = MapPickerScreen.allMaps.where((m) => !_pool.contains(m['name'])).toList();
  }

  // globalIndex: порядковый номер элемента на экране (учитывая заголовки секций)
  Animation<double> _itemAnim(int globalIndex) {
    const span = 0.28;
    const stagger = 0.055;
    final start = (globalIndex * stagger).clamp(0.0, 1.0 - span);
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, start + span, curve: Curves.easeOutCubic),
    );
  }

  Widget _fadeSlide(int globalIndex, Widget child) {
    final anim = _itemAnim(globalIndex);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _rebuildLists();
    _loadLineupCounts();
    _loadFavorites();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorite_maps_order');
    if (json != null && mounted) {
      setState(() {
        _favoriteMaps = List<String>.from(jsonDecode(json) as List);
        _rebuildLists();
      });
    }
  }

  Future<void> _toggleFavorite(String name) async {
    final newFavs = List<String>.from(_favoriteMaps);
    if (newFavs.contains(name)) {
      newFavs.remove(name);
    } else {
      newFavs.insert(0, name);
    }
    setState(() {
      _favoriteMaps = newFavs;
      _rebuildLists();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_maps_order', jsonEncode(newFavs));
  }

  Future<void> _loadLineupCounts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lineups')
          .where('status', isEqualTo: 'approved')
          .where('category', isEqualTo: widget.category)
          .limit(500)
          .get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final map = (doc.data()['map'] as String?) ?? '';
        if (map.isNotEmpty) counts[map] = (counts[map] ?? 0) + 1;
      }
      if (mounted) setState(() => _mapLineupCounts = counts);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _countsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(widget.categoryName.toUpperCase(),
            style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, child) => AbsorbPointer(
            absorbing: _entranceCtrl.value < 0.8,
            child: child!,
          ),
          child: CustomScrollView(
          slivers: [
            // globalIndex 0 — заголовок "Рейтинговый пул"
            SliverToBoxAdapter(
              child: _fadeSlide(0, Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.star, color: theme.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.ratingMapPool,
                      style: TextStyle(color: theme.primary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              )),
            ),
            // globalIndex 1.._rated.length — карточки рейтингового пула
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _fadeSlide(index + 1,
                  RepaintBoundary(
                    child: _MapPickerCard(
                      key: ValueKey(_rated[index]['name']),
                      mapData: _rated[index],
                      category: widget.category,
                      lineupCount: _mapLineupCounts[_rated[index]['name']] ?? 0,
                      countsLoading: _countsLoading,
                      isFavorite: _favoriteMaps.contains(_rated[index]['name']),
                      onToggleFavorite: () => _toggleFavorite(_rated[index]['name']!),
                    ),
                  ),
                ),
                childCount: _rated.length,
              ),
            ),
            // globalIndex _rated.length + 1 — заголовок "Другие карты"
            SliverToBoxAdapter(
              child: _fadeSlide(_rated.length + 1, Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: theme.textSecondary, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context)!.otherMaps,
                        style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )),
            ),
            // globalIndex _rated.length + 2.. — карточки других карт
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _fadeSlide(_rated.length + 2 + index,
                  RepaintBoundary(
                    child: _MapPickerCard(
                      key: ValueKey(_other[index]['name']),
                      mapData: _other[index],
                      category: widget.category,
                      lineupCount: _mapLineupCounts[_other[index]['name']] ?? 0,
                      countsLoading: _countsLoading,
                    ),
                  ),
                ),
                childCount: _other.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        ),
        ),
      ),
    );
  }
}

class _MapPickerCard extends StatefulWidget {
  final Map<String, dynamic> mapData;
  final String category;
  final int lineupCount;
  final bool countsLoading;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _MapPickerCard({
    super.key,
    required this.mapData,
    required this.category,
    this.lineupCount = 0,
    this.countsLoading = false,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<_MapPickerCard> createState() => _MapPickerCardState();
}

class _MapPickerCardState extends State<_MapPickerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _starCtrl;
  late final Animation<double> _starScale;

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _starScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    super.dispose();
  }

  void _onStarTap() {
    _starCtrl.forward(from: 0);
    widget.onToggleFavorite?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final isEmpty = !widget.countsLoading && widget.lineupCount == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.countsLoading
                ? null
                : isEmpty
                ? () => AppSnackBar.show(context, AppLocalizations.of(context)!.noLineupsYet)
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(
                          mapName: widget.mapData['name'] as String,
                          mapAsset: 'assets/maps/${widget.mapData['name']}_minimap.png',
                          category: widget.category),
                    ),
                  ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isEmpty ? Colors.grey.withValues(alpha: 0.5) : theme.primary,
                  width: 1,
                ),
                color: theme.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.mapData['splash'] as String,
                      cacheManager: AppImageCache.manager,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => ColoredBox(color: theme.surface2),
                      errorWidget: (context, url, err) => ColoredBox(
                        color: theme.surface2,
                        child: Center(
                          child: Text(
                            widget.mapData['name'] as String,
                            style: TextStyle(color: theme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    // Overlay вместо Opacity + color/colorBlendMode на image —
                    // оба вызывали saveLayer (offscreen render) при каждом кадре скролла
                    ColoredBox(color: Colors.black.withValues(alpha: isEmpty ? 0.55 : 0.15)),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Text(
                          (widget.mapData['name'] as String).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                        ),
                      ),
                      if (widget.onToggleFavorite != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _onStarTap,
                            behavior: HitTestBehavior.opaque,
                            child: ScaleTransition(
                              scale: _starScale,
                              child: Icon(
                                widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                color: widget.isFavorite ? Colors.amber : Colors.white.withValues(alpha: 0.75),
                                size: 22,
                                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ),
        ),
        SizedBox(
          height: 38,
          child: Center(
            child: widget.countsLoading
                ? Container(
                    width: 60,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isEmpty
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppThemeNotifier.of(context).primary.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.lineupCountLabel(widget.lineupCount),
                      style: TextStyle(
                        color: isEmpty
                            ? Colors.white38
                            : AppThemeNotifier.of(context).primary.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

