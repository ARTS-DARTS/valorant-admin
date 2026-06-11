import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'services/image_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorites_service.dart';
import 'interactive_map_screen.dart';
import 'valorant_api.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  StreamSubscription<List<String>>? _sub;
  bool _loading = true;
  String? _error;
  Map<String, Map<String, List<Map<String, dynamic>>>> _grouped = {};
  Map<String, String> _agentIcons = {};
  final Set<String> _collapsedAgents = {};
  final Map<String, AnimationController> _expandControllers = {};
  final Map<String, Animation<double>> _expandAnimations = {};

  static const _mapOrder = [
    'Haven', 'Bind', 'Ascent', 'Split', 'Icebox',
    'Breeze', 'Fracture', 'Pearl', 'Lotus', 'Sunset', 'Abyss', 'Corrode',
  ];

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadAgentIcons();
  }

  void _subscribe() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _sub?.cancel();
    _sub = FavoritesService.getFavorites().listen(
      (ids) async {
        if (!mounted) return;
        if (ids.isEmpty) {
          setState(() {
            _grouped = {};
            _loading = false;
          });
          return;
        }
        final lineups = await _loadLineups(ids);
        final grouped = _groupLineups(lineups);
        if (mounted) setState(() { _grouped = grouped; _loading = false; });
      },
      onError: (Object _) {
        if (mounted) setState(() { _error = 'РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё'; _loading = false; });
      },
    );
  }

  Future<void> _loadAgentIcons() async {
    try {
      final agents = await ValorantApi.getCached() ?? await ValorantApi.getAgents();
      if (!mounted) return;
      final icons = <String, String>{};
      for (final a in agents) {
        final name = a['displayName'] as String? ?? '';
        final icon = a['displayIconSmall'] as String? ?? '';
        if (name.isNotEmpty) icons[name] = icon;
      }
      if (mounted) setState(() => _agentIcons = icons);
    } catch (_) {}
  }

  AnimationController _getController(String agentName) {
    if (_expandControllers.containsKey(agentName)) return _expandControllers[agentName]!;
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed || status == AnimationStatus.completed) {
        if (mounted) setState(() {});
      }
    });
    _expandControllers[agentName] = ctrl;
    _expandAnimations[agentName] = CurvedAnimation(
      parent: ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (!_collapsedAgents.contains(agentName)) ctrl.value = 1.0;
    return ctrl;
  }

  void _toggleAgent(String agentName) {
    final ctrl = _getController(agentName);
    if (_collapsedAgents.contains(agentName)) {
      setState(() => _collapsedAgents.remove(agentName));
      ctrl.forward();
    } else {
      setState(() => _collapsedAgents.add(agentName));
      ctrl.reverse();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _expandControllers.values) {
      ctrl.dispose();
    }
    _sub?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadLineups(List<String> ids) async {
    final results = <Map<String, dynamic>>[];
    int failCount = 0;
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance.collection('lineups').doc(id).get();
        if (doc.exists) {
          final d = doc.data()!;
          if (d['status'] != 'archived') results.add({...d, 'id': doc.id});
        }
      } catch (_) {
        failCount++;
      }
    }
    if (results.isEmpty && failCount > 0 && mounted) {
      setState(() => _error = 'РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё ($failCount/${ids.length} РЅРµ СѓРґР°Р»РѕСЃСЊ)');
    }
    return results;
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupLineups(
      List<Map<String, dynamic>> lineups) {
    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final l in lineups) {
      final agent = l['agent'] as String? ?? '';
      final map = l['map'] as String? ?? '';
      if (agent.isEmpty || map.isEmpty) continue;
      grouped.putIfAbsent(agent, () => {})[map] =
          [...(grouped[agent]?[map] ?? []), l];
    }
    return grouped;
  }

  List<Map<String, dynamic>> _sortedLineups(List<Map<String, dynamic>> lineups) {
    return [...lineups]..sort((a, b) {
      final aMap = a['map'] as String? ?? '';
      final bMap = b['map'] as String? ?? '';
      final aIdx = _mapOrder.indexOf(aMap);
      final bIdx = _mapOrder.indexOf(bMap);
      final aOrd = aIdx == -1 ? 999 : aIdx;
      final bOrd = bIdx == -1 ? 999 : bIdx;
      return aOrd.compareTo(bOrd);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          AppLocalizations.of(context)!.favorites.toUpperCase(),
          style: TextStyle(color: t.primary, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(AppThemeData t) {
    if (_loading) return Center(child: CircularProgressIndicator(color: t.primary));

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 56),
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: t.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('РџРѕРІС‚РѕСЂРёС‚СЊ', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, color: t.border, size: 56),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.favoritesEmpty,
                style: TextStyle(color: t.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context)!.favoritesEmptyDesc,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final agents = _grouped.entries.toList()
      ..sort((a, b) {
        final aC = a.value.values.fold<int>(0, (s, l) => s + l.length);
        final bC = b.value.values.fold<int>(0, (s, l) => s + l.length);
        return bC.compareTo(aC);
      });

    // Background map — first lineup of first agent
    final firstMapName = agents.isNotEmpty
        ? (agents.first.value.keys.isNotEmpty ? agents.first.value.keys.first : '')
        : '';

    final slivers = <Widget>[];
    for (final entry in agents) {
      final agentName = entry.key;
      final mapsGroup = entry.value;
      final allLineups = _sortedLineups(
        mapsGroup.values.expand((list) => list).toList(),
      );
      final count = allLineups.length;
      final iconUrl = _agentIcons[agentName] ?? '';
      final ctrl = _getController(agentName);
      final anim = _expandAnimations[agentName]!;

      slivers.add(SliverAppBar(
        key: ValueKey('header_$agentName'),
        pinned: true,
        floating: false,
        snap: false,
        toolbarHeight: 52,
        backgroundColor: t.surface,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleAgent(agentName),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (iconUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: iconUrl,
                    cacheManager: AppImageCache.manager,
                    width: 34, height: 34,
                    fit: BoxFit.contain,
                  )
                else
                  Icon(Icons.person, size: 34, color: t.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    agentName,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: t.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: ctrl,
                  builder: (ctx, child) => Icon(
                    ctrl.isDismissed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: t.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      slivers.add(SliverToBoxAdapter(
        key: ValueKey('grid_$agentName'),
        child: SizeTransition(
          axisAlignment: -1.0,
          sizeFactor: anim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Column(
              children: List.generate(
                (allLineups.length / 2).ceil(),
                (rowIndex) {
                  final i1 = rowIndex * 2;
                  final i2 = i1 + 1;
                  final rowDelay = rowIndex * 0.08;
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (_, child) {
                      final raw = (anim.value - rowDelay).clamp(0.0, 1.0);
                      final denom = (1.0 - rowDelay).clamp(0.0001, 1.0);
                      final progress = (raw / denom).clamp(0.0, 1.0);
                      final curved = Curves.easeOutCubic.transform(progress);
                      return Opacity(
                        opacity: curved,
                        child: Transform.translate(
                          offset: Offset(0, (1 - curved) * 24),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildLineupCard(allLineups[i1], mapsGroup, t),
                          ),
                          const SizedBox(width: 10),
                          if (i2 < allLineups.length)
                            Expanded(
                              child: _buildLineupCard(allLineups[i2], mapsGroup, t),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ));
    }

    return Container(
      color: t.background,
      child: CustomScrollView(slivers: slivers),
    );
  }

  Widget _buildLineupCard(
    Map<String, dynamic> lineup,
    Map<String, List<Map<String, dynamic>>> mapsGroup,
    AppThemeData t,
  ) {
    final screenshots = lineup['screenshots'] as List? ?? [];
    final thumbUrl = screenshots.isNotEmpty ? screenshots[0] as String : null;
    final title = lineup['title'] as String? ?? '';
    final mapName = lineup['map'] as String? ?? '';
    final ability = lineup['ability'] as String? ?? '';

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          final lineupsByMap = mapsGroup[mapName] ?? [lineup];
          final idx = lineupsByMap.indexOf(lineup);
          final heroTag = 'lineup_${lineup['id'] ?? title}_$mapName';
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              reverseTransitionDuration: const Duration(milliseconds: 350),
              pageBuilder: (ctx, animation, secondary) => _LineupDetailScreen(
                lineups: lineupsByMap,
                initialIndex: idx < 0 ? 0 : idx,
                heroTag: heroTag,
              ),
              transitionsBuilder: (ctx, animation, secondary, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: child,
                );
              },
            ),
          );
        },
        child: Hero(
          tag: 'lineup_${lineup['id'] ?? title}_$mapName',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: thumbUrl != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: thumbUrl,
                                  cacheManager: AppImageCache.manager,
                                  fit: BoxFit.cover,
                                  placeholder: (ctx, url) =>
                                      Container(color: Colors.white10),
                                  errorWidget: (ctx, url, err) => Container(
                                    color: Colors.white10,
                                    child: Icon(Icons.image_not_supported,
                                        color: Colors.white38),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black87],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 5, left: 6, right: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mapName.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 8,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_outlined,
                                    color: Colors.white38, size: 28),
                                const SizedBox(height: 4),
                                Text(mapName,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      child: Text(
                        ability,
                        style: TextStyle(
                          color: t.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
      ),
    ),
  );
  }
}


// ── Lineup detail screen (Hero destination) ────────────────────────────────

class _LineupDetailScreen extends StatefulWidget {
  final List<Map<String, dynamic>> lineups;
  final int initialIndex;
  final String heroTag;

  const _LineupDetailScreen({
    required this.lineups,
    required this.initialIndex,
    required this.heroTag,
  });

  @override
  State<_LineupDetailScreen> createState() => _LineupDetailScreenState();
}

class _LineupDetailScreenState extends State<_LineupDetailScreen> {
  late int _current;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineup = widget.lineups[_current];
    final title = lineup['title'] as String? ?? '';
    final mapName = lineup['map'] as String? ?? '';
    final ability = lineup['ability'] as String? ?? '';
    final agentName = lineup['agent'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e1a),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 15),
                    ),
                  ),
                  const Spacer(),
                  if (widget.lineups.length > 1)
                    Text(
                      '${_current + 1} / ${widget.lineups.length}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _tag(Icons.map_outlined, mapName, Colors.white54, Colors.white12),
                  _tag(Icons.person_outline, agentName, const Color(0xFFFF6670), const Color(0x26FF4655)),
                  _tag(null, ability, Colors.white38, Colors.white.withValues(alpha: 0.05)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: widget.lineups.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) {
                  final view = _LineupMediaView(lineup: widget.lineups[i]);
                  if (i == widget.initialIndex) {
                    return Hero(
                      tag: widget.heroTag,
                      flightShuttleBuilder: (_, animation, direction, fromCtx, toCtx) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (_, child) => Material(
                            color: Colors.transparent,
                            child: toCtx.widget,
                          ),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: view,
                      ),
                    );
                  }
                  return view;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData? icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Media view for one lineup ───────────────────────────────────────────────

class _LineupMediaView extends StatefulWidget {
  final Map<String, dynamic> lineup;
  final String? heroTag;

  const _LineupMediaView({required this.lineup, this.heroTag});

  @override
  State<_LineupMediaView> createState() => _LineupMediaViewState();
}

class _LineupMediaViewState extends State<_LineupMediaView> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _videoError = false;
  bool _showControls = false;

  List<String> get _screenshots =>
      List<String>.from(widget.lineup['screenshots'] ?? []);
  String? get _videoUrl => widget.lineup['video_url'] as String?;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = _videoUrl;
    if (url == null || url.isEmpty) return;
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          ctrl?.dispose();
          if (mounted) setState(() => _videoError = true);
          return;
        },
      );
      if (!mounted) { ctrl.dispose(); return; }
      ctrl.setLooping(true);
      ctrl.play();
      setState(() { _videoCtrl = ctrl; _videoReady = true; });
    } catch (_) {
      ctrl?.dispose();
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenshots = _screenshots;
    final hasVideo = _videoUrl != null && _videoUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasVideo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: _videoReady && _videoCtrl != null
                    ? _videoCtrl!.value.aspectRatio
                    : 16 / 9,
                child: _videoError
                    ? Container(
                        color: const Color(0xFF1a2330),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'Видео недоступно',
                                style: TextStyle(color: Colors.white24, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _videoReady && _videoCtrl != null
                        ? GestureDetector(
                            onTap: () {
                              setState(() => _showControls = !_showControls);
                              if (_videoCtrl!.value.isPlaying) {
                                _videoCtrl!.pause();
                              } else {
                                _videoCtrl!.play();
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(_videoCtrl!),
                                if (_showControls || !_videoCtrl!.value.isPlaying)
                                  Container(
                                    color: Colors.black38,
                                    child: Center(
                                      child: Icon(
                                        _videoCtrl!.value.isPlaying
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        color: Colors.white70,
                                        size: 52,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1a2330),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF4655),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (screenshots.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'СКРИНШОТЫ',
                    style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 0.5, color: Colors.white12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...screenshots.map((url) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                clipBehavior: Clip.hardEdge,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      cacheManager: AppImageCache.manager,
                      fit: BoxFit.contain,
                      color: const Color(0xFF0a0e1a),
                      colorBlendMode: BlendMode.dst,
                      placeholder: (ctx, url) => Container(
                        color: const Color(0xFF111820),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF4655),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (ctx, url, err) => Container(
                        color: const Color(0xFF111820),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 32),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Interactive map scoped to favorites ────────────────────────────────────

class _FavoritesMapScreen extends StatefulWidget {
  final String agentName;
  final String mapName;
  final List<Map<String, dynamic>> lineups;

  const _FavoritesMapScreen({
    required this.agentName,
    required this.mapName,
    required this.lineups,
  });

  @override
  State<_FavoritesMapScreen> createState() => _FavoritesMapScreenState();
}

class _FavoritesMapScreenState extends State<_FavoritesMapScreen> {
  List<Map<String, dynamic>> _abilities = [];
  bool _abilitiesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAbilities();
  }

  Future<void> _loadAbilities() async {
    try {
      final agents =
          await ValorantApi.getCached() ?? await ValorantApi.getAgents();
      final agent = agents.firstWhere(
        (a) => a['displayName'] == widget.agentName,
        orElse: () => <String, dynamic>{},
      );
      final abilities =
          List<Map<String, dynamic>>.from(agent['abilities'] ?? []);
      if (mounted && abilities.isNotEmpty) {
        setState(() { _abilities = abilities; _abilitiesLoaded = true; });
        return;
      }
    } catch (_) {}
    final seen = <String>{};
    final fallback = <Map<String, dynamic>>[];
    for (final l in widget.lineups) {
      final name = l['ability'] as String? ?? '';
      if (name.isNotEmpty && seen.add(name)) {
        fallback.add({'displayName': name, 'displayIcon': ''});
      }
    }
    if (mounted) setState(() { _abilities = fallback; _abilitiesLoaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    if (!_abilitiesLoaded) {
      return Scaffold(
        backgroundColor: t.background,
        body: Center(child: CircularProgressIndicator(color: t.primary)),
      );
    }
    return InteractiveMapScreen(
      mapName: widget.mapName,
      agentName: widget.agentName,
      mapAsset: 'assets/maps/${widget.mapName}_minimap.png',
      abilities: _abilities,
      category: 'lineup',
      preloadedLineups: widget.lineups,
      favoritesMode: true,
    );
  }
}

