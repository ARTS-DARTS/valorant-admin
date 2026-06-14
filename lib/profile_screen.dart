import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'terms_screen.dart';
import 'level_system.dart';
import 'level_badge.dart';
import 'leaderboard_screen.dart';
import 'feedback_screen.dart';
import 'app_theme.dart';
import 'favorites_screen.dart';
import 'onboarding_screen.dart';
import 'app_snack_bar.dart';
import 'services/locale_service.dart';
import 'badge_widget.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onAccountDeleted;
  final VoidCallback onSignedOut;
  const ProfileScreen({
    super.key,
    required this.onAccountDeleted,
    required this.onSignedOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? username;
  int approvedLineups = 0;
  int totalLineups = 0;
  bool loading = false;
  int cooldownRemaining = 0;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final name = await AuthService.getUsername();
      final uid = AuthService.userId;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        final displayName = name ?? userDoc.data()?['name'] as String?;
        final createdAtValue = userDoc.data()?['created_at'];
        final createdAt = createdAtValue is Timestamp ? createdAtValue.toDate() : null;

        final byUserId = await FirebaseFirestore.instance
            .collection('lineups')
            .where('user_id', isEqualTo: uid)
            .get();

        final allDocs = <String, QueryDocumentSnapshot>{};
        for (final doc in byUserId.docs) {
          allDocs[doc.id] = doc;
        }
        if (displayName != null && displayName.isNotEmpty) {
          final byName = await FirebaseFirestore.instance
              .collection('lineups')
              .where('submitted_by', isEqualTo: displayName)
              .get();
          for (final doc in byName.docs) {
            allDocs[doc.id] = doc;
          }
        }

        final mergedLineups = allDocs.values.toList();
        final remaining = await AuthService.getCooldownRemainingMinutes();

        if (mounted) {
          setState(() {
            username = displayName;
            approvedLineups = mergedLineups
                .where((d) => d['status'] == 'approved')
                .length;
            totalLineups = mergedLineups.where((d) => d['status'] != 'archived').length;
            cooldownRemaining = remaining;
            _createdAt = createdAt;
          });
        }
      } else {
        if (mounted) setState(() => username = name);
      }
    } catch (e) {
      if (mounted) {
        final uid = AuthService.userId;
        final fallback = AppLocalizations.of(context)!.defaultPlayer;
        if (uid != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (mounted) setState(() => username = doc.data()?['name'] ?? fallback);
          } catch (_) {
            if (mounted) setState(() => username = fallback);
          }
        } else {
          setState(() => username = fallback);
        }
      }
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = AppThemeNotifier.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.signOutDialogTitle,
            style: TextStyle(color: theme.textPrimary, fontSize: 16)),
        content: Text(
          l10n.signOutDialogMessage,
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
            child: Text(l10n.signOutBtn,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onSignedOut();
    }
  }

  Future<void> deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(l10n.deleteAccountTitle,
                style: const TextStyle(color: Color(0xFFFF4655), fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountIrreversible,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              l10n.deleteAccountContent,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.deleteForever,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (mounted) setState(() => loading = true);

    try {
      final uid = AuthService.userId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete();

        final pendingLineups = await FirebaseFirestore.instance
            .collection('lineups')
            .where('user_id', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in pendingLineups.docs) {
          await doc.reference.delete();
        }

        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onAccountDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        AppSnackBar.show(context, AppLocalizations.of(context)!.errorOccurred, type: SnackBarType.error);
      }
    }
  }

  Future<void> _linkEmailPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = AppThemeNotifier.of(context);
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(l10n.linkEmailPassword,
                style: TextStyle(color: theme.primary, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.linkEmailDesc,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.newPassword,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.repeatPassword,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel,
                    style: TextStyle(color: theme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  final pass = passCtrl.text;
                  final confirm = confirmCtrl.text;
                  final dl10n = AppLocalizations.of(ctx)!;
                  if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
                    setDialogState(() => errorMsg = dl10n.fillAllFields);
                    return;
                  }
                  if (!email.contains('@')) {
                    setDialogState(() => errorMsg = dl10n.enterValidEmail);
                    return;
                  }
                  if (pass.length < 6) {
                    setDialogState(() => errorMsg = dl10n.passwordMinSixSymbols);
                    return;
                  }
                  if (pass != confirm) {
                    setDialogState(() => errorMsg = dl10n.passwordsMismatch);
                    return;
                  }
                  try {
                    await AuthService.linkEmailPassword(email, pass);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {});
                      AppSnackBar.show(context, AppLocalizations.of(context)!.emailPasswordLinked, type: SnackBarType.success);
                    }
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() {
                      errorMsg = e.code == 'email-already-in-use'
                          ? dl10n.emailAlreadyUsedByOther
                          : e.code == 'credential-already-in-use'
                              ? dl10n.emailAlreadyLinked
                              : dl10n.errorOccurred;
                    });
                  }
                },
                child: Text(l10n.link,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    } finally {
      emailCtrl.dispose();
      passCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = AppThemeNotifier.of(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMsg;

    try {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(l10n.changePassword,
                style: TextStyle(color: theme.primary, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.currentPassword,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.newPassword,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: l10n.repeatNewPassword,
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.border),
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.primary),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(errorMsg!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel,
                    style: TextStyle(color: theme.textSecondary)),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: theme.primary),
                onPressed: () async {
                  final current = currentCtrl.text;
                  final newPass = newCtrl.text;
                  final confirm = confirmCtrl.text;
                  final dl10n = AppLocalizations.of(ctx)!;
                  if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                    setDialogState(() => errorMsg = dl10n.fillAllFields);
                    return;
                  }
                  if (newPass.length < 6) {
                    setDialogState(() => errorMsg = dl10n.newPasswordMinSix);
                    return;
                  }
                  if (newPass != confirm) {
                    setDialogState(() => errorMsg = dl10n.passwordsMismatch);
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser!;
                    final cred = EmailAuthProvider.credential(
                        email: user.email!, password: current);
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPass);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      AppSnackBar.show(context, AppLocalizations.of(context)!.passwordChanged, type: SnackBarType.success);
                    }
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() {
                      errorMsg =
                          e.code == 'wrong-password' ||
                                  e.code == 'invalid-credential'
                              ? dl10n.currentPasswordWrong
                              : dl10n.errorOccurred;
                    });
                  }
                },
                child: Text(l10n.change,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  void _showThemePicker() {
    final l10n = AppLocalizations.of(context)!;
    final notifier = AppThemeNotifier.notifierOf(context);
    final currentTheme = AppThemeNotifier.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            AppThemeData selected = notifier?.value ?? AppThemes.standard;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appTheme,
                      style: TextStyle(
                          color: currentTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 16),
                  ...AppThemes.all.map((t) {
                    final isSelected = selected.type == t.type;
                    return GestureDetector(
                      onTap: () async {
                        setSheetState(() => selected = t);
                        notifier?.value = t;
                        await AppThemes.save(t.type);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? t.primary.withValues(alpha: 0.15)
                              : currentTheme.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSelected ? t.primary : currentTheme.border,
                              width: isSelected ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            Text(t.emoji,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(t.name,
                                  style: TextStyle(
                                      color: isSelected
                                          ? t.primary
                                          : currentTheme.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14)),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle,
                                  color: t.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context)!;
    final theme = AppThemeNotifier.of(context);
    final currentCode = LocaleService.currentCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.languageTitle,
                  style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 16),
              ...LocaleService.supportedLanguages.map((lang) {
                final isSelected = lang['code'] == currentCode;
                return GestureDetector(
                  onTap: () async {
                    await LocaleService.setLocale(lang['code']!);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primary.withValues(alpha: 0.15)
                          : theme.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected ? theme.primary : theme.border,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Text(lang['flag']!,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(lang['name']!,
                              style: TextStyle(
                                  color: isSelected
                                      ? theme.primary
                                      : theme.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14)),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: theme.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          ),
          ),
        );
      },
    );
  }

  bool get _isPioneer =>
      _createdAt != null && _createdAt!.isBefore(DateTime(2026, 6, 1));

  void _showPioneerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B3B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: const Color(0xFF6C3FE8).withValues(alpha: 0.6)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡',
                style: TextStyle(fontSize: 28, color: Color(0xFF00D4FF))),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6C3FE8), Color(0xFF00D4FF)],
              ).createShader(bounds),
              child: const Text('PIONEER',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            Text(
              'Вы стояли у истоков. Один из немногих, кто был призван в закрытое тестирование ещё до того, как мир узнал об этом приложении.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Выдаётся навсегда · Нельзя получить сейчас',
              style: TextStyle(
                  color: const Color(0xFF6C3FE8).withValues(alpha: 0.7),
                  fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(color: Color(0xFF6C3FE8))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = AppThemeNotifier.of(context);
    final levelData = LevelSystem.getLevel(approvedLineups);
    final nextLevel = LevelSystem.getNextLevel(approvedLineups);
    final progress = LevelSystem.getProgress(approvedLineups);
    final color = Color(levelData['color'] as int);
    final isAnimated = levelData['animated'] as bool;
    final cooldown = LevelSystem.getCooldownMinutes(approvedLineups);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(l10n.profileTitle.toUpperCase(),
            style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          _NotificationBell(theme: theme),
          IconButton(
            icon: Icon(Icons.leaderboard, color: theme.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen()),
            ),
            tooltip: l10n.topAuthors,
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : username == null
              ? Center(
                  child: CircularProgressIndicator(color: theme.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Avatar
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isAnimated)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.9, end: 1.05),
                              duration: const Duration(seconds: 2),
                              builder: (context, value, child) =>
                                  Transform.scale(
                                      scale: value, child: child),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: color, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 20,
                                        spreadRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                levelData['icon'] as String,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            username!,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          if (AuthService.userId != null)
                            UserBadgeRow(uid: AuthService.userId!, size: 16),
                        ],
                      ),
                      const SizedBox(height: 6),

                      LevelBadge(
                        approvedLineups: approvedLineups,
                        animated: isAnimated,
                        large: true,
                      ),
                      if (_isPioneer) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showPioneerDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C3FE8), Color(0xFF00D4FF)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C3FE8)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Text(
                              '⚡ PIONEER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Progress bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.approvedCount(approvedLineups),
                                  style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 13),
                                ),
                                if (nextLevel != null)
                                  Text(
                                    l10n.toNextLevel(
                                      nextLevel['name'] as String,
                                      (nextLevel['minLineups'] as int) - approvedLineups,
                                    ),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  )
                                else
                                  Text(l10n.maximum,
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white12,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                              child: _statCard('✅', l10n.approvedStat,
                                  '$approvedLineups', Colors.green, theme)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _statCard('📨', l10n.totalStat,
                                  '$totalLineups', Colors.blue, theme)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _statCard(
                                  '⏱', l10n.cooldownStat, '${cooldown}м', color, theme)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (cooldownRemaining > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer,
                                  color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                l10n.nextLineupIn(cooldownRemaining),
                                style: const TextStyle(
                                    color: Colors.orange, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Level privileges
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.levelPrivileges,
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 10),
                            _perk('⏱', l10n.cooldownMinutes(cooldown), theme),
                            _perk('🎨', l10n.borderColor(levelData['name'] as String), theme),
                            if (isAnimated)
                              _perk('✨', l10n.animatedProfile, theme),
                            _perk('🏆', l10n.topAuthorPosition, theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // All levels
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.allLevels,
                                style: TextStyle(
                                    color: theme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 10),
                            ...LevelSystem.levels.map((lvl) {
                              final lvlColor = Color(lvl['color'] as int);
                              final isCurrentLevel =
                                  lvl['level'] == levelData['level'];
                              final isUnlocked = approvedLineups >=
                                  (lvl['minLineups'] as int);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Text(lvl['icon'] as String,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                lvl['name'] as String,
                                                style: TextStyle(
                                                  color: isUnlocked
                                                      ? lvlColor
                                                      : Colors.white24,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (isCurrentLevel)
                                                Container(
                                                  margin: const EdgeInsets
                                                      .only(left: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: lvlColor
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(4),
                                                  ),
                                                  child: Text(l10n.currentLevel,
                                                      style: TextStyle(
                                                          color: lvlColor,
                                                          fontSize: 10)),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            l10n.levelRequirements(
                                              lvl['minLineups'] as int,
                                              lvl['cooldownMinutes'] as int,
                                            ),
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isUnlocked)
                                      const Icon(Icons.lock,
                                          color: Colors.white24, size: 16),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Menu ───────────────────────────────────────────────

                      _menuItem(
                        icon: Icons.leaderboard,
                        title: l10n.topAuthors,
                        theme: theme,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const LeaderboardScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.bookmark_border,
                        title: l10n.favorites,
                        theme: theme,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const FavoritesScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.palette_outlined,
                        title: l10n.appTheme,
                        theme: theme,
                        trailing: Text(
                          AppThemeNotifier.of(context).emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        onTap: _showThemePicker,
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.language,
                        title: l10n.language,
                        theme: theme,
                        trailing: Text(
                          LocaleService.supportedLanguages.firstWhere(
                            (lang) => lang['code'] == LocaleService.currentCode,
                            orElse: () => LocaleService.supportedLanguages.first,
                          )['flag']!,
                          style: const TextStyle(fontSize: 18),
                        ),
                        onTap: _showLanguagePicker,
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: AuthService.hasEmailProvider()
                            ? Icons.lock_outline
                            : Icons.link,
                        title: AuthService.hasEmailProvider()
                            ? l10n.changePassword
                            : l10n.linkEmailPassword,
                        theme: theme,
                        onTap: AuthService.hasEmailProvider()
                            ? _changePassword
                            : _linkEmailPassword,
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.description_outlined,
                        title: l10n.termsOfService,
                        theme: theme,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TermsScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.info_outline,
                        title: l10n.aboutApp,
                        theme: theme,
                        onTap: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: theme.surface,
                            title: Text('Valorant Lineups',
                                style:
                                    TextStyle(color: theme.primary)),
                            content: Text(
                              l10n.aboutAppContent,
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l10n.ok,
                                    style:
                                        TextStyle(color: theme.primary)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.language,
                        title: '🌐 Загрузить лайнап на сайте',
                        theme: theme,
                        onTap: () async {
                          final uri = Uri.parse('https://vlineups.com');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.feedback_outlined,
                        title: l10n.feedback,
                        theme: theme,
                        trailingWidget: const FeedbackBadgeInline(),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const FeedbackScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.school_outlined,
                        title: l10n.viewTutorial,
                        theme: theme,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OnboardingScreen(
                              onDone: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _menuItem(
                        icon: Icons.logout,
                        title: l10n.signOutMenuTitle,
                        theme: theme,
                        onTap: _signOut,
                      ),
                      const SizedBox(height: 24),

                      // Account deletion danger zone
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.dangerZone,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.dangerZoneDesc,
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: deleteAccount,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                child: Text(l10n.deleteMyAccount.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color,
      AppThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: TextStyle(
                  color: theme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _perk(String emoji, String text, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: theme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required AppThemeData theme,
    Widget? trailing,
    Widget? trailingWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: theme.textPrimary, fontSize: 14))),
            ?trailingWidget,
            ?trailing,
            if (trailing == null && trailingWidget == null)
              Icon(Icons.arrow_forward_ios,
                  color: theme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Notification bell in profile AppBar
class _NotificationBell extends StatelessWidget {
  final AppThemeData theme;
  const _NotificationBell({required this.theme});

  Future<void> _open(BuildContext context) async {
    final uid = AuthService.userId;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('created_at', descending: true)
        .get();

    for (final doc in snap.docs) {
      if ((doc.data()['is_read'] as bool? ?? false) == false) {
        await doc.reference.update({'is_read': true});
      }
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _NotificationsSheet(docs: snap.docs, theme: theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('is_read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: theme.primary),
              onPressed: () => _open(context),
              tooltip: AppLocalizations.of(context)!.notifications,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final AppThemeData theme;
  const _NotificationsSheet({required this.docs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.notifications,
              style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 16),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(l10n.noNotifications,
                    style: TextStyle(color: theme.textSecondary)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final body = data['body'] as String? ?? '';
                  final createdAt =
                      (data['created_at'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(body,
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 13)),
                        if (createdAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${createdAt.day}.${createdAt.month}.${createdAt.year}',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Unread reply badge for menu row
class FeedbackBadgeInline extends StatelessWidget {
  const FeedbackBadgeInline({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) return const SizedBox.shrink();

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

        if (count == 0) {
          return Icon(Icons.arrow_forward_ios,
              color: AppThemeNotifier.of(context).textSecondary, size: 14);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade300, width: 1.5),
          ),
          child: Text(
            AppLocalizations.of(context)!.newCount(count),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
