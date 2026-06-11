import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'app_theme.dart';
import 'choose_username_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onRegistered;
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    required this.onCreateAccount,
    required this.onRegistered,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _passwordVisible = false;
  String? _errorText;

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text;

    if (nickname.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterNickname);
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterPassword);
      return;
    }

    setState(() { _loading = true; _errorText = null; });

    try {
      await AuthService.signInWithPassword(nickname, password);
      if (!mounted) return;
      widget.onLoggedIn();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          final l10n = AppLocalizations.of(context)!;
          switch (e.code) {
            case 'user-not-found':
              _errorText = l10n.userNotFound;
            case 'wrong-password':
            case 'invalid-credential':
              _errorText = l10n.wrongPassword;
            case 'operation-not-allowed':
              _errorText = l10n.loginFailed;
            case 'network-request-failed':
              _errorText = l10n.noInternet;
            default:
              _errorText = l10n.loginFailed;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _errorText = AppLocalizations.of(context)!.connectionError; });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _errorText = null; });
    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        // Пользователь отменил
        setState(() => _loading = false);
        return;
      }
      if (result) {
        // Новый пользователь — нужен выбор никнейма
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChooseUsernameScreen(onDone: widget.onRegistered),
          ),
        );
        if (mounted) setState(() => _loading = false);
      } else {
        // Существующий пользователь
        widget.onLoggedIn();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _errorText = AppLocalizations.of(context)!.googleLoginFailed; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text('VALORANT', style: TextStyle(color: theme.primary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              Text('LINEUPS', style: TextStyle(color: theme.textPrimary, fontSize: 20, letterSpacing: 8)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.appSubtitle, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              const SizedBox(height: 48),

              // ─── Переключатель Войти / Создать аккаунт ────────────────
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _AuthTab(label: AppLocalizations.of(context)!.signIn.toUpperCase(), selected: true, color: theme.primary)),
                    Expanded(
                      child: _AuthTab(
                        label: AppLocalizations.of(context)!.register.toUpperCase(),
                        selected: false,
                        color: theme.primary,
                        onTap: _loading ? null : widget.onCreateAccount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primary, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.welcome, style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(AppLocalizations.of(context)!.loginToAccount, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _nicknameController,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.nickname,
                        hintStyle: TextStyle(color: theme.textSecondary),
                        filled: true,
                        fillColor: theme.background,
                        prefixIcon: Icon(Icons.person_outline, color: theme.primary),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primary, width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      style: TextStyle(color: theme.textPrimary),
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.password,
                        hintStyle: TextStyle(color: theme.textSecondary),
                        filled: true,
                        fillColor: theme.background,
                        prefixIcon: Icon(Icons.lock_outline, color: theme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, color: theme.textSecondary),
                          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.primary, width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppLocalizations.of(context)!.signIn.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Разделитель
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(AppLocalizations.of(context)!.or, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: theme.border)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Google кнопка
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleLogo(),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.of(context)!.signInWithGoogle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  const _AuthTab({required this.label, required this.selected, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
