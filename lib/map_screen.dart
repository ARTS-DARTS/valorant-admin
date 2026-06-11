import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/image_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'valorant_api.dart';
import 'agents_config_service.dart';
import 'interactive_map_screen.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'ad_service.dart';

class MapScreen extends StatefulWidget {
  final String mapName;
  final String mapAsset;
  final String category;
  const MapScreen({
    super.key,
    required this.mapName,
    required this.mapAsset,
    required this.category,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Map<String, dynamic>> agents = [];
  bool loading = true;
  bool _hasError = false;
  Set<String> disabledAgents = {};
  String? selectedRole;
  Map<String, int> lineupCounts = {};
  int _navCount = 0;
  String? _lastOpenedAgent;
  Set<String> _favoriteAgents = {};
  bool _showOnlyFavorites = false;

  // Порядок ролей: Зачинщик → Страж → Специалист → Дуэлянт
  static const _roleOrder = [
    'Зачинщик', 'Страж', 'Специалист', 'Дуэлянт',
    // английский fallback на случай смены языка API
    'Initiator', 'Sentinel', 'Controller', 'Duelist',
    // устаревшие русские названия (старый API)
    'Контроллер', 'Защитник', 'Инициатор',
  ];

  // Отображаемые названия ролей
  static const _roleDisplayName = {
    'Зачинщик':   'Инициатор',
    'Специалист': 'Смокер',
    // английский fallback
    'Initiator':  'Инициатор',
    'Controller': 'Смокер',
    'Sentinel':   'Страж',
    'Duelist':    'Дуэлянт',
    // устаревшие
    'Контроллер': 'Смокер',
    'Защитник':   'Смокер',
    'Инициатор':  'Инициатор',
  };

  static const _roleEmoji = {
    'Зачинщик':   '🔍',
    'Специалист': '🌀',
    'Страж':      '🛡',
    'Дуэлянт':    '⚔️',
    // английский fallback
    'Initiator':  '🔍',
    'Controller': '🌀',
    'Sentinel':   '🛡',
    'Duelist':    '⚔️',
    // устаревшие
    'Контроллер': '🌀',
    'Защитник':   '🌀',
    'Инициатор':  '🔍',
  };

  // Жёстко заданный порядок агентов внутри каждой роли
  static const _agentOrder = <String, List<String>>{
    'Зачинщик':   ['Sova', 'Breach', 'Fade', 'Gekko', 'KAY/O', 'Skye', 'Tejo'],
    'Initiator':  ['Sova', 'Breach', 'Fade', 'Gekko', 'KAY/O', 'Skye', 'Tejo'],
    'Инициатор':  ['Sova', 'Breach', 'Fade', 'Gekko', 'KAY/O', 'Skye', 'Tejo'],
    'Специалист': ['Viper', 'Brimstone', 'Omen', 'Astra', 'Harbor', 'Clove', 'Miks'],
    'Контроллер': ['Viper', 'Brimstone', 'Omen', 'Astra', 'Harbor', 'Clove', 'Miks'],
    'Controller': ['Viper', 'Brimstone', 'Omen', 'Astra', 'Harbor', 'Clove', 'Miks'],
    'Защитник':   ['Viper', 'Brimstone', 'Omen', 'Astra', 'Harbor', 'Clove', 'Miks'],
    'Страж':      ['Sage', 'Killjoy', 'Cypher', 'Chamber', 'Deadlock', 'Vyse', 'Veto'],
    'Sentinel':   ['Sage', 'Killjoy', 'Cypher', 'Chamber', 'Deadlock', 'Vyse', 'Veto'],
    'Дуэлянт':   ['Jett', 'Raze', 'Reyna', 'Phoenix', 'Neon', 'Iso', 'Yoru', 'Waylay'],
    'Duelist':    ['Jett', 'Raze', 'Reyna', 'Phoenix', 'Neon', 'Iso', 'Yoru', 'Waylay'],
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadFavoriteAgents();
  }

  Future<void> _loadFavoriteAgents() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('favorite_agents_${widget.mapName}');
    if (json != null && mounted) {
      setState(() => _favoriteAgents = Set<String>.from(jsonDecode(json) as List));
    }
  }

  Future<void> _toggleFavoriteAgent(String name) async {
    final newFavs = Set<String>.from(_favoriteAgents);
    if (newFavs.contains(name)) {
      newFavs.remove(name);
    } else {
      newFavs.add(name);
    }
    setState(() => _favoriteAgents = newFavs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_agents_${widget.mapName}', jsonEncode(newFavs.toList()));
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _hasError = false; });

    // ── Шаг 1: кэш агентов + Firestore параллельно ──────────────────────────
    final cachedAgents = await ValorantApi.getCached();

    // getDisabledAgents is error-safe — await independently so a failure
    // in the other Firestore queries doesn't prevent filtering from applying.
    final hiddenAgentsFuture = AgentsConfigService.getDisabledAgents();
    final disabledFuture = FirebaseFirestore.instance
        .collection('settings').doc('disabled_agents').get();
    final lineupsFuture = FirebaseFirestore.instance
        .collection('lineups')
        .where('map', isEqualTo: widget.mapName)
        .where('status', isEqualTo: 'approved')
        .where('category', isEqualTo: widget.category)
        .limit(200)
        .get();

    // All three futures run in parallel; hidden is set even if others fail.
    final hidden = await hiddenAgentsFuture;
    Map<String, int> counts = {};
    Set<String> disabled = {};

    try {
      final results = await Future.wait([disabledFuture, lineupsFuture]);
      final disabledDoc = results[0] as DocumentSnapshot;
      final lineupsSnap = results[1] as QuerySnapshot;

      for (final doc in lineupsSnap.docs) {
        final name = (doc.data() as Map)['agent'] as String? ?? '';
        counts[name] = (counts[name] ?? 0) + 1;
      }
      disabled = Set<String>.from(
        disabledDoc.exists
            ? List<String>.from(
            (disabledDoc.data() as Map? ?? {})['agents'] ?? [])
            : [],
      );
    } catch (_) {
      // Firestore ошибка — продолжаем с пустыми counts/disabled
    }

    // Показываем кэш немедленно, не ждём сеть
    if (cachedAgents != null && mounted) {
      setState(() {
        agents = AgentsConfigService.applyDisabled(cachedAgents, hidden);
        disabledAgents = disabled;
        lineupCounts = counts;
        loading = false;
      });
    }

    // ── Шаг 2: свежие данные из API ─────────────────────────────────────────
    try {
      final freshAgents = await ValorantApi.getAgents();
      final visibleAgents = AgentsConfigService.applyDisabled(freshAgents, hidden);
      if (mounted) {
        // Перерисовываем только если список агентов действительно изменился
        final currentNames = agents.map((a) => a['displayName']).toSet();
        final freshNames = visibleAgents.map((a) => a['displayName']).toSet();
        final changed = !currentNames.containsAll(freshNames) || !freshNames.containsAll(currentNames);
        if (changed || loading) {
          setState(() {
            agents = visibleAgents;
            disabledAgents = disabled;
            lineupCounts = counts;
            loading = false;
            _hasError = false;
          });
        }
        for (final agent in visibleAgents) {
          final icon = agent['displayIconSmall'] as String?;
          if (icon != null && icon.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(icon, cacheManager: AppImageCache.manager), context);
          }
          for (final ability in (agent['abilities'] as List? ?? [])) {
            final abilIcon = (ability as Map)['displayIcon'] as String?;
            if (abilIcon != null && abilIcon.isNotEmpty) {
              precacheImage(CachedNetworkImageProvider(abilIcon, cacheManager: AppImageCache.manager), context);
            }
          }
        }
      }
    } catch (_) {
      if (!mounted) return;
      if (agents.isEmpty) {
        setState(() { loading = false; _hasError = true; });
      }
    }
  }

  List<String> get _availableRoles {
    final seen = <String>{};
    final result = <String>[];
    for (final r in _roleOrder) {
      if (agents.any((a) => (a['role']?['displayName'] as String?) == r)) {
        if (seen.add(r)) result.add(r);
      }
    }
    for (final a in agents) {
      final role = a['role']?['displayName'] as String?;
      if (role != null && seen.add(role)) result.add(role);
    }
    return result;
  }

  List<Map<String, dynamic>> _applyFavoriteFilter(List<Map<String, dynamic>> list) {
    if (!_showOnlyFavorites) return list;
    return list.where((a) => _favoriteAgents.contains(a['displayName'] as String?)).toList();
  }

  List<Map<String, dynamic>> get _filteredAgents {
    var list = agents.where((a) {
      if (selectedRole == null) return true;
      return (a['role']?['displayName'] as String?) == selectedRole;
    }).toList();
    list = _applyFavoriteFilter(list);
    _sortAgents(list);
    return list;
  }

  void _sortAgents(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aName = a['displayName'] as String? ?? '';
      final bName = b['displayName'] as String? ?? '';
      final aRole = a['role']?['displayName'] as String?;

      final aDisabled = disabledAgents.contains(aName);
      final bDisabled = disabledAgents.contains(bName);
      if (aDisabled != bDisabled) return aDisabled ? 1 : -1;

      final aC = lineupCounts[aName] ?? 0;
      final bC = lineupCounts[bName] ?? 0;
      // Агенты с лайнапами — первые, без лайнапов — в конце роли
      if ((aC > 0) != (bC > 0)) return aC > 0 ? -1 : 1;

      // Внутри группы — жёстко заданный порядок по роли
      final order = aRole != null
          ? (_agentOrder[aRole] ?? const <String>[])
          : const <String>[];
      final aIdx = order.indexOf(aName);
      final bIdx = order.indexOf(bName);
      if (aIdx == -1 && bIdx == -1) return aName.compareTo(bName);
      if (aIdx == -1) return 1;
      if (bIdx == -1) return -1;
      return aIdx.compareTo(bIdx);
    });
  }

  void _openAgentScreen(String name, List<Map<String, dynamic>> abilities) {
    if (_lastOpenedAgent != name) {
      _navCount++;
      _lastOpenedAgent = name;
    }

    void navigate() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveMapScreen(
          mapName: widget.mapName,
          agentName: name,
          mapAsset: widget.mapAsset,
          abilities: abilities,
          category: widget.category,
        ),
      ),
    );

    if (_navCount % 5 == 0) {
      AdService.showInterstitial(onDismissed: () {
        if (mounted) navigate();
      });
    } else {
      navigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(widget.mapName.toUpperCase(),
            style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.star_rounded : Icons.star_border_rounded,
              color: _showOnlyFavorites ? Colors.amber : theme.primary,
            ),
            tooltip: _showOnlyFavorites ? 'Все агенты' : 'Только избранные',
            onPressed: () => setState(() => _showOnlyFavorites = !_showOnlyFavorites),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : _hasError
          ? _buildErrorScreen(theme)
          : Column(
        children: [
          // Фильтр по роли
          Container(
            color: theme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _roleChip('Все', '👥', selectedRole == null, theme,
                    () => setState(() => selectedRole = null)),
                ..._availableRoles.map((role) => _roleChip(
                  _roleDisplayName[role] ?? role,
                  _roleEmoji[role] ?? '⭐',
                  selectedRole == role,
                  theme,
                  () => setState(() => selectedRole = selectedRole == role ? null : role),
                )),
              ],
            ),
          ),

          // Сетка агентов
          Expanded(
            child: selectedRole != null
                ? (_filteredAgents.isEmpty
                ? Center(
                child: Text('Нет агентов',
                    style: TextStyle(
                        color: theme.textSecondary)))
                : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.62,
              ),
              itemCount: _filteredAgents.length,
              itemBuilder: (context, index) =>
                  _buildAgentCard(
                      _filteredAgents[index], theme),
            ))
                : _buildGroupedGrid(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(AppThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: theme.textSecondary, size: 64),
            const SizedBox(height: 20),
            Text(
              'Не удалось загрузить агентов',
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Проверь интернет-соединение.\nПопытки: 3 из 3 исчерпаны.',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() { loading = true; _hasError = false; });
                  _loadAll();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Попробовать снова',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent, AppThemeData theme) {
    final name = agent['displayName'] as String? ?? '';
    final iconUrl = agent['displayIconSmall'] as String? ?? '';
    final abilities =
    List<Map<String, dynamic>>.from(agent['abilities'] ?? []);
    final isDisabled = disabledAgents.contains(name);
    final count = lineupCounts[name] ?? 0;

    final isEmpty = !isDisabled && count == 0;

    return GestureDetector(
      onTap: isDisabled
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.noLineupsYet),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF1B2838),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF2d4a63)),
                  ),
                ),
              )
          : isEmpty
              ? () => AppSnackBar.show(context, AppLocalizations.of(context)!.noLineupsYet)
              : () => _openAgentScreen(name, abilities),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: Opacity(
                opacity: isDisabled ? 0.45 : (isEmpty ? 0.4 : 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDisabled ? theme.border : theme.primary,
                      width: 1,
                    ),
                  ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                            child: ColorFiltered(
                              colorFilter: isDisabled
                                  ? const ColorFilter.matrix([
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0,      0,      0,      1, 0,
                                    ])
                                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                              child: CachedNetworkImage(
                                imageUrl: iconUrl,
                                cacheManager: AppImageCache.manager,
                                fit: BoxFit.contain,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholder: (_, _) => const SizedBox.shrink(),
                                errorWidget: (_, _, _) => Icon(Icons.person, color: theme.textSecondary, size: 36),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 28,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: theme.border.withValues(alpha: 0.35), width: 0.5),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isDisabled ? theme.textSecondary : theme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isDisabled)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.lock, color: theme.textSecondary, size: 13),
                      ),
                    if (!isDisabled)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _toggleFavoriteAgent(name),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _favoriteAgents.contains(name) ? Icons.star_rounded : Icons.star_border_rounded,
                              color: _favoriteAgents.contains(name) ? Colors.amber : Colors.white70,
                              size: 28,
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
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDisabled || isEmpty)
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFF4FC3F7).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                isDisabled
                    ? '🔒 скоро'
                    : AppLocalizations.of(context)!.lineupCountLabel(count),
                style: TextStyle(
                  color: (isDisabled || isEmpty)
                      ? Colors.white38
                      : const Color(0xFF4FC3F7).withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedGrid(AppThemeData theme) {
    final seenRoles = <String>{};
    final orderedRoles = <String>[];

    for (final r in _roleOrder) {
      if (agents.any((a) => (a['role']?['displayName'] as String?) == r)) {
        if (seenRoles.add(r)) orderedRoles.add(r);
      }
    }
    for (final a in agents) {
      final role = a['role']?['displayName'] as String?;
      if (role != null && seenRoles.add(role)) orderedRoles.add(role);
    }

    if (orderedRoles.isEmpty) {
      final all = _applyFavoriteFilter(List<Map<String, dynamic>>.from(agents));
      _sortAgents(all);
      if (all.isEmpty) {
        return Center(
            child: Text('Нет агентов',
                style: TextStyle(color: theme.textSecondary)));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: all.length,
        itemBuilder: (ctx, i) => _buildAgentCard(all[i], theme),
      );
    }

    final slivers = <Widget>[];
    final usedNames = <String>{};

    for (final role in orderedRoles) {
      var roleAgents = _applyFavoriteFilter(agents
          .where((a) => (a['role']?['displayName'] as String?) == role)
          .toList());
      if (roleAgents.isEmpty) continue;
      _sortAgents(roleAgents);
      for (final a in roleAgents) {
        usedNames.add(a['displayName'] as String? ?? '');
      }

      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Text(_roleEmoji[role] ?? '⭐',
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                (_roleDisplayName[role] ?? role).toUpperCase(),
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: theme.border, thickness: 1)),
            ],
          ),
        ),
      ));

      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildAgentCard(roleAgents[i], theme),
            childCount: roleAgents.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
        ),
      ));
    }

    // Агенты без роли
    final ungrouped = _applyFavoriteFilter(agents
        .where((a) => !usedNames.contains(a['displayName'] as String? ?? ''))
        .toList());
    if (ungrouped.isNotEmpty) {
      _sortAgents(ungrouped);
      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildAgentCard(ungrouped[i], theme),
            childCount: ungrouped.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
        ),
      ));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return CustomScrollView(slivers: slivers);
  }

  Widget _roleChip(String label, String emoji, bool isSelected,
      AppThemeData theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary : theme.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? theme.primary : theme.border),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }



}