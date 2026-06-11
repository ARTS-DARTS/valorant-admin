import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'auth_service.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final uid = AuthService.userId;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text('МОИ ПОДПИСКИ',
            style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: uid == null
          ? Center(
              child: Text('Войди чтобы видеть подписки',
                  style: TextStyle(color: theme.textSecondary)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('subscriptions')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: theme.primary));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            color: theme.textSecondary, size: 64),
                        const SizedBox(height: 16),
                        Text('Нет подписок',
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Открой любой лайнап и нажми 🔔',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 13)),
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
                    final agent = data['agent'] as String? ?? '';
                    final map   = data['map']   as String? ?? '';
                    final type  = data['type']  as String? ?? 'agent_map';

                    final String label = switch (type) {
                      'agent' => agent,
                      'map'   => map,
                      _       => '$agent — $map',
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: theme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400, size: 20),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
