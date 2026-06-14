import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/image_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agents_config_service.dart';
import 'favorites_service.dart';
import 'guide_screen.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'exclusive_service.dart';
import 'ad_service.dart';

class InteractiveMapScreen extends StatefulWidget {
  final String mapName;
  final String agentName;
  final String mapAsset;
  final List<Map<String, dynamic>> abilities;
  final String category;
  final List<Map<String, dynamic>>? preloadedLineups;
  final bool favoritesMode;

  const InteractiveMapScreen({
    super.key,
    required this.mapName,
    required this.agentName,
    required this.mapAsset,
    required this.abilities,
    required this.category,
    this.preloadedLineups,
    this.favoritesMode = false,
  });

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen>
    with TickerProviderStateMixin {
  static const Color _selectedColor = Color(0xFF4CAF50);

  String? selectedAbility;
  List<Map<String, dynamic>> allLineups = [];
  List<Map<String, dynamic>> _filteredAbilities = [];
  bool _hasExclusiveAccess = false;

  // Trajectory animation
  String? _activeLineupId;
  late AnimationController _trajectoryAnim;
  late AnimationController _rangeAnim;

  // Pulse animation for selected marker
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _trajectoryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rangeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _trajectoryAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rangeAnim.forward(from: 0);
      } else if (status == AnimationStatus.dismissed) {
        _rangeAnim.reset();
      }
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _filteredAbilities = widget.abilities;
    loadAllLineups();
    _loadExclusiveAccess();
    _loadAbilitiesConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final ability in widget.abilities) {
        final icon = ability['displayIcon'] as String?;
        if (icon != null && icon.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(icon, cacheManager: AppImageCache.manager), context);
        }
      }
    });
    ExclusiveService.accessNotifier.addListener(_onAccessChanged);
  }

  @override
  void dispose() {
    _trajectoryAnim.dispose();
    _rangeAnim.dispose();
    _pulseCtrl.dispose();
    ExclusiveService.accessNotifier.removeListener(_onAccessChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(InteractiveMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.abilities != widget.abilities) {
      _filteredAbilities = widget.abilities;
      _loadAbilitiesConfig();
    }
  }

  void _onAccessChanged() => _loadExclusiveAccess();

  Future<void> _loadAbilitiesConfig() async {
    final filtered = await AgentsConfigService.filterAbilities(
        widget.agentName, widget.category, widget.abilities);
    if (mounted) setState(() => _filteredAbilities = filtered);
  }

  Future<void> _loadExclusiveAccess() async {
    final has = await ExclusiveService.hasAccess();
    if (mounted) setState(() => _hasExclusiveAccess = has);
  }

  void loadAllLineups() async {
    if (widget.preloadedLineups != null) {
      if (mounted) setState(() => allLineups = List.from(widget.preloadedLineups!));
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lineups')
          .where('map', isEqualTo: widget.mapName)
          .where('agent', isEqualTo: widget.agentName)
          .where('status', isEqualTo: 'approved')
          .where('category', isEqualTo: widget.category)
          .limit(100)
          .get();
      if (mounted) {
        setState(() {
          allLineups = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmRemoveFavorite(BuildContext context, String lineupId) async {
    final t = AppThemeNotifier.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Убрать из избранного?',
            style: TextStyle(color: t.textPrimary, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await FavoritesService.removeFavorite(lineupId);
      setState(() {
        allLineups.removeWhere((l) => l['id'] == lineupId);
        if (_activeLineupId == lineupId) {
          _activeLineupId = null;
          _trajectoryAnim.reset();
          _pulseCtrl.reset();
        }
      });
    }
  }

  // ── Filtered lineups (side filter + exclusive-first) ──────────────────────

  List<Map<String, dynamic>> get _filteredLineups {
    final list = [...allLineups];
    list.sort((a, b) {
      final aEx = (a['is_exclusive'] as bool? ?? false) ? 0 : 1;
      final bEx = (b['is_exclusive'] as bool? ?? false) ? 0 : 1;
      return aEx.compareTo(bEx);
    });
    return list;
  }

  // ── Grouping ──────────────────────────────────────────────────────────────

  List<List<Map<String, dynamic>>> _groupLineups(List<Map<String, dynamic>> lineups) {
    final groups = <List<Map<String, dynamic>>>[];
    for (final lineup in lineups) {
      final x = (lineup['position_x'] ?? 0.5) as double;
      final y = (lineup['position_y'] ?? 0.5) as double;
      bool added = false;
      for (final group in groups) {
        final gx = (group.first['position_x'] ?? 0.5) as double;
        final gy = (group.first['position_y'] ?? 0.5) as double;
        if ((x - gx).abs() < 0.02 && (y - gy).abs() < 0.02) {
          group.add(lineup);
          added = true;
          break;
        }
      }
      if (!added) groups.add([lineup]);
    }
    return groups;
  }

  // ── Trajectory helpers ────────────────────────────────────────────────────

  List<Map<String, dynamic>> _parseTrajectory(Map<String, dynamic> lineup) {
    final raw = lineup['trajectory'];
    if (raw is! List || raw.isEmpty) return [];
    return raw.whereType<Map>().map((p) => {
          'x': ((p['x'] ?? 0) as num).toDouble(),
          'y': ((p['y'] ?? 0) as num).toDouble(),
        }).toList();
  }

  List<Map<String, dynamic>> _getActiveTrajectoryPoints() {
    if (_activeLineupId == null) return [];
    try {
      final lineup = allLineups.firstWhere((l) => l['id'] == _activeLineupId);
      return _parseTrajectory(lineup);
    } catch (_) {
      return [];
    }
  }

  double get _activeRangeRadius {
    if (_activeLineupId == null) return 0.0;
    try {
      final lineup = allLineups.firstWhere((l) => l['id'] == _activeLineupId);
      return (lineup['range_radius'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  void _clearTrajectory() {
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    _trajectoryAnim.reset();
    setState(() => _activeLineupId = null);
  }

  void _selectLineup(String id) {
    setState(() => _activeLineupId = id);
    _trajectoryAnim.forward(from: 0);
    _pulseCtrl.forward(from: 0);
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  Future<void> _onLineupTap(Map<String, dynamic> lineup) async {
    final isExclusive = lineup['is_exclusive'] as bool? ?? false;

    if (isExclusive && !_hasExclusiveAccess) {
      await _showExclusiveMapDialog(lineup);
      return;
    }

    final trajectory = _parseTrajectory(lineup);
    if (trajectory.isNotEmpty && _activeLineupId != lineup['id']) {
      _selectLineup(lineup['id'] as String);
      return;
    }

    // Second tap on same lineup, or no trajectory → open guide
    final screenshots = List<String>.from(lineup['screenshots'] ?? []);
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute(
        builder: (_) => GuideScreen(
          lineupId: lineup['id'] as String? ?? '',
          title: lineup['title'] ?? '',
          description: lineup['description'] ?? '',
          ability: lineup['ability'] ?? '',
          mapName: widget.mapName,
          agentName: widget.agentName,
          videoUrl: lineup['video_url'],
          screenshots: screenshots,
          category: widget.category,
          isExclusive: isExclusive,
          authorName: lineup['submitted_by'] as String?,
          authorId: lineup['user_id'] as String?,
          difficulty: lineup['difficulty'] as String?,
        ),
      ),
    );
  }

  void _showGroupSheet(
      BuildContext context, AppThemeData t, List<Map<String, dynamic>> group) {
    String? selectedId = _activeLineupId;
    String? diffFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final displayed = diffFilter == null
              ? group
              : group.where((l) => l['difficulty'] == diffFilter).toList();

          Widget diffChip(String? value, String label) {
            final active = diffFilter == value;
            return GestureDetector(
              onTap: () => setSheetState(() {
                diffFilter = value;
                if (selectedId != null &&
                    displayed.every((l) => l['id'] != selectedId)) {
                  selectedId = null;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? t.primary : t.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? t.primary : t.border),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : t.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Difficulty filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    diffChip(null, 'Все'),
                    const SizedBox(width: 6),
                    diffChip('easy', '🟢 Легко'),
                    const SizedBox(width: 6),
                    diffChip('medium', '🟡 Средне'),
                    const SizedBox(width: 6),
                    diffChip('hard', '🔴 Сложно'),
                  ],
                ),
              ),
              ...displayed.map((lineup) {
                final id = lineup['id'] as String?;
                final isExclusive = lineup['is_exclusive'] as bool? ?? false;
                final isSelected = id != null && id == selectedId;
                return GestureDetector(
                  onTap: () {
                    setSheetState(() => selectedId = id);
                    if (id != null) _selectLineup(id);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _selectedColor.withValues(alpha: 0.12) : t.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected ? _selectedColor : t.border,
                          width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lineup['title'] ?? '',
                            style: TextStyle(
                              color: isSelected ? _selectedColor : t.textPrimary,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isExclusive)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text('👑', style: TextStyle(fontSize: 12)),
                          ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check, color: _selectedColor, size: 16),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              if (displayed.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Нет лайнапов с такой сложностью',
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedId == null
                        ? null
                        : () async {
                            final lineup = displayed.firstWhere(
                              (l) => l['id'] == selectedId,
                              orElse: () => displayed.first,
                            );
                            Navigator.pop(ctx);
                            await _onLineupTap(lineup);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.primary,
                      disabledBackgroundColor: t.border,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Открыть лайнап',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void showSelectAbilityHint() {
    final t = AppThemeNotifier.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: t.primary, size: 48),
            const SizedBox(height: 12),
            Text('Выберите абилку снизу',
                style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Нажмите на абилку внизу экрана чтобы увидеть лайнапы',
                style: TextStyle(color: t.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: t.primary),
              child: const Text('Понял!', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExclusiveMapDialog(Map<String, dynamic> lineup) async {
    final t = AppThemeNotifier.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('⭐ Эксклюзивный лайнап',
            style: TextStyle(color: Colors.amber.shade600, fontSize: 16)),
        content: Text(
          'Посмотри рекламу чтобы открыть все эксклюзивные лайнапы на 1 час',
          style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Смотреть рекламу', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    if (!AdService.isRewardedReady) {
      if (mounted) {
        AppSnackBar.show(context, 'Реклама загружается, попробуй через секунду...', type: SnackBarType.warning);
      }
      return;
    }

    AdService.showRewarded(
      onRewarded: () async {
        await ExclusiveService.grantAccess();
        if (!mounted) return;
        setState(() => _hasExclusiveAccess = true);
        final screenshots = List<String>.from(lineup['screenshots'] ?? []);
        final nav = Navigator.of(context);
        nav.push(
          MaterialPageRoute(
            builder: (_) => GuideScreen(
              lineupId: lineup['id'] as String? ?? '',
              title: lineup['title'] ?? '',
              description: lineup['description'] ?? '',
              ability: lineup['ability'] ?? '',
              mapName: widget.mapName,
              agentName: widget.agentName,
              videoUrl: lineup['video_url'],
              screenshots: screenshots,
              category: widget.category,
              isExclusive: true,
              authorName: lineup['submitted_by'] as String?,
              authorId: lineup['user_id'] as String?,
              difficulty: lineup['difficulty'] as String?,
            ),
          ),
        );
      },
      onDismissed: () {
        if (mounted) {
          AppSnackBar.show(context, 'Досмотри рекламу до конца чтобы получить доступ', type: SnackBarType.error);
        }
      },
      onNotReady: () {
        if (mounted) {
          AppSnackBar.show(context, 'Реклама недоступна, попробуй позже', type: SnackBarType.warning);
        }
      },
    );
  }

  // ── Marker widgets ────────────────────────────────────────────────────────

  Widget _markerWidget(AppThemeData t, Map<String, dynamic> lineup, bool isActive,
      {bool isSelected = false}) {
    final isExclusive = lineup['is_exclusive'] as bool? ?? false;
    final abilityName = lineup['ability'] ?? '';
    final ability = widget.abilities.firstWhere(
        (a) => a['displayName'] == abilityName, orElse: () => {});
    final iconUrl = ability['displayIcon'] ?? '';

    final borderColor = isSelected
        ? _selectedColor
        : isExclusive
            ? (isActive ? Colors.amber : Colors.amber.withValues(alpha: 0.4))
            : (isActive ? t.primary : Colors.white38);

    final marker = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: t.surface,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: isSelected ? 2.5 : 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: ClipOval(
        child: Opacity(
          opacity: isActive || isSelected ? 1.0 : 0.3,
          child: ColorFiltered(
            colorFilter: isActive || isSelected
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ]),
            child: iconUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: iconUrl, cacheManager: AppImageCache.manager, width: 20, height: 20, fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Colors.transparent),
                    errorWidget: (_, _, _) => Icon(Icons.place, color: t.textPrimary, size: 12))
                : Icon(Icons.place, color: t.textPrimary, size: 12),
          ),
        ),
      ),
    );

    if (!isExclusive) return marker;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        marker,
        const Positioned(
          top: -8, right: -8,
          child: Text('⭐', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  Widget _groupMarkerWidget(
      AppThemeData t, List<Map<String, dynamic>> group, bool isActive) {
    final isSelected = group.any((l) => l['id'] == _activeLineupId);
    final rep = isSelected
        ? group.firstWhere((l) => l['id'] == _activeLineupId, orElse: () => group.first)
        : isActive
            ? group.firstWhere((l) => l['ability'] == selectedAbility, orElse: () => group.first)
            : group.first;

    final base = _markerWidget(t, rep, isActive, isSelected: isSelected);

    Widget result = group.length == 1
        ? base
        : Stack(
            clipBehavior: Clip.none,
            children: [
              base,
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${group.length}',
                      style: const TextStyle(
                        color: Color(0xFFFF4655),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    if (isSelected) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
        child: result,
      );
    }
    return result;
  }

  // ── Info panel (shown when lineup is selected) ────────────────────────────

  Widget _buildInfoPanel(AppThemeData t, String? title) {
    return Container(
      color: t.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, color: _selectedColor, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Нажмите ещё раз чтобы открыть',
                      style: TextStyle(color: _selectedColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.favoritesMode && _activeLineupId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Убрать из избранного',
              onPressed: () => _confirmRemoveFavorite(context, _activeLineupId!),
            ),
        ],
      ),
    );
  }

  // ── Ability panel ─────────────────────────────────────────────────────────

  Widget _buildAbilityPanel(AppThemeData t) {
    return SafeArea(
      top: false,
      child: Container(
        color: t.surface,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text('Выбери абилку:',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            ),
            Row(
              children: _filteredAbilities.map((ability) {
                final isSelected = selectedAbility == ability['displayName'];
                final name = ability['displayName'] ?? '';
                final icon = ability['displayIcon'] ?? '';
                if (icon.isEmpty) return const SizedBox.shrink();
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      selectedAbility = name;
                      _clearTrajectory();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? t.primary : t.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? t.primary : t.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CachedNetworkImage(
                            imageUrl: icon, cacheManager: AppImageCache.manager, width: 30, height: 30,
                            placeholder: (_, _) => Container(color: Colors.transparent),
                            errorWidget: (_, _, _) =>
                                Icon(Icons.flash_on, color: t.textPrimary, size: 28)),
                          const SizedBox(height: 4),
                          Text(name,
                              style: TextStyle(
                                  color: isSelected ? Colors.white : t.textSecondary,
                                  fontSize: 9),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    final groups = _groupLineups(_filteredLineups);

    String? activeTitle;
    if (_activeLineupId != null) {
      try {
        activeTitle = allLineups
            .firstWhere((l) => l['id'] == _activeLineupId)['title'] as String?;
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          '${widget.agentName} — ${widget.mapName}'.toUpperCase(),
          style: TextStyle(
              color: t.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 13),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: Column(
        children: [
          // ─── Карта + инфо-панель ─────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final activePoints = _getActiveTrajectoryPoints();

                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Stack(
                          children: [
                            // Background — tap to clear selection
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (_activeLineupId != null) _clearTrajectory();
                              },
                              child: Image.asset(
                                widget.mapAsset,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                fit: BoxFit.contain,
                              ),
                            ),

                            // Trajectory overlay (layer 2)
                            if (activePoints.length >= 2)
                              IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_trajectoryAnim, _rangeAnim]),
                                  builder: (context, _) => SizedBox(
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    child: CustomPaint(
                                      painter: _TrajectoryPainter(
                                        points: activePoints,
                                        progress: _trajectoryAnim.value,
                                        color: _selectedColor,
                                        rangeRadius: _activeRangeRadius,
                                        rangeProgress: _rangeAnim.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Markers (layer 3)
                            ...groups.map((group) {
                              final x = (group.first['position_x'] ?? 0.5) as double;
                              final y = (group.first['position_y'] ?? 0.5) as double;
                              final isAllMode = selectedAbility == null;
                              final isActive = !isAllMode &&
                                  group.any((l) => l['ability'] == selectedAbility);

                              return Positioned(
                                left: x * constraints.maxWidth - 10,
                                top: y * constraints.maxHeight - 10,
                                child: GestureDetector(
                                  onTap: () async {
                                    if (isAllMode) {
                                      showSelectAbilityHint();
                                      return;
                                    }
                                    if (!isActive) return;

                                    final activeInGroup = group
                                        .where((l) => l['ability'] == selectedAbility)
                                        .toList();

                                    if (activeInGroup.length > 1) {
                                      _showGroupSheet(context, t, activeInGroup);
                                    } else {
                                      await _onLineupTap(activeInGroup.first);
                                    }
                                  },
                                  child: _groupMarkerWidget(t, group, isActive),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Инфо-панель поверх карты (без смещения)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: AnimatedSlide(
                      offset: _activeLineupId != null
                          ? Offset.zero
                          : const Offset(0, 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: IgnorePointer(
                        ignoring: _activeLineupId == null,
                        child: _buildInfoPanel(t, activeTitle),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Панель абилок ───────────────────────────────────────────
          _buildAbilityPanel(t),
        ],
      ),
    );
  }
}

// ── Trajectory painter ────────────────────────────────────────────────────────

class _TrajectoryPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final double progress;
  final Color color;
  final double rangeRadius;
  final double rangeProgress;

  const _TrajectoryPainter({
    required this.points,
    required this.progress,
    required this.color,
    this.rangeRadius = 0.0,
    this.rangeProgress = 0.0,
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

    // Segment lengths and total
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

    // Draw animated line segments
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

    // Dots at each waypoint that has been reached
    double d = 0;
    for (int i = 0; i < pts.length; i++) {
      if (d <= targetLen) canvas.drawCircle(pts[i], 3.5, fillPaint);
      if (i < segments.length) d += segments[i];
    }

    // Arrowhead at the current animation endpoint
    if ((currentEnd - segmentStart).distance > 1) {
      _drawArrow(canvas, segmentStart, currentEnd, fillPaint);
    }

    // Range radius circle — appears with fade-in when trajectory is complete
    if (rangeProgress > 0 && rangeRadius > 0.0 && pts.isNotEmpty) {
      final center = pts.last;
      final radiusPx = rangeRadius * size.width;

      final rangeFillPaint = Paint()
        ..color = color.withValues(alpha: 0.12 * rangeProgress)
        ..style = PaintingStyle.fill;

      final rangeBorderPaint = Paint()
        ..color = color.withValues(alpha: 0.55 * rangeProgress)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radiusPx, rangeFillPaint);
      canvas.drawCircle(center, radiusPx, rangeBorderPaint);
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
    final left = Offset(bx - hw * uy, by + hw * ux);
    final right = Offset(bx + hw * uy, by - hw * ux);
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) =>
      old.progress != progress ||
      old.points.length != points.length ||
      old.color != color ||
      old.rangeRadius != rangeRadius ||
      old.rangeProgress != rangeProgress;
}
