import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'guide_screen.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';
import 'fcm_service.dart';

class ModeratorScreen extends StatefulWidget {
  const ModeratorScreen({super.key});

  @override
  State<ModeratorScreen> createState() => _ModeratorScreenState();
}

class _ModeratorScreenState extends State<ModeratorScreen> {
  String _moderatorName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await AuthService.getUsername() ?? 'Модератор';
    if (mounted) setState(() => _moderatorName = name);
  }

  void _logout() => Navigator.pop(context);

  Future<void> _approveLineup(
      String id, Map<String, dynamic> data) async {
    try {
      final userId = data['user_id'] as String?;
      final title = data['title'] as String? ?? '';
      await FirebaseFirestore.instance
          .collection('lineups')
          .doc(id)
          .update({'status': 'approved'});
      if (userId != null && userId.isNotEmpty) {
        await AuthService.incrementApprovedLineups(userId);
        FcmService.notifyLineupApproved(userId, title).ignore();
      }
      _snack('Лайнап одобрен ✅', Colors.green);
    } catch (e) {
      _snack('Что-то пошло не так. Попробуйте ещё раз', Colors.orange);
    }
  }

  Future<void> _rejectLineup(
      String id, Map<String, dynamic> data) async {
    try {
      final userId = data['user_id'] as String?;
      final title = data['title'] as String? ?? '';
      await FirebaseFirestore.instance
          .collection('lineups')
          .doc(id)
          .update({'status': 'rejected'});
      if (userId != null && userId.isNotEmpty) {
        FcmService.notifyLineupRejected(userId, title).ignore();
      }
      _snack('Лайнап отклонён', Colors.orange);
    } catch (e) {
      _snack('Что-то пошло не так. Попробуйте ещё раз', Colors.red);
    }
  }

  Future<void> _replyFeedback(String id, String feedbackText) async {
    final t = AppThemeNotifier.of(context);
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Text('Ответить пользователю',
              style: TextStyle(color: t.primary, fontSize: 15)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: t.textPrimary),
            maxLines: 4,
            maxLength: 300,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Напиши ответ...',
              hintStyle: TextStyle(color: t.textSecondary),
              counterStyle: TextStyle(color: t.textSecondary),
              filled: true,
              fillColor: t.background,
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.border),
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.primary),
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style: TextStyle(color: t.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: t.primary),
              child: const Text('Отправить',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (result != null && result.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('feedback')
            .doc(id)
            .update({
          'reply': result,
          'reply_read': false,
          'is_read': true,
        });
        _snack('Ответ отправлен ✅', Colors.green);
      }
    } finally {
      controller.dispose();
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    final type = color == Colors.green
        ? SnackBarType.success
        : color == Colors.red
            ? SnackBarType.error
            : SnackBarType.warning;
    AppSnackBar.show(context, msg, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          backgroundColor: t.surface,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('МОДЕРАТОР',
                  style: TextStyle(
                      color: t.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 14)),
              Text(_moderatorName,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 11)),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout,
                  color: Colors.red, size: 18),
              label: const Text('Выйти',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
          bottom: TabBar(
            indicatorColor: t.primary,
            labelColor: t.primary,
            unselectedLabelColor: t.textSecondary,
            tabs: const [
              Tab(text: 'ЛАЙНАПЫ'),
              Tab(text: 'ПОДДЕРЖКА'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _lineupsTab(t),
            _feedbackTab(t),
          ],
        ),
      ),
    );
  }

  Widget _lineupsTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lineups')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(color: t.primary));
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      color: t.border, size: 48),
                  const SizedBox(height: 12),
                  Text('Нет лайнапов на проверке',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 15)),
                ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final title = data['title'] as String? ?? '';
            final submittedBy =
                data['submitted_by'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuideScreen(
                          lineupId: id,
                          title: data['title'] ?? '',
                          description: data['description'] ?? '',
                          ability: data['ability'] ?? '',
                          mapName: data['map'] ?? '',
                          agentName: data['agent'] ?? '',
                          videoUrl: data['video_url'] as String?,
                          screenshots: List<String>.from(data['screenshots'] ?? []),
                          category: data['category'] ?? '',
                          isExclusive: data['is_exclusive'] as bool? ?? false,
                          authorName: data['submitted_by'] as String?,
                          authorId: data['user_id'] as String?,
                        ),
                      ),
                    ),
                    child: ListTile(
                      title: Text(title,
                          style: TextStyle(
                              color: t.textPrimary,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['map']} • ${data['agent']} • ${data['ability']}',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 12),
                          ),
                          if (submittedBy.isNotEmpty)
                            Text('👤 $submittedBy',
                                style: TextStyle(
                                    color: t.primary, fontSize: 12)),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: t.textSecondary),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _approveLineup(id, data),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: const Text('Одобрить',
                                style: TextStyle(
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _rejectLineup(id, data),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Отклонить',
                                style: TextStyle(
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _feedbackTab(AppThemeData t) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('is_read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(color: t.primary));
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feedback_outlined,
                      color: t.border, size: 48),
                  const SizedBox(height: 12),
                  Text('Нет непрочитанных обращений',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 16)),
                ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final text = data['text'] as String? ?? '';
            final category =
                data['category'] as String? ?? 'другое';
            final username =
                data['username'] as String? ?? 'Аноним';
            final reply = data['reply'] as String?;

            Color catColor;
            IconData catIcon;
            switch (category) {
              case 'баг':
                catColor = Colors.red;
                catIcon = Icons.bug_report;
                break;
              case 'предложение':
                catColor = Colors.blue;
                catIcon = Icons.lightbulb_outline;
                break;
              default:
                catColor = t.textSecondary;
                catIcon = Icons.chat_bubble_outline;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: catColor, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 4, 4),
                    child: Row(
                      children: [
                        Icon(catIcon,
                            color: catColor, size: 20),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(4),
                            border: Border.all(
                                color: catColor.withValues(
                                    alpha: 0.5)),
                          ),
                          child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 9,
                                  fontWeight:
                                      FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('👤 $username',
                              style: TextStyle(
                                  color: t.primary,
                                  fontSize: 12),
                              overflow:
                                  TextOverflow.ellipsis),
                        ),
                        if (reply == null)
                          IconButton(
                            icon: const Icon(Icons.reply,
                                color: Colors.green,
                                size: 20),
                            onPressed: () =>
                                _replyFeedback(id, text),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 8),
                    child: Text(text,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 14,
                            height: 1.4)),
                  ),
                  if (reply != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield,
                                color: Colors.green,
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(reply,
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                        height: 1.4))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
