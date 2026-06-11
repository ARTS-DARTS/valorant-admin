import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'app_theme.dart';
import 'app_snack_bar.dart';

/// Экран обратной связи для пользователя.
/// Показывает список его сообщений + ответы от администратора.
/// На иконке в профиле отображается зелёный бейдж с количеством непрочитанных ответов.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final uid = AuthService.userId;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(AppLocalizations.of(context)!.feedbackTitle.toUpperCase(),
            style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 15)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primary,
          labelColor: theme.primary,
          unselectedLabelColor: theme.textSecondary,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.feedbackSendTab),
            Tab(
              child: uid == null
                  ? Text(AppLocalizations.of(context)!.feedbackMyMessages)
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('feedback')
                          .where('user_id', isEqualTo: uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.where((d) {
                              final data = d.data() as Map;
                              return data['reply'] != null &&
                                  (data['reply_read'] == false ||
                                      data['reply_read'] == null);
                            }).length ??
                            0;
                        final myMessages = AppLocalizations.of(context)!.feedbackMyMessages;
                        if (count == 0) return Text(myMessages);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(myMessages),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SendTab(theme: theme),
          _MyMessagesTab(theme: theme, uid: uid),
        ],
      ),
    );
  }
}

// ─── Вкладка "Отправить" ─────────────────────────────────────────────────────

class _SendTab extends StatefulWidget {
  final AppThemeData theme;
  const _SendTab({required this.theme});

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  final _textController = TextEditingController();
  String selectedCategory = 'предложение';
  bool loading = false;
  bool sent = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> categories = [
    {'id': 'баг', 'label': '🐛 Баг', 'color': Colors.red},
    {'id': 'предложение', 'label': '💡 Предложение', 'color': Colors.blue},
    {'id': 'другое', 'label': '💬 Другое', 'color': Colors.white54},
  ];

  Future<void> send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.show(context, 'Напиши что-нибудь!', type: SnackBarType.warning);
      return;
    }
    if (text.length > 2000) {
      AppSnackBar.show(context, 'Сообщение слишком длинное (макс. 2000 символов)', type: SnackBarType.warning);
      return;
    }

    setState(() => loading = true);

    try {
      final username = await AuthService.getUsername();
      final uid = AuthService.userId;

      await FirebaseFirestore.instance.collection('feedback').add({
        'text': text,
        'category': selectedCategory,
        'username': username ?? 'Аноним',
        'user_id': uid ?? '',
        'is_read': false,
        'reply': null,
        'reply_read': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() { loading = false; sent = true; });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    if (sent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            Text('Отзыв отправлен!',
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Спасибо за обратную связь',
                style: TextStyle(color: theme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                sent = false;
                _textController.clear();
              }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12)),
              child: const Text('Написать ещё',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Твой отзыв увидит только администратор. Пиши о багах, предложениях или чём угодно.',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Категория',
              style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: categories.map((cat) {
              final isSelected = selectedCategory == cat['id'];
              final color = cat['color'] as Color;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat['id']),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : theme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected ? color : theme.border,
                          width: isSelected ? 1.5 : 1),
                    ),
                    child: Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? color : theme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Text('Сообщение',
              style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            style: TextStyle(color: theme.textPrimary),
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Опиши проблему или идею подробно...',
              hintStyle: TextStyle(color: theme.textSecondary),
              filled: true,
              fillColor: theme.surface,
              counterStyle: TextStyle(color: theme.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.primary),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : send,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ОТПРАВИТЬ',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Вкладка "Мои сообщения" ─────────────────────────────────────────────────

class _MyMessagesTab extends StatelessWidget {
  final AppThemeData theme;
  final String? uid;

  const _MyMessagesTab({required this.theme, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Center(
        child: Text('Войди чтобы увидеть сообщения',
            style: TextStyle(color: theme.textSecondary)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: theme.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки',
                style: TextStyle(color: theme.textSecondary)),
          );
        }

        // Сортируем локально — не нужен составной индекс Firestore
        final docs = [...(snapshot.data?.docs ?? [])];
        docs.sort((a, b) {
          final aTime = (a.data() as Map)['created_at'];
          final bTime = (b.data() as Map)['created_at'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feedback_outlined,
                    color: theme.textSecondary, size: 48),
                const SizedBox(height: 12),
                Text('Ты ещё не отправлял отзывы',
                    style:
                        TextStyle(color: theme.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final text = data['text'] ?? '';
            final category = data['category'] ?? 'другое';
            final reply = data['reply'] as String?;
            final replyRead = data['reply_read'] as bool? ?? true;
            final hasNewReply = reply != null && !replyRead;

            Color categoryColor;
            switch (category) {
              case 'баг':
                categoryColor = Colors.red;
                break;
              case 'предложение':
                categoryColor = Colors.blue;
                break;
              default:
                categoryColor = Colors.white54;
            }

            return GestureDetector(
              onTap: () async {
                // Помечаем ответ прочитанным при открытии
                if (hasNewReply) {
                  await FirebaseFirestore.instance
                      .collection('feedback')
                      .doc(id)
                      .update({'reply_read': true});
                }
                if (context.mounted) {
                  _showDetail(context, text, reply, category, theme);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasNewReply ? Colors.green : theme.border,
                    width: hasNewReply ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: categoryColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                              color: categoryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: theme.textPrimary, fontSize: 13),
                      ),
                      trailing: hasNewReply
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: const Text(
                                'ОТВЕТ',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            )
                          : reply != null
                              ? Icon(Icons.mark_email_read,
                                  color: theme.textSecondary, size: 20)
                              : Icon(Icons.arrow_forward_ios,
                                  color: theme.textSecondary, size: 14),
                    ),
                    if (reply != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.admin_panel_settings,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(reply,
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, String text, String? reply,
      String category, AppThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Твоё сообщение',
                style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 10),
            Text(text,
                style: TextStyle(color: theme.textPrimary, fontSize: 14)),
            if (reply != null) ...[
              const SizedBox(height: 16),
              Text('Ответ администратора',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Text(reply,
                    style: const TextStyle(
                        color: Colors.green, fontSize: 14, height: 1.5)),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text('Ответ ещё не получен',
                  style:
                      TextStyle(color: theme.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Виджет-бейдж для иконки "Обратная связь" в профиле.
/// Показывает зелёную цифру непрочитанных ответов.
class FeedbackBadge extends StatelessWidget {
  const FeedbackBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) return const Icon(Icons.feedback_outlined);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.where((d) {
              final data = d.data() as Map;
              return data['reply'] != null &&
                  (data['reply_read'] == false || data['reply_read'] == null);
            }).length ??
            0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.feedback_outlined),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade300, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
