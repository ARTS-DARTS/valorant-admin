import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'terms_screen.dart';
import 'app_theme.dart';
import 'choose_username_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback? onLoginInstead;
  const RegistrationScreen({super.key, required this.onRegistered, this.onLoginInstead});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // Step 1 = theme, Step 2 = nickname, Step 3 = password
  int _step = 1;

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool loading = false;
  bool termsAccepted = false;
  String? errorText;
  bool? nameAvailable;
  bool checkingName = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _nameController.text.trim();
    setState(() {
      errorText = null;
      nameAvailable = null;
    });
    if (isValidName(name)) _checkNameDebounced(name);
  }

  String? _lastChecked;

  void _checkNameDebounced(String name) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_nameController.text.trim() != name) return;
    if (_lastChecked == name) return;
    _lastChecked = name;
    setState(() => checkingName = true);
    try {
      final taken = await isNameTaken(name);
      if (!mounted) return;
      if (_nameController.text.trim() != name) return;
      setState(() {
        nameAvailable = !taken;
        checkingName = false;
      });
    } catch (_) {
      if (mounted) setState(() => checkingName = false);
    }
  }

  Future<bool> isNameTaken(String name) async {
    final normalized = name.toLowerCase().trim();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('name_lower', isEqualTo: normalized)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  bool isValidName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 20) return false;
    final regex = RegExp(r'^[a-zA-Zа-яА-ЯёЁ0-9_\- ]+$');
    return regex.hasMatch(trimmed);
  }

  Future<void> _signInWithGoogle() async {
    setState(() { loading = true; errorText = null; });
    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        setState(() => loading = false);
        return;
      }
      if (result) {
        // New user — choose nickname
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChooseUsernameScreen(onDone: widget.onRegistered),
          ),
        );
        if (mounted) setState(() => loading = false);
      } else {
        // Already registered via Google
        widget.onRegistered();
      }
    } catch (e) {
      if (mounted) setState(() { loading = false; errorText = AppLocalizations.of(context)!.googleLoginFailed; });
    }
  }

  Future<void> _validateAndProceed() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();

    if (!termsAccepted) {
      setState(() => errorText = l10n.mustAcceptTerms);
      return;
    }
    if (!isValidName(name)) {
      setState(() => errorText = l10n.nameRules);
      return;
    }
    if (nameAvailable == false) {
      setState(() => errorText = l10n.nameTaken);
      return;
    }

    if (nameAvailable == null) {
      setState(() {
        loading = true;
        errorText = null;
      });
      try {
        final taken = await isNameTaken(name);
        if (!mounted) return;
        if (taken) {
          setState(() {
            loading = false;
            nameAvailable = false;
            errorText = AppLocalizations.of(context)!.nameTaken;
          });
          return;
        }
        setState(() {
          loading = false;
          nameAvailable = true;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            loading = false;
            errorText = AppLocalizations.of(context)!.nameCheckError;
          });
        }
        return;
      }
    }

    setState(() {
      _step = 3;
      errorText = null;
    });
  }

  Future<void> register() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      setState(() => errorText = l10n.passwordMinSix);
      return;
    }
    if (password != confirm) {
      setState(() => errorText = l10n.passwordsMismatch);
      return;
    }

    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      await AuthService.registerWithPassword(name, password);
      if (!mounted) return;
      widget.onRegistered();
    } on NameTakenException {
      if (mounted) {
        setState(() {
          loading = false;
          nameAvailable = false;
          errorText = AppLocalizations.of(context)!.nameTaken;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        setState(() {
          loading = false;
          errorText = switch (e.code) {
            'weak-password' => l.passwordTooSimple,
            'email-already-in-use' => l.emailAlreadyInUse,
            'network-request-failed' => l.noInternet,
            _ => l.accountCreationFailed,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          errorText = AppLocalizations.of(context)!.accountCreationFailed;
        });
      }
    }
  }

  Color get _borderColor {
    if (errorText != null) return Colors.red;
    if (nameAvailable == true) return Colors.green;
    if (nameAvailable == false) return Colors.red;
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: _step == 1
            ? _buildThemePicker(theme)
            : _step == 2
                ? _buildNicknameForm(theme)
                : _buildPasswordForm(theme),
      ),
    );
  }

  // ─── Tab switcher ────────────────────────────────────────────────────────

  Widget _authTab(String label, {required bool selected, required AppThemeData theme, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : theme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ─── Step 1: Theme picker ────────────────────────────────────────────────

  Widget _buildThemePicker(AppThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = AppThemeNotifier.notifierOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'VALORANT',
            style: TextStyle(
              color: theme.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          Text(
            'LINEUPS',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 20,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.appSubtitle,
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 40),

          Text(
            l10n.chooseAppTheme,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.canChangeInProfile,
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          ...AppThemes.all.map((t) {
            final isSelected = theme.type == t.type;
            return GestureDetector(
              onTap: () async {
                notifier?.value = t;
                await AppThemes.save(t.type);
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? t.primary.withValues(alpha: 0.15)
                      : theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? t.primary : theme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.primary, width: 2),
                      ),
                      child: Center(
                        child: Text(t.emoji,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              color: isSelected ? t.primary : theme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _colorDot(t.primary),
                              const SizedBox(width: 4),
                              _colorDot(t.surface),
                              const SizedBox(width: 4),
                              _colorDot(t.background),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: t.primary, size: 22),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                l10n.continueBtn.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
    );
  }

  // ─── Step 2: Nickname ────────────────────────────────────────────────────

  Widget _buildNicknameForm(AppThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final isValid = isValidName(name);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            'VALORANT',
            style: TextStyle(
              color: theme.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          Text(
            'LINEUPS',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 20,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.appSubtitle,
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // ─── Sign in / Register tab switcher ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _authTab(
                    l10n.signIn.toUpperCase(),
                    selected: false,
                    theme: theme,
                    onTap: loading ? null : widget.onLoginInstead,
                  ),
                ),
                Expanded(
                  child: _authTab(
                    l10n.register.toUpperCase(),
                    selected: true,
                    theme: theme,
                    onTap: null,
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
                Text(
                  l10n.welcome,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.createNicknameDesc,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                if (isValid && name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (checkingName)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white38),
                          )
                        else if (nameAvailable == true)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 14)
                        else if (nameAvailable == false)
                          const Icon(Icons.cancel,
                              color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          checkingName
                              ? l10n.checkingNickname
                              : nameAvailable == true
                                  ? l10n.nicknameFree
                                  : nameAvailable == false
                                      ? l10n.nicknameTaken
                                      : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: checkingName
                                ? Colors.white38
                                : nameAvailable == true
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),

                TextField(
                  controller: _nameController,
                  style: TextStyle(color: theme.textPrimary),
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: 'SovaKing / Archer99',
                    hintStyle: TextStyle(color: theme.textSecondary),
                    filled: true,
                    fillColor: theme.background,
                    counterStyle: TextStyle(color: theme.textSecondary),
                    prefixIcon:
                        Icon(Icons.person_outline, color: theme.primary),
                    suffixIcon: checkingName
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white38),
                            ),
                          )
                        : nameAvailable == true
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : nameAvailable == false
                                ? const Icon(Icons.cancel, color: Colors.red)
                                : null,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: nameAvailable == true
                            ? Colors.green
                            : nameAvailable == false
                                ? Colors.red
                                : theme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(errorText!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ),

                Text(
                  l10n.nameHint,
                  style:
                      TextStyle(color: theme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () =>
                      setState(() => termsAccepted = !termsAccepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: termsAccepted
                              ? theme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: termsAccepted
                                ? theme.primary
                                : Colors.white38,
                            width: 2,
                          ),
                        ),
                        child: termsAccepted
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              l10n.iAgreePrefix,
                              style: TextStyle(
                                  color: theme.textSecondary, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const TermsScreen()),
                              ),
                              child: Text(
                                l10n.termsOfService,
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: theme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          termsAccepted ? theme.primary : Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            l10n.continueBtn.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(l10n.or, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: theme.border)),
                  ],
                ),
                const SizedBox(height: 12),

                // Google button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: loading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleLogoReg(),
                        const SizedBox(width: 10),
                        Text(l10n.signInWithGoogle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _step = 1),
                    child: Text(
                      l10n.changeTheme,
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Step 3: Password ────────────────────────────────────────────────────

  Widget _buildPasswordForm(AppThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'VALORANT',
            style: TextStyle(
              color: theme.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          Text(
            'LINEUPS',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 20,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.appSubtitle,
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 40),

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
                Text(
                  l10n.createPassword,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.passwordNeeded,
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.passwordHint,
                    hintStyle: TextStyle(color: theme.textSecondary),
                    filled: true,
                    fillColor: theme.background,
                    prefixIcon: Icon(Icons.lock_outline, color: theme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: theme.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: theme.primary, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _confirmController,
                  obscureText: !_confirmVisible,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.repeatPassword,
                    hintStyle: TextStyle(color: theme.textSecondary),
                    filled: true,
                    fillColor: theme.background,
                    prefixIcon: Icon(Icons.lock_outline, color: theme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: theme.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _confirmVisible = !_confirmVisible),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: theme.primary, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            l10n.start.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _step = 2;
                      errorText = null;
                    }),
                    child: Text(
                      l10n.back,
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GoogleLogoReg extends StatelessWidget {
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
