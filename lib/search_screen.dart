import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guide_screen.dart';
import 'app_theme.dart';

const _kLineupCategories = <Map<String, dynamic>>[
  {'key': 'lineup', 'emoji': '🎯', 'name': 'Лайнапы'},
  {'key': 'combo',  'emoji': '⚡', 'name': 'Комбо'},
  {'key': 'meta',   'emoji': '👑', 'name': 'Мета'},
  {'key': 'smoke',  'emoji': '💨', 'name': 'Смоки'},
  {'key': 'defense','emoji': '🛡', 'name': 'Защита'},
];

String _categoryEmoji(String? key) {
  for (final c in _kLineupCategories) {
    if (c['key'] == key) return c['emoji'] as String;
  }
  return '📌';
}

String _categoryName(String? key) {
  for (final c in _kLineupCategories) {
    if (c['key'] == key) return c['name'] as String;
  }
  return key ?? '';
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _allLineups = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLineups();
    _ctrl.addListener(_filter);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_filter);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadLineups() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('lineups')
          .where('status', isEqualTo: 'approved')
          .limit(500)
          .get();
      final lineups =
          snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      if (!mounted) return;
      setState(() {
        _allLineups = lineups;
        _results = lineups.take(10).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = _allLineups.take(10).toList());
      return;
    }
    setState(() {
      _results = _allLineups.where((l) {
        return (l['title'] as String? ?? '').toLowerCase().contains(q) ||
            (l['description'] as String? ?? '').toLowerCase().contains(q) ||
            (l['agent'] as String? ?? '').toLowerCase().contains(q) ||
            (l['map'] as String? ?? '').toLowerCase().contains(q) ||
            (l['ability'] as String? ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        iconTheme: IconThemeData(color: t.primary),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchLineups,
            hintStyle: TextStyle(color: t.textSecondary),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: t.textSecondary),
              onPressed: () {
                _ctrl.clear();
                _filter();
              },
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, color: t.border, size: 56),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.nothingFound,
                          style:
                              TextStyle(color: t.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final l = _results[i];
                    final catKey = l['category'] as String? ?? '';
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuideScreen(
                            lineupId: l['id'] as String? ?? '',
                            title: l['title'] ?? '',
                            description: l['description'] ?? '',
                            ability: l['ability'] ?? '',
                            mapName: l['map'] ?? '',
                            agentName: l['agent'] ?? '',
                            videoUrl: l['video_url'],
                            screenshots:
                                List<String>.from(l['screenshots'] ?? []),
                            category: catKey,
                            authorName: l['submitted_by'] as String?,
                            authorId: l['user_id'] as String?,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.primary, width: 1),
                        ),
                        child: ListTile(
                          title: Text(l['title'] ?? '',
                              style: TextStyle(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l['agent']} • ${l['map']} • ${l['ability']}',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 12),
                              ),
                              if (catKey.isNotEmpty)
                                Text(
                                  '${_categoryEmoji(catKey)} ${_categoryName(catKey)}',
                                  style: TextStyle(
                                      color: t.textSecondary, fontSize: 11),
                                ),
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios,
                              color: t.textSecondary, size: 14),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
