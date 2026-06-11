import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'collections_service.dart';
import 'guide_screen.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';

// ─── Экран "Мои коллекции" ────────────────────────────────────────────────────

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text('МОИ КОЛЛЕКЦИИ',
            style: TextStyle(
                color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: theme.primary),
            tooltip: 'Найти по коду',
            onPressed: () => _showFindByCodeDialog(context, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_collections',
        backgroundColor: theme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Новая коллекция', style: TextStyle(color: Colors.white)),
        onPressed: () => _showEditDialog(context, theme),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: CollectionsService.myCollections(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.collections_bookmark_outlined,
                      size: 64, color: theme.textSecondary),
                  const SizedBox(height: 16),
                  Text('Нет коллекций',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Создай коллекцию и добавляй лайнапы',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final lineupIds = List<String>.from(data['lineup_ids'] ?? []);
              return _CollectionCard(
                collectionId: doc.id,
                data: data,
                lineupCount: lineupIds.length,
                theme: theme,
                onEdit: () => _showEditDialog(context, theme,
                    collectionId: doc.id, existingTitle: data['title'] as String? ?? '',
                    existingDesc: data['description'] as String? ?? ''),
                onDelete: () => _confirmDelete(context, theme, doc.id),
                onShare: () => _showShareDialog(context, theme, data['share_code'] as String? ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CollectionDetailScreen(
                      collectionId: doc.id,
                      title: data['title'] as String? ?? 'Коллекция',
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

  void _showEditDialog(BuildContext context, AppThemeData theme,
      {String? collectionId, String existingTitle = '', String existingDesc = ''}) {
    final titleCtrl = TextEditingController(text: existingTitle);
    final descCtrl = TextEditingController(text: existingDesc);
    final isEdit = collectionId != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Редактировать' : 'Новая коллекция',
            style: TextStyle(color: theme.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.primary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: theme.textPrimary),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Описание (необязательно)',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.border)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              if (isEdit) {
                await CollectionsService.updateCollection(
                    collectionId: collectionId,
                    title: title,
                    description: descCtrl.text.trim());
              } else {
                await CollectionsService.createCollection(
                    title: title, description: descCtrl.text.trim());
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Создать',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppThemeData theme, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Удалить коллекцию?',
            style: TextStyle(color: theme.textPrimary)),
        content: Text('Это действие нельзя отменить.',
            style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              CollectionsService.deleteCollection(id);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, AppThemeData theme, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Поделиться', style: TextStyle(color: theme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Код коллекции:', style: TextStyle(color: theme.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primary),
              ),
              child: Text(
                code,
                style: TextStyle(
                    color: theme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 8),
            Text('Передай этот код другу чтобы он мог скопировать коллекцию',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFindByCodeDialog(BuildContext context, AppThemeData theme) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Найти по коду', style: TextStyle(color: theme.textPrimary)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: theme.textPrimary, fontSize: 22, letterSpacing: 4),
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'XXXXXX',
            hintStyle: TextStyle(color: theme.textSecondary),
            counterStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
            onPressed: () async {
              final code = ctrl.text.trim();
              if (code.length < 6) return;
              Navigator.pop(ctx);
              final doc = await CollectionsService.findByShareCode(code);
              if (!context.mounted) return;
              if (doc == null) {
                AppSnackBar.show(context, 'Коллекция не найдена', type: SnackBarType.error);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SharedCollectionScreen(source: doc),
                ),
              );
            },
            child: const Text('Найти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Карточка коллекции ───────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final String collectionId;
  final Map<String, dynamic> data;
  final int lineupCount;
  final AppThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.collectionId,
    required this.data,
    required this.lineupCount,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text('$lineupCount',
                    style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] as String? ?? '',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  if ((data['description'] as String? ?? '').isNotEmpty)
                    Text(data['description'] as String,
                        style: TextStyle(
                            color: theme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  Text('$lineupCount лайнапов',
                      style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: theme.surface,
              icon: Icon(Icons.more_vert, color: theme.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'share') onShare();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'edit',
                    child: Text('Редактировать',
                        style: TextStyle(color: theme.textPrimary))),
                PopupMenuItem(
                    value: 'share',
                    child: Text('Поделиться',
                        style: TextStyle(color: theme.textPrimary))),
                PopupMenuItem(
                    value: 'delete',
                    child: const Text('Удалить',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Детальный экран коллекции ────────────────────────────────────────────────

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;
  final String title;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(title.toUpperCase(),
            style: TextStyle(
                color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('collections')
            .doc(collectionId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(child: CircularProgressIndicator(color: theme.primary));
          }
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final lineupIds = List<String>.from(data['lineup_ids'] ?? []);

          if (lineupIds.isEmpty) {
            return Center(
              child: Text('Нет лайнапов в коллекции',
                  style: TextStyle(color: theme.textSecondary)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lineupIds.length,
            itemBuilder: (context, i) => _LineupTile(
              lineupId: lineupIds[i],
              collectionId: collectionId,
              theme: theme,
            ),
          );
        },
      ),
    );
  }
}

class _LineupTile extends StatelessWidget {
  final String lineupId;
  final String collectionId;
  final AppThemeData theme;

  const _LineupTile({
    required this.lineupId,
    required this.collectionId,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('lineups').doc(lineupId).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 56,
            decoration: BoxDecoration(
                color: theme.surface, borderRadius: BorderRadius.circular(8)),
          );
        }
        if (!snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        if (data['status'] == 'archived') return const SizedBox.shrink();
        final isExclusive = data['is_exclusive'] as bool? ?? false;
        final isOutdated  = data['is_outdated']  as bool? ?? false;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuideScreen(
                lineupId: lineupId,
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                ability: data['ability'] ?? '',
                mapName: data['map'] ?? '',
                agentName: data['agent'] ?? '',
                videoUrl: data['video_url'],
                screenshots: List<String>.from(data['screenshots'] ?? []),
                category: data['category'] ?? '',
                isExclusive: isExclusive,
                authorName: data['submitted_by'] as String?,
                authorId: data['user_id'] as String?,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOutdated ? Colors.orange.withValues(alpha: 0.5) : theme.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isExclusive)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text('⭐', style: TextStyle(fontSize: 12)),
                            ),
                          Expanded(
                            child: Text(
                              data['title'] ?? '',
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text('${data['agent']} • ${data['map']}',
                          style: TextStyle(
                              color: theme.textSecondary, fontSize: 12)),
                      if (isOutdated)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 11),
                              const SizedBox(width: 3),
                              Text('Устарел',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: Colors.red.shade400, size: 20),
                  onPressed: () => CollectionsService.removeLineupFromCollection(
                    collectionId: collectionId,
                    lineupId: lineupId,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Просмотр чужой коллекции по share_code ───────────────────────────────────

class SharedCollectionScreen extends StatelessWidget {
  final DocumentSnapshot source;

  const SharedCollectionScreen({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final data = source.data() as Map<String, dynamic>;
    final lineupIds = List<String>.from(data['lineup_ids'] ?? []);
    final title = data['title'] as String? ?? 'Коллекция';
    final desc = data['description'] as String? ?? '';

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(title.toUpperCase(),
            style: TextStyle(
                color: theme.primary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await CollectionsService.copyCollection(source);
              if (!context.mounted) return;
              AppSnackBar.show(context, 'Коллекция скопирована в "Мои коллекции"', type: SnackBarType.success);
              Navigator.pop(context);
            },
            icon: Icon(Icons.copy, color: theme.primary, size: 16),
            label:
                Text('Скопировать', style: TextStyle(color: theme.primary, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (desc.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: theme.surface, borderRadius: BorderRadius.circular(8)),
              child: Text(desc, style: TextStyle(color: theme.textSecondary)),
            ),
          Expanded(
            child: lineupIds.isEmpty
                ? Center(
                    child: Text('Коллекция пуста',
                        style: TextStyle(color: theme.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: lineupIds.length,
                    itemBuilder: (context, i) => _SharedLineupTile(
                      lineupId: lineupIds[i],
                      theme: theme,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SharedLineupTile extends StatelessWidget {
  final String lineupId;
  final AppThemeData theme;

  const _SharedLineupTile({required this.lineupId, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('lineups').doc(lineupId).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 56,
              decoration: BoxDecoration(
                  color: theme.surface, borderRadius: BorderRadius.circular(8)));
        }
        if (!snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        if (data['status'] == 'archived') return const SizedBox.shrink();
        final isExclusive = data['is_exclusive'] as bool? ?? false;
        final isOutdated  = data['is_outdated']  as bool? ?? false;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuideScreen(
                lineupId: lineupId,
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                ability: data['ability'] ?? '',
                mapName: data['map'] ?? '',
                agentName: data['agent'] ?? '',
                videoUrl: data['video_url'],
                screenshots: List<String>.from(data['screenshots'] ?? []),
                category: data['category'] ?? '',
                isExclusive: isExclusive,
                authorName: data['submitted_by'] as String?,
                authorId: data['user_id'] as String?,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOutdated ? Colors.orange.withValues(alpha: 0.5) : theme.border,
              ),
            ),
            child: Row(
              children: [
                if (isExclusive)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('⭐', style: TextStyle(fontSize: 12)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? '',
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${data['agent']} • ${data['map']}',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      if (isOutdated)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 11),
                              const SizedBox(width: 3),
                              Text('Устарел',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Диалог "Добавить в коллекцию" (вызывается из GuideScreen) ───────────────

class AddToCollectionDialog extends StatefulWidget {
  final String lineupId;

  const AddToCollectionDialog({super.key, required this.lineupId});

  @override
  State<AddToCollectionDialog> createState() => _AddToCollectionDialogState();
}

class _AddToCollectionDialogState extends State<AddToCollectionDialog> {
  Set<String> _inCollections = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final cols = await CollectionsService.collectionsContaining(widget.lineupId);
    if (mounted) {
      setState(() {
        _inCollections = cols.map((c) => c['id'] as String).toSet();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Добавить в коллекцию',
          style: TextStyle(color: theme.textPrimary, fontSize: 16)),
      content: _loading
          ? SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(color: theme.primary)))
          : StreamBuilder<QuerySnapshot>(
              stream: CollectionsService.myCollections(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(
                    'Нет коллекций. Создай коллекцию сначала.',
                    style: TextStyle(color: theme.textSecondary),
                  );
                }
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final isIn = _inCollections.contains(doc.id);
                      return CheckboxListTile(
                        title: Text(data['title'] as String? ?? '',
                            style: TextStyle(color: theme.textPrimary)),
                        value: isIn,
                        activeColor: theme.primary,
                        checkColor: Colors.white,
                        onChanged: (_) async {
                          if (isIn) {
                            await CollectionsService.removeLineupFromCollection(
                                collectionId: doc.id, lineupId: widget.lineupId);
                            if (mounted) {
                              setState(() => _inCollections.remove(doc.id));
                            }
                          } else {
                            await CollectionsService.addLineupToCollection(
                                collectionId: doc.id, lineupId: widget.lineupId);
                            if (mounted) {
                              setState(() => _inCollections.add(doc.id));
                            }
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
