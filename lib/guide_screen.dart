import 'dart:io';
import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/image_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'ad_service.dart';
import 'favorites_service.dart';
import 'likes_service.dart';
import 'exclusive_service.dart';
import 'user_profile_screen.dart';
import 'auth_service.dart';
import 'collections_screen.dart';
import 'guide_content_service.dart';

class GuideScreen extends StatefulWidget {
  final String lineupId;
  final String title;
  final String description;
  final String ability;
  final String mapName;
  final String agentName;
  final String? videoUrl;
  final List<String> screenshots;
  final String category;
  final bool isExclusive;
  final String? authorName;
  final String? authorId;
  final String? difficulty; // 'easy', 'medium', 'hard'

  const GuideScreen({
    super.key,
    this.lineupId = '',
    required this.title,
    required this.description,
    required this.ability,
    required this.mapName,
    required this.agentName,
    this.videoUrl,
    this.screenshots = const [],
    this.category = '',
    this.isExclusive = false,
    this.authorName,
    this.authorId,
    this.difficulty,
  });

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> with WidgetsBindingObserver {
  // Плеер
  VideoPlayerController? _controller;
  bool _playerReady = false;
  bool _playerError = false;

  // Кэш (только для не-YouTube видео)
  bool _isCached = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // Обычная реклама (сохранить оффлайн)
  bool _adLoading = false;
  bool _showThankYou = false;

  // Эксклюзивный доступ
  bool? _hasAccess; // null = loading, true/false = result
  bool _exclusiveAdLoading = false;

  // Репутация / патч
  String? _patchVersion;
  int _repUp = 0;
  int _repDown = 0;
  bool _isOutdated = false;
  bool? _myVote; // true = up, false = down, null = not voted
  bool _voteLoading = false;

  // Подписки
  bool _isSubscribed = false;

  // Актуальное имя автора из Firestore
  String? _actualAuthorName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isExclusive) {
      _checkAccess();
    } else {
      _maybeInitPlayer();
    }
    _checkVideoAvailability();
    _loadAuthorName();
    if (widget.lineupId.isNotEmpty) {
      _loadReputationData();
      _logLineupView();
    }
    if (widget.agentName.isNotEmpty && widget.mapName.isNotEmpty) {
      _checkSubscription();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isExclusive) {
      _checkAccess();
    }
  }

  // ─── Analytics ────────────────────────────────────────────────────────────

  Future<void> _logLineupView() async {
    final uid = AuthService.userId;
    final db = FirebaseFirestore.instance;
    final futures = <Future>[
      db.collection('lineups').doc(widget.lineupId).update({
        'views_count': FieldValue.increment(1),
      }).catchError((Object _) {}),
    ];

    if (uid != null) {
      futures.add(
        db.collection('analytics_events').add({
          'type': 'lineup_viewed',
          'lineup_id': widget.lineupId,
          'agent': widget.agentName,
          'map': widget.mapName,
          'ability': widget.ability,
          'uid': uid,
          'ts': FieldValue.serverTimestamp(),
        }).then((_) {}).catchError((Object _) {}),
      );
    }

    await Future.wait(futures);
  }

  // ─── Автор ────────────────────────────────────────────────────────────────

  Future<void> _loadAuthorName() async {
    final uid = widget.authorId;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _actualAuthorName = name);
      }
    } catch (_) {}
  }

  // ─── Репутация / патч ─────────────────────────────────────────────────────

  Future<void> _loadReputationData() async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = _currentUid();

      final futures = <Future>[
        db.collection('lineups').doc(widget.lineupId).get(),
        if (uid != null)
          db
              .collection('lineups')
              .doc(widget.lineupId)
              .collection('votes')
              .doc(uid)
              .get(),
      ];
      final results = await Future.wait(futures);

      final snap = results[0] as DocumentSnapshot;
      final data = snap.data() as Map<String, dynamic>? ?? {};

      bool? myVote;
      if (uid != null && results.length > 1) {
        final voteSnap = results[1] as DocumentSnapshot;
        if (voteSnap.exists) {
          myVote = (voteSnap.data() as Map<String, dynamic>?)?['vote'] as bool?;
        }
      }

      if (!mounted) return;
      setState(() {
        _patchVersion = data['patch_version'] as String?;
        _repUp = (data['votes_actual'] as int?) ?? (data['reputation_up'] as int?) ?? 0;
        _repDown = (data['votes_outdated'] as int?) ?? (data['reputation_down'] as int?) ?? 0;
        _isOutdated = (data['is_outdated'] as bool?) ?? false;
        _myVote = myVote;
      });
    } catch (_) {}
  }

  String? _currentUid() => AuthService.userId;

  Future<void> _castVote(bool isUp) async {
    if (_voteLoading) return;
    final uid = _currentUid();
    if (uid == null) {
      setState(() => _voteLoading = false);
      _showVoteLockedDialog(false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final level = (userDoc.data()?['level'] as int?) ?? 1;
    if (level < 2) {
      if (mounted) _showVoteLockedDialog(true);
      return;
    }

    setState(() => _voteLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final voteRef = db
          .collection('lineups')
          .doc(widget.lineupId)
          .collection('votes')
          .doc(uid);
      final lineupRef = db.collection('lineups').doc(widget.lineupId);

      final prevVote = _myVote;

      if (prevVote == isUp) {
        // Снимаем голос
        await voteRef.delete();
        await lineupRef.update({
          isUp ? 'votes_actual' : 'votes_outdated': FieldValue.increment(-1),
        });
        if (mounted) setState(() { _myVote = null; isUp ? _repUp-- : _repDown--; });
      } else {
        // Ставим или меняем голос
        await voteRef.set({'vote': isUp, 'voted_at': FieldValue.serverTimestamp()});
        final batch = db.batch();
        batch.update(lineupRef, {
          isUp ? 'votes_actual' : 'votes_outdated': FieldValue.increment(1),
        });
        if (prevVote != null) {
          batch.update(lineupRef, {
            !isUp ? 'votes_actual' : 'votes_outdated': FieldValue.increment(-1),
          });
        }
        await batch.commit();
        if (mounted) {
          setState(() {
            if (prevVote != null) { prevVote ? _repUp-- : _repDown--; }
            isUp ? _repUp++ : _repDown++;
            _myVote = isUp;
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _voteLoading = false);
    }
  }

  void _showVoteLockedDialog(bool hasLowLevel) {
    final t = AppThemeNotifier.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Text('🔒 ', style: TextStyle(fontSize: 20)),
          Text(hasLowLevel ? AppLocalizations.of(ctx)!.needLevel2 : AppLocalizations.of(ctx)!.loginRequired,
              style: TextStyle(color: t.textPrimary, fontSize: 16)),
        ]),
        content: hasLowLevel
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(ctx)!.votingFromLevel2,
                    style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showLevelUpInfoSheet();
                    },
                    child: Text(
                      AppLocalizations.of(ctx)!.howToGetLevel2,
                      style: TextStyle(
                        color: t.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: t.primary,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                AppLocalizations.of(ctx)!.loginToVote,
                style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.5),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel, style: TextStyle(color: t.textSecondary)),
          ),
          if (hasLowLevel)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _watchAdForVote();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text(AppLocalizations.of(ctx)!.watchAd, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _showLevelUpInfoSheet() {
    final t = AppThemeNotifier.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _GuideContentSheet(theme: t),
    );
  }



  Future<void> _watchAdForVote() async {
    final uid = _currentUid();
    if (uid == null) return;

    // Защита от двойного голоса — проверяем до показа рекламы
    try {
      final voteDoc = await FirebaseFirestore.instance
          .collection('lineups')
          .doc(widget.lineupId)
          .collection('votes')
          .doc(uid)
          .get();
      if (voteDoc.exists && mounted) {
        AppSnackBar.show(context, AppLocalizations.of(context)!.alreadyVoted, type: SnackBarType.warning);
        return;
      }
    } catch (_) {}

    if (!AdService.isRewardedReady) {
      if (mounted) {
        AppSnackBar.show(context, AppLocalizations.of(context)!.adLoading, type: SnackBarType.warning);
      }
      return;
    }
    AdService.showRewarded(
      onRewarded: () async {
        if (uid.isEmpty || !mounted) return;
        final db = FirebaseFirestore.instance;
        final voteRef = db
            .collection('lineups')
            .doc(widget.lineupId)
            .collection('votes')
            .doc(uid);
        final lineupRef = db.collection('lineups').doc(widget.lineupId);
        final vote = await _askVoteDirection();
        if (vote == null || !mounted) return;
        try {
          await voteRef.set({'vote': vote, 'voted_at': FieldValue.serverTimestamp()});
          await lineupRef.update({
            vote ? 'votes_actual' : 'votes_outdated': FieldValue.increment(1),
          });
          if (mounted) {
            setState(() { vote ? _repUp++ : _repDown++; _myVote = vote; });
            AppSnackBar.show(context, AppLocalizations.of(context)!.voteAccepted, type: SnackBarType.success);
          }
        } catch (e) {
          debugPrint('[Vote] onRewarded error: $e');
          if (mounted) {
            AppSnackBar.show(context, AppLocalizations.of(context)!.voteSaveError, type: SnackBarType.error);
          }
        }
      },
      onDismissed: () {
        if (mounted) {
          AppSnackBar.show(context, AppLocalizations.of(context)!.watchAdFull, type: SnackBarType.error);
        }
      },
      onNotReady: () {
        if (mounted) {
          AppSnackBar.show(context, AppLocalizations.of(context)!.adUnavailable, type: SnackBarType.warning);
        }
      },
    );
  }

  Future<bool?> _askVoteDirection() async {
    final t = AppThemeNotifier.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(AppLocalizations.of(ctx)!.yourVote, style: TextStyle(color: t.textPrimary)),
        content: Text(AppLocalizations.of(ctx)!.isLineupRelevant, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.thumb_down, color: Colors.red),
            label: Text(AppLocalizations.of(ctx)!.outdated, style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.thumb_up, color: Colors.white),
            label: Text(AppLocalizations.of(ctx)!.relevant, style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  // ─── Подписки ─────────────────────────────────────────────────────────────

  String get _subId =>
      '${widget.agentName}_${widget.mapName}'.replaceAll(' ', '_').toLowerCase();

  Future<void> _checkSubscription() async {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('subscriptions').doc(_subId)
          .get();
      if (mounted) setState(() => _isSubscribed = snap.exists);
    } catch (_) {}
  }

  Future<void> _toggleSubscription() async {
    final uid = _currentUid();
    if (uid == null) {
      AppSnackBar.show(context, AppLocalizations.of(context)!.loginRequired);
      return;
    }
    final subRef = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('subscriptions').doc(_subId);
    try {
      if (_isSubscribed) {
        await subRef.delete();
        if (mounted) setState(() => _isSubscribed = false);
      } else {
        await subRef.set({
          'type': 'agent_map',
          'agent': widget.agentName,
          'map': widget.mapName,
          'created_at': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _isSubscribed = true);
      }
    } catch (_) {}
  }

  void _openAuthorProfile() {
    final uid = widget.authorId;
    if (uid == null || uid.isEmpty) {
      AppSnackBar.show(context, AppLocalizations.of(context)!.authorProfileUnavailable);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          uid: uid,
          name: _actualAuthorName ?? widget.authorName ?? '',
        ),
      ),
    );
  }

  // ─── Проверка эксклюзивного доступа ─────────────────────────────────────

  Future<void> _checkAccess() async {
    final has = await ExclusiveService.hasAccess();
    if (!mounted) return;
    setState(() {
      _hasAccess = has;
    });
    if (has) _maybeInitPlayer();
  }

  void _watchAdForExclusiveAccess() {
    if (_exclusiveAdLoading) return;

    if (!AdService.isRewardedReady) {
      AppSnackBar.show(context, AppLocalizations.of(context)!.adLoading, type: SnackBarType.warning);
      return;
    }

    setState(() => _exclusiveAdLoading = true);

    AdService.showRewarded(
      onRewarded: () async {
        await ExclusiveService.grantAccess();
        if (!mounted) return;
        setState(() {
          _exclusiveAdLoading = false;
          _hasAccess = true;
          _showThankYou = true;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showThankYou = false);
        });
        _maybeInitPlayer();
      },
      onDismissed: () {
        if (!mounted) return;
        setState(() => _exclusiveAdLoading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.watchAdForAccess, type: SnackBarType.error);
      },
      onNotReady: () {
        if (!mounted) return;
        setState(() => _exclusiveAdLoading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.adUnavailable, type: SnackBarType.warning);
      },
    );
  }

  // ─── Определение типа видео и инициализация плеера ───────────────────────

  void _maybeInitPlayer() {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;
    if (_isYoutubeUrl(url)) {
      _initYoutubePlayer(url);
    } else {
      _checkCache();
    }
  }

  static bool _isYoutubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.replaceFirst('www.', '');
    return host == 'youtu.be' || host == 'youtube.com'; // cspell:ignore youtu
  }

  Future<void> _initYoutubePlayer(String url) async {
    try {
      final yt = YoutubeExplode();
      final videoId = VideoId(url);
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();
      final streamUrl = streamInfo.url.toString();
      yt.close();
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      _setupController(ctrl);
    } catch (_) {
      if (mounted) setState(() => _playerError = true);
    }
  }

  // ─── Фоновая проверка доступности YouTube видео ───────────────────────────

  Future<void> _checkVideoAvailability() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty || widget.lineupId.isEmpty) return;
    if (!_isYoutubeUrl(url)) return;

    try {
      final encoded = Uri.encodeComponent(url);
      final response = await http
          .get(Uri.parse(
              'https://www.youtube.com/oembed?url=$encoded&format=json'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        await FirebaseFirestore.instance
            .collection('lineups')
            .doc(widget.lineupId)
            .update({'status': 'removed'});
      }
    } catch (_) {}
  }

  // ─── Кэш (для не-YouTube видео) ───────────────────────────────────────────

  String get _cacheFileName {
    final uri = Uri.tryParse(widget.videoUrl ?? '');
    final segments = uri?.pathSegments ?? [];
    final name = segments.isNotEmpty ? segments.last : 'video';
    return name.split('?').first.replaceAll(RegExp(r'[^\w.]'), '_');
  }

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/cached_videos');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return File('${cacheDir.path}/$_cacheFileName');
  }

  Future<void> _checkCache() async {
    final file = await _getCacheFile();
    final cached = await file.exists();
    if (!mounted) return;
    if (cached) {
      setState(() => _isCached = true);
      _initPlayerFromFile(file);
    } else {
      _initPlayerFromNetwork();
    }
  }

  void _initPlayerFromNetwork() {
    if (widget.videoUrl == null) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
    _setupController(ctrl);
  }

  void _initPlayerFromFile(File file) {
    final ctrl = VideoPlayerController.file(file);
    _setupController(ctrl);
  }

  void _setupController(VideoPlayerController ctrl) {
    ctrl.initialize().then((_) {
      if (!mounted) { ctrl.dispose(); return; }
      ctrl.play();
      setState(() { _controller = ctrl; _playerReady = true; });
    }).catchError((_) {
      if (mounted) setState(() => _playerError = true);
    });
  }

  // ─── Rewarded → скачать оффлайн ───────────────────────────────────────────

  void _downloadWithAd() {
    if (_adLoading || _isDownloading) return;
    if (!AdService.isRewardedReady) {
      AppSnackBar.show(context, AppLocalizations.of(context)!.adLoading, type: SnackBarType.warning);
      return;
    }
    setState(() => _adLoading = true);
    AdService.showRewarded(
      onRewarded: () async {
        if (!mounted) return;
        setState(() { _adLoading = false; _showThankYou = true; });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showThankYou = false);
        });
        await _downloadVideo();
      },
      onDismissed: () {
        if (!mounted) return;
        setState(() => _adLoading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.watchAdForSave, type: SnackBarType.error);
      },
      onNotReady: () {
        if (!mounted) return;
        setState(() => _adLoading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.adUnavailable, type: SnackBarType.warning);
      },
    );
  }

  Future<void> _downloadVideo() async {
    if (widget.videoUrl == null) return;
    setState(() { _isDownloading = true; _downloadProgress = 0; });
    try {
      final cacheFile = await _getCacheFile();
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.videoUrl!));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int received = 0;
      final sink = cacheFile.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && mounted) setState(() => _downloadProgress = received / totalBytes);
      }).asFuture();
      await sink.flush();
      await sink.close();
      client.close();
      if (!mounted) return;
      await _controller?.dispose();
      _controller = null;
      if (!mounted) return;
      setState(() { _isCached = true; _isDownloading = false; _downloadProgress = 1.0; _playerReady = false; });
      _initPlayerFromFile(cacheFile);
      AppSnackBar.show(context, AppLocalizations.of(context)!.videoSavedSuccess, type: SnackBarType.success);
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.downloadError, type: SnackBarType.error);
      }
    }
  }

  Future<void> _deleteCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) await file.delete();
      await _controller?.dispose();
      _controller = null;
      setState(() { _isCached = false; _playerReady = false; });
      _initPlayerFromNetwork();
    } catch (_) {}
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppThemeData t) {
    return AppBar(
      backgroundColor: t.surface,
      title: Text(widget.title.toUpperCase(),
          style: TextStyle(color: t.primary, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
      centerTitle: true,
      iconTheme: IconThemeData(color: t.primary),
      actions: [
        if (widget.agentName.isNotEmpty && widget.mapName.isNotEmpty)
          IconButton(
            icon: Icon(
              _isSubscribed ? Icons.notifications_active : Icons.notifications_none,
              color: _isSubscribed ? t.primary : t.textSecondary,
            ),
            onPressed: _toggleSubscription,
            tooltip: 'Уведомления о новых лайнапах',
          ),
        if (widget.lineupId.isNotEmpty) ...[
          IconButton(
            icon: Icon(Icons.playlist_add, color: t.textSecondary),
            tooltip: AppLocalizations.of(context)!.addToCollection,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddToCollectionDialog(lineupId: widget.lineupId),
            ),
          ),
          StreamBuilder<bool>(
            stream: FavoritesService.isFavorite(widget.lineupId),
            builder: (context, snap) {
              final saved = snap.data ?? false;
              return IconButton(
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                    color: saved ? t.primary : t.textSecondary),
                onPressed: () => FavoritesService.toggleFavorite(widget.lineupId),
                tooltip: saved ? AppLocalizations.of(context)!.removeFromFavorites : AppLocalizations.of(context)!.addToFavorites,
              );
            },
          ),
        ],
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    // Эксклюзив: загрузка
    if (widget.isExclusive && _hasAccess == null) {
      return Scaffold(
        backgroundColor: t.background,
        appBar: _buildAppBar(t),
        body: Center(child: CircularProgressIndicator(color: t.primary)),
      );
    }

    // Эксклюзив: нет доступа
    if (widget.isExclusive && _hasAccess == false) {
      return Scaffold(
        backgroundColor: t.background,
        appBar: _buildAppBar(t),
        body: _buildLockedScreen(t),
      );
    }

    // Нормальный экран (+ эксклюзив с доступом)
    return Scaffold(
      backgroundColor: t.background,
      appBar: _buildAppBar(t),
      body: Column(
        children: [
          // Баннер эксклюзивного доступа (счётчик просмотров)
          if (widget.isExclusive && _hasAccess == true)
            const _ExclusiveViewsBanner(),

          // Баннер "Спасибо"
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: _showThankYou
                ? _ThankYouBanner(theme: t, onClose: () => setState(() => _showThankYou = false))
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      _tag(widget.mapName, t),
                      _tag(widget.agentName, t),
                      _tag(widget.ability.toUpperCase(), t, highlight: true),
                      if (widget.isExclusive)
                        _tag('⭐ ЭКСКЛЮЗИВ', t, highlight: true, color: Colors.amber),
                      if (_patchVersion != null && _patchVersion!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: t.border),
                          ),
                          child: Text(
                            'Патч $_patchVersion',
                            style: TextStyle(color: t.textSecondary, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  if (widget.authorId != null && widget.authorId!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _openAuthorProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: t.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: (_actualAuthorName ?? widget.authorName ?? '').isNotEmpty
                                  ? Text(
                                      (_actualAuthorName ?? widget.authorName ?? '')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const Icon(Icons.person, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.lineupFrom,
                                style: TextStyle(color: t.textSecondary, fontSize: 11),
                              ),
                              Text(
                                _actualAuthorName ?? widget.authorName ?? '',
                                style: TextStyle(
                                  color: t.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: t.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  _buildVideoBlock(t),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(AppLocalizations.of(context)!.description,
                          style: TextStyle(color: t.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      if (widget.difficulty != null) ...[
                        const SizedBox(width: 10),
                        _DifficultyBadge(difficulty: widget.difficulty!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: t.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
                    child: Text(widget.description,
                        style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(height: 20),
                  if (widget.screenshots.isNotEmpty) ...[
                    Text(AppLocalizations.of(context)!.screenshots,
                        style: TextStyle(color: t.primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.6),
                      itemCount: widget.screenshots.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _PhotoViewerScreen(
                              urls: widget.screenshots,
                              initialIndex: i,
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                              imageUrl: widget.screenshots[i], cacheManager: AppImageCache.manager, fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: Colors.transparent),
                              errorWidget: (_, _, _) => _screenshotPlaceholder(i + 1, t)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Репутация: предупреждение об устаревании
          if (_isOutdated || _repDown > _repUp * 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.possiblyOutdated,
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Репутация: голосование + патч
          if (widget.lineupId.isNotEmpty)
            Container(
              color: t.surface,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Column(
                children: [
                  if (_patchVersion != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.update, size: 13, color: t.textSecondary),
                          const SizedBox(width: 4),
                          Text(AppLocalizations.of(context)!.patchVersion(_patchVersion!),
                              style: TextStyle(color: t.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.isRelevant,
                          style: TextStyle(color: t.textSecondary, fontSize: 12)),
                      _VoteButton(
                        icon: Icons.thumb_up_outlined,
                        activeIcon: Icons.thumb_up,
                        count: _repUp,
                        isActive: _myVote == true,
                        color: Colors.green,
                        loading: _voteLoading,
                        onTap: () => _castVote(true),
                        theme: t,
                      ),
                      const SizedBox(width: 12),
                      _VoteButton(
                        icon: Icons.thumb_down_outlined,
                        activeIcon: Icons.thumb_down,
                        count: _repDown,
                        isActive: _myVote == false,
                        color: Colors.red,
                        loading: _voteLoading,
                        onTap: () => _castVote(false),
                        theme: t,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Кнопка лайка
          if (widget.lineupId.isNotEmpty)
            Container(
              color: t.surface,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LineupLikeButton(
                    lineupId: widget.lineupId,
                    isExclusive: widget.isExclusive,
                    hasAccess: _hasAccess,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Заблокированный экран ────────────────────────────────────────────────

  Widget _buildLockedScreen(AppThemeData t) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          child: _showThankYou
              ? _ThankYouBanner(theme: t, onClose: () => setState(() => _showThankYou = false))
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('👑', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.exclusiveLineup,
                    style: TextStyle(color: t.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.watchAdForExclusive,
                    style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_exclusiveAdLoading)
                    CircularProgressIndicator(color: t.primary)
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _watchAdForExclusiveAccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.watchAdAccessBtn,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Видео блок ───────────────────────────────────────────────────────────

  Widget _buildVideoBlock(AppThemeData t) {
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) return _noVideoBlock(t);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isCached ? Colors.green : t.primary, width: _isCached ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _playerError
                  ? _playerErrorWidget(t)
                  : !_playerReady
                      ? _playerLoading(t)
                      : _VideoPlayerWidget(controller: _controller!),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_isCached ? Icons.offline_pin : Icons.cloud_outlined,
                        color: _isCached ? Colors.green : t.textSecondary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _isCached ? AppLocalizations.of(context)!.savedOffline : AppLocalizations.of(context)!.onlineOnly,
                      style: TextStyle(color: _isCached ? Colors.green : t.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: _downloadProgress, backgroundColor: t.border,
                        valueColor: AlwaysStoppedAnimation<Color>(t.primary), minHeight: 6),
                  ),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context)!.downloadingPercent((_downloadProgress * 100).toStringAsFixed(0)),
                      style: TextStyle(color: t.textSecondary, fontSize: 11)),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (!_isCached)
                      Expanded(child: _adLoading || _isDownloading ? _loadingBtn(t) : _saveBtn(t))
                    else ...[
                      Expanded(child: _savedIndicator(t)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _deleteCache,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBtn(AppThemeData t) {
    return GestureDetector(
      onTap: _downloadWithAd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.saveOffline,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
              child: Text(AppLocalizations.of(context)!.adLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBtn(AppThemeData t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)),
          const SizedBox(width: 10),
          Text(_adLoading ? AppLocalizations.of(context)!.loadingAd : AppLocalizations.of(context)!.savingVideo,
              style: TextStyle(color: t.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _savedIndicator(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.videoSaved,
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _playerLoading(AppThemeData t) {
    return Container(color: Colors.black, child: Center(child: CircularProgressIndicator(color: t.primary)));
  }

  Widget _playerErrorWidget(AppThemeData t) {
    return Container(
      color: t.surface2,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: t.textSecondary, size: 36),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.videoLoadError, style: TextStyle(color: t.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _noVideoBlock(AppThemeData t) {
    return Container(
      width: double.infinity, height: 140,
      decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: t.textSecondary, size: 40),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.videoComingSoon, style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ─── Вспомогательные ─────────────────────────────────────────────────────

  Widget _tag(String text, AppThemeData t, {bool highlight = false, Color? color}) {
    final c = color ?? t.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? c.withValues(alpha: 0.2) : t.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: highlight ? c : t.border),
      ),
      child: Text(text,
          style: TextStyle(
            color: highlight ? c : t.textSecondary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          )),
    );
  }

  Widget _screenshotPlaceholder(int n, AppThemeData t) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: t.border, size: 28),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.screenshotN(n), style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Таймер эксклюзивного доступа ────────────────────────────────────────────

class _ExclusiveViewsBanner extends StatelessWidget {
  const _ExclusiveViewsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.exclusiveTag,
            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Виджет плеера с управлением ─────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoPlayerWidget({required this.controller});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  bool _showControls = false;
  int  _loopCount   = 0;
  bool _seekPending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    final ctrl = widget.controller;
    final pos  = ctrl.value.position;
    final dur  = ctrl.value.duration;
    if (!_seekPending && dur > Duration.zero && pos >= dur && !ctrl.value.isPlaying) {
      if (_loopCount < 2) {
        _loopCount++;
        _seekPending = true;
        ctrl.seekTo(Duration.zero).then((_) {
          _seekPending = false;
          ctrl.play();
        });
      } else {
        _loopCount = 0;
      }
    }
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    setState(() => _showControls = true);
    if (widget.controller.value.isPlaying) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    final isPlaying = ctrl.value.isPlaying;

    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && ctrl.value.isPlaying) setState(() => _showControls = false);
          });
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black, child: VideoPlayer(ctrl)),
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                          child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      children: [
                        VideoProgressIndicator(ctrl, allowScrubbing: true,
                            colors: const VideoProgressColors(
                                playedColor: Color(0xFFFF4655),
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white12),
                            padding: EdgeInsets.zero),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(_fmtDuration(position),
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            const Spacer(),
                            Text(_fmtDuration(duration),
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _VideoFullscreenScreen(controller: ctrl),
                                ),
                              ),
                              child: const Icon(Icons.fullscreen, color: Colors.white70, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Бейдж сложности ─────────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  static const _colors = {
    'easy':   0xFF22c55e,
    'medium': 0xFFf59e0b,
    'hard':   0xFFef4444,
  };

  @override
  Widget build(BuildContext context) {
    final colorVal = _colors[difficulty];
    if (colorVal == null) return const SizedBox.shrink();
    final color = Color(colorVal);
    final l10n = AppLocalizations.of(context)!;
    final label = switch (difficulty) {
      'easy' => l10n.difficultyEasy,
      'medium' => l10n.difficultyMedium,
      'hard' => l10n.difficultyHard,
      _ => difficulty,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Полноэкранный просмотр фото ─────────────────────────────────────────────

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewerScreen({required this.urls, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1} / ${widget.urls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.urls[i],
              cacheManager: AppImageCache.manager,
              fit: BoxFit.contain,
              placeholder: (_, _) => Container(color: Colors.transparent),
              errorWidget: (_, _, _) =>
                  const Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Кнопка лайка с TikTok-анимацией ─────────────────────────────────────────

class _LineupLikeButton extends StatefulWidget {
  final String lineupId;
  final bool isExclusive;
  final bool? hasAccess;

  const _LineupLikeButton({
    required this.lineupId,
    required this.isExclusive,
    this.hasAccess,
  });

  @override
  State<_LineupLikeButton> createState() => _LineupLikeButtonState();
}

class _LineupLikeButtonState extends State<_LineupLikeButton> with TickerProviderStateMixin {
  bool? _liked;
  int _count = 0;
  bool _loading = false;
  bool _showFloat = false;

  late final AnimationController _scaleCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _floatOffset;
  late final Animation<double> _floatOpacity;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.85), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _floatOffset = Tween(begin: 0.0, end: -36.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeOut));
    _floatOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_floatCtrl);

    _floatCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showFloat = false);
        _floatCtrl.reset();
      }
    });

    LikesService.isLiked(widget.lineupId).first.then((v) {
      if (mounted) setState(() => _liked = v);
    });
    LikesService.getLikesCount(widget.lineupId).first.then((v) {
      if (mounted) setState(() => _count = v);
    });
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _doToggle() async {
    if (_loading) return;
    final wasLiked = _liked ?? false;
    setState(() {
      _liked = !wasLiked;
      _count += wasLiked ? -1 : 1;
      _loading = true;
      if (!wasLiked) _showFloat = true;
    });
    _scaleCtrl.forward(from: 0);
    if (!wasLiked) _floatCtrl.forward(from: 0);
    try {
      await LikesService.toggleLike(widget.lineupId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _count += wasLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    final liked = _liked ?? false;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (widget.isExclusive && widget.hasAccess != true) {
              AppSnackBar.show(
                context,
                AppLocalizations.of(context)!.needExclusiveForLike,
                type: SnackBarType.warning,
              );
              return;
            }
            _doToggle();
          },
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: liked ? t.primary.withValues(alpha: 0.15) : t.surface2,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: liked ? t.primary : t.border,
                  width: liked ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      key: ValueKey(liked),
                      color: liked ? t.primary : t.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      '$_count',
                      key: ValueKey(_count),
                      style: TextStyle(
                        color: liked ? t.primary : t.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showFloat)
          Positioned(
            top: -38,
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, _) => Opacity(
                opacity: _floatOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _floatOffset.value),
                  child: Text(
                    '+1',
                    style: TextStyle(
                      color: t.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Полноэкранный плеер ──────────────────────────────────────────────────────

class _VideoFullscreenScreen extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoFullscreenScreen({required this.controller});

  @override
  State<_VideoFullscreenScreen> createState() => _VideoFullscreenScreenState();
}

class _VideoFullscreenScreenState extends State<_VideoFullscreenScreen> {
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _update() { if (mounted) setState(() {}); }

  void _togglePlay() {
    final ctrl = widget.controller;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    setState(() => _showControls = true);
    if (!ctrl.value.isPlaying) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl     = widget.controller;
    final position = ctrl.value.position;
    final duration = ctrl.value.duration;
    final isPlaying = ctrl.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && ctrl.value.isPlaying) setState(() => _showControls = false);
            });
          }
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.isInitialized ? ctrl.value.aspectRatio : 16 / 9,
                child: VideoPlayer(ctrl),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black45,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      child: Column(
                        children: [
                          VideoProgressIndicator(ctrl, allowScrubbing: true,
                              colors: const VideoProgressColors(
                                  playedColor: Color(0xFFFF4655),
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12),
                              padding: EdgeInsets.zero),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(_fmt(position),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              const Spacer(),
                              Text(_fmt(duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8, left: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Баннер "Спасибо" ─────────────────────────────────────────────────────────

class _ThankYouBanner extends StatelessWidget {
  final AppThemeData theme;
  final VoidCallback onClose;
  const _ThankYouBanner({required this.theme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800.withValues(alpha: 0.9), Colors.green.shade600.withValues(alpha: 0.9)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade400),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Text('🙏', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.thanksForAd,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(AppLocalizations.of(context)!.adHelpsUs,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
              ],
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

// ─── Боттом-шит с гайдом из Firestore ────────────────────────────────────────

class _GuideContentSheet extends StatefulWidget {
  final AppThemeData theme;
  const _GuideContentSheet({required this.theme});

  @override
  State<_GuideContentSheet> createState() => _GuideContentSheetState();
}

class _GuideContentSheetState extends State<_GuideContentSheet> {
  static const _categoryKeys = ['molly', 'reveal', 'smoke'];
  List<String> get _fallbackTabs {
    final l10n = AppLocalizations.of(context)!;
    return [l10n.tabMolly, l10n.tabReveal, l10n.tabSmoky];
  }

  final List<Map<String, dynamic>?> _data = [null, null, null];
  final List<bool> _loaded = [false, false, false];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadTab(0);
  }

  Future<void> _loadTab(int i) async {
    if (_loaded[i]) return;
    final data = await GuideContentService.getCategory(_categoryKeys[i]);
    if (mounted) setState(() { _data[i] = data; _loaded[i] = true; });
  }

  AppThemeData get t => widget.theme;

  String _tabName(int i) => (_data[i]?['title'] as String?) ?? _fallbackTabs[i];
  String _tabIcon(int i) => (_data[i]?['icon'] as String?) ?? '';

  List<String> _list(int i, String key) =>
      List<String>.from(_data[i]?[key] as List? ?? []);

  // Статичный fallback для шагов
  static final _fallbackSteps = [
    [
      ('Покажи спайк', 'Камера на спайке — зритель должен понять, где он стоит.'),
      ('Откуда бросать', 'Встань в точку броска и дай зрителю осмотреться.'),
      ('Куда целиться', 'Прицелься маршалом — точка прицела должна быть чётко видна.'),
      ('Бросок + полёт', 'Выполни бросок и лети камерой за снарядом, показывая траекторию.'),
      ('Место приземления', 'Крупный план — покажи куда упал снаряд.'),
    ],
    [
      ('Откуда активировать', 'Встань в точку броска / установки и дай зрителю осмотреться.'),
      ('Куда целиться', 'Прицелься маршалом — точка прицела должна быть чётко видна.'),
      ('Активация + полёт', 'Выполни способность и лети камерой за снарядом.'),
      ('Зона ревила', 'Покажи, какую область закрывает способность и что там выявлено.'),
    ],
    [
      ('Позиция', 'Встань туда, откуда выставляются дымы, и осмотрись.'),
      ('Прицел на каждый дым', 'Для каждого дыма наведись маршалом / через интерфейс на целевую точку.'),
      ('Выставь дымы', 'Покажи как они расставляются — без лишних движений.'),
      ('Результат', 'Покажи закрытые линии обзора: вид с атаки и с защиты.'),
    ],
  ];

  static final _fallbackTimings = [
    ['Длина видео — не более 20 секунд.', 'В начале записи — без пауз, сразу к делу.', 'Паузы только на: позицию, прицел, бросок, приземление.', 'Без Alt+Tab во время записи.'],
    ['Длина видео — не более 20 секунд.', 'В начале записи — без пауз, сразу к делу.', 'Паузы только на: позицию, прицел, активацию, зону ревила.', 'Без Alt+Tab во время записи.'],
    ['Длина видео — не более 30 секунд (несколько дымов).', 'В начале записи — без пауз, сразу к делу.', 'Пауза на каждой точке прицела — зритель должен успеть увидеть.', 'Без Alt+Tab во время записи.'],
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, sc) {
        final stepsFromFirestore = _list(_tab, 'steps');
        final timingsFromFirestore = _list(_tab, 'timings');

        final steps = stepsFromFirestore.isNotEmpty
            ? stepsFromFirestore.asMap().entries.map((e) =>
                _sheetStep(t, '${e.key + 1}', e.value, '')).toList()
            : _fallbackSteps[_tab].asMap().entries.map((e) =>
                _sheetStep(t, '${e.key + 1}', e.value.$1, e.value.$2)).toList();

        final timings = timingsFromFirestore.isNotEmpty
            ? timingsFromFirestore
            : _fallbackTimings[_tab];

        return ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.howToGetLevel2Title,
                style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.xpDesc,
              style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.lineupRequirementsTitle,
                style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Переключатель групп
            Row(
              children: List.generate(3, (i) {
                final active = i == _tab;
                final name = _tabName(i);
                final icon = _tabIcon(i);
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _tab = i);
                      _loadTab(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? t.primary : t.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? t.primary : t.border),
                      ),
                      child: Text(
                        icon.isNotEmpty ? '$icon $name' : name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active ? Colors.white : t.textSecondary,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            if (!_loaded[_tab])
              Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: t.primary, strokeWidth: 2),
              ))
            else ...[
              ...steps,
              const SizedBox(height: 20),
              _sheetSection(t, AppLocalizations.of(context)!.timingsSectionTitle),
              const SizedBox(height: 10),
              ...timings.map((s) => _sheetBullet(t, s)),
            ],

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(AppLocalizations.of(context)!.gotItWillPost,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _sheetSection(AppThemeData t, String title) =>
      Text(title, style: TextStyle(color: t.textPrimary, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _sheetStep(AppThemeData t, String num, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
            child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: body.isEmpty
                ? Text(title, style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(body, style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sheetBullet(AppThemeData t, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: t.primary, fontSize: 16, height: 1.3)),
          Expanded(child: Text(text, style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }
}

// ─── Кнопка голосования репутации ─────────────────────────────────────────────

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  final AppThemeData theme;

  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.color,
    required this.loading,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : theme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : theme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: isActive ? color : theme.textSecondary, size: 16),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    color: isActive ? color : theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
