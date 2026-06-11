import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guide_screen.dart';
import 'app_theme.dart';
import 'exclusive_service.dart';
import 'ad_service.dart';
import 'app_snack_bar.dart';

class LineupScreen extends StatelessWidget {
  final String mapName;
  final String agentName;
  final String category;
  const LineupScreen({
    super.key,
    required this.mapName,
    required this.agentName,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text('$agentName — $mapName'.toUpperCase(),
            style: TextStyle(color: t.primary, fontWeight: FontWeight.bold,
                letterSpacing: 1, fontSize: 14)),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lineups')
            .where('map', isEqualTo: mapName)
            .where('agent', isEqualTo: agentName)
            .where('status', isEqualTo: 'approved')
            .where('category', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: t.primary));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, color: t.border, size: 56),
                  const SizedBox(height: 12),
                  Text('Лайнапов пока нет',
                      style: TextStyle(color: t.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final screenshots = List<String>.from(data['screenshots'] ?? []);
              final likesCount = data['likes_count'] as int? ?? 0;
              final isExclusive = data['is_exclusive'] as bool? ?? false;
              return GestureDetector(
                onTap: () async {
                  if (isExclusive) {
                    final hasAccess = await ExclusiveService.hasAccess();
                    if (!context.mounted) return;
                    if (!hasAccess) {
                      _showExclusiveDialog(
                        context, t, doc.id, data, screenshots, mapName, agentName, category,
                      );
                      return;
                    }
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuideScreen(
                        lineupId: doc.id,
                        title: data['title'] ?? '',
                        description: data['description'] ?? '',
                        ability: data['ability'] ?? '',
                        mapName: mapName,
                        agentName: agentName,
                        videoUrl: data['video_url'],
                        screenshots: screenshots,
                        category: category,
                        isExclusive: isExclusive,
                        authorName: data['submitted_by'] as String?,
                        authorId: data['user_id'] as String?,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExclusive ? Colors.amber : t.primary,
                      width: isExclusive ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Row(
                      children: [
                        if (isExclusive) ...[
                          const Text('👑', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(data['title'] ?? '',
                              style: TextStyle(color: t.textPrimary,
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(data['description'] ?? '',
                          style: TextStyle(color: t.textSecondary, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: t.primary),
                          ),
                          child: Text(data['ability'] ?? '',
                              style: TextStyle(
                                  color: t.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (likesCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite,
                                  color: t.primary, size: 12),
                              const SizedBox(width: 3),
                              Text('$likesCount',
                                  style: TextStyle(
                                      color: t.primary, fontSize: 11)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showExclusiveDialog(
  BuildContext context,
  AppThemeData t,
  String lineupId,
  Map<String, dynamic> data,
  List<String> screenshots,
  String mapName,
  String agentName,
  String category,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('👑 Эксклюзивный лайнап',
          style: TextStyle(color: t.primary, fontSize: 16)),
      content: Text(
        'Посмотри рекламу чтобы открыть доступ на 1 час',
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

  if (result != true || !context.mounted) return;

  if (!AdService.isRewardedReady) {
    if (context.mounted) {
      AppSnackBar.show(context, 'Реклама загружается, попробуй через секунду...', type: SnackBarType.warning);
    }
    return;
  }

  AdService.showRewarded(
    onRewarded: () async {
      await ExclusiveService.grantAccess();
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuideScreen(
            lineupId: lineupId,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            ability: data['ability'] ?? '',
            mapName: mapName,
            agentName: agentName,
            videoUrl: data['video_url'],
            screenshots: screenshots,
            category: category,
            isExclusive: true,
            authorName: data['submitted_by'] as String?,
            authorId: data['user_id'] as String?,
          ),
        ),
      );
    },
    onDismissed: () {
      if (context.mounted) {
        AppSnackBar.show(context, 'Досмотри рекламу до конца чтобы получить доступ', type: SnackBarType.error);
      }
    },
    onNotReady: () {
      if (context.mounted) {
        AppSnackBar.show(context, 'Реклама недоступна, попробуй позже', type: SnackBarType.warning);
      }
    },
  );
}
