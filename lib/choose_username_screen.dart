import 'package:flutter/material.dart';
import 'package:valorant_lineups/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'app_theme.dart';

class ChooseUsernameScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ChooseUsernameScreen({super.key, required this.onDone});

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _checking = false;
  bool? _nameAvailable;
  String? _errorText;
  String? _lastChecked;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final name = _ctrl.text.trim();
    setState(() {
      _errorText = null;
      _nameAvailable = null;
    });
    if (_isValid(name)) _checkDebounced(name);
  }

  bool _isValid(String name) {
    if (name.length < 2 || name.length > 20) return false;
    return RegExp(r'^[a-zA-Zа-яА-ЯёЁ0-9_\- ]+$').hasMatch(name);
  }

  void _checkDebounced(String name) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_ctrl.text.trim() != name || _lastChecked == name) return;
    _lastChecked = name;
    setState(() => _checking = true);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('name_lower', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();
    if (!mounted || _ctrl.text.trim() != name) return;
    setState(() {
      _nameAvailable = snap.docs.isEmpty;
      _checking = false;
    });
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (!_isValid(name)) {
      setState(() => _errorText = AppLocalizations.of(context)!.nameRules);
      return;
    }
    setState(() { _loading = true; _errorText = null; });
    try {
      await AuthService.saveGoogleUsername(name);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
    } on NameTakenException {
      if (mounted) setState(() { _loading = false; _nameAvailable = false; _errorText = AppLocalizations.of(context)!.nameTaken; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorText = AppLocalizations.of(context)!.errorOccurred; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.of(context);
    final name = _ctrl.text.trim();
    final isValid = _isValid(name);

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
              const SizedBox(height: 48),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.createNicknameDesc, style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Отображается в профиле и таблице лидеров', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),

                    if (isValid && name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            if (_checking)
                              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38))
                            else if (_nameAvailable == true)
                              const Icon(Icons.check_circle, color: Colors.green, size: 14)
                            else if (_nameAvailable == false)
                              const Icon(Icons.cancel, color: Colors.red, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _checking ? AppLocalizations.of(context)!.checkingNickname : _nameAvailable == true ? AppLocalizations.of(context)!.nicknameFree : _nameAvailable == false ? AppLocalizations.of(context)!.nicknameTaken : '',
                              style: TextStyle(fontSize: 12, color: _checking ? Colors.white38 : _nameAvailable == true ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
                      ),

                    TextField(
                      controller: _ctrl,
                      style: TextStyle(color: theme.textPrimary),
                      maxLength: 20,
                      decoration: InputDecoration(
                        hintText: 'Например: SovaKing',
                        hintStyle: TextStyle(color: theme.textSecondary),
                        filled: true,
                        fillColor: theme.background,
                        counterStyle: TextStyle(color: theme.textSecondary),
                        prefixIcon: Icon(Icons.person_outline, color: theme.primary),
                        suffixIcon: _checking
                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)))
                            : _nameAvailable == true
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : _nameAvailable == false
                                    ? const Icon(Icons.cancel, color: Colors.red)
                                    : null,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _errorText != null ? Colors.red : _nameAvailable == true ? Colors.green : _nameAvailable == false ? Colors.red : Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: _nameAvailable == true ? Colors.green : _nameAvailable == false ? Colors.red : theme.primary, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),

                    Text(AppLocalizations.of(context)!.nameHint, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppLocalizations.of(context)!.continueBtn.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
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
