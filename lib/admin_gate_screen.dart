import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_service.dart';
import 'admin_screen.dart';
import 'moderator_screen.dart';
import 'app_theme.dart';

class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key});

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  bool _loading = true;
  Map<String, dynamic>? _application;

  final _reasonController = TextEditingController();
  bool _submitLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    try {
      final role = await RoleService.getCurrentRole();

      if (role == 'admin') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
        return;
      }

      if (role == 'moderator') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ModeratorScreen()),
        );
        return;
      }

      final application = await RoleService.getApplicationStatus();
      if (mounted) {
        setState(() {
          _application = application;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitApplication() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 50) return;
    setState(() => _submitLoading = true);
    await RoleService.submitApplication(reason);
    final application = await RoleService.getApplicationStatus();
    if (mounted) {
      setState(() {
        _application = application;
        _submitLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text('ПАНЕЛЬ УПРАВЛЕНИЯ',
            style: TextStyle(
                color: t.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        iconTheme: IconThemeData(color: t.primary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary))
          : _buildApplicationScreen(t),
    );
  }

  Widget _buildApplicationScreen(AppThemeData t) {
    final status = _application?['status'] as String?;

    if (status == 'pending') {
      final createdAt =
          (_application?['created_at'] as Timestamp?)?.toDate();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, color: t.primary, size: 64),
              const SizedBox(height: 20),
              Text('Заявка на рассмотрении ⏳',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (createdAt != null)
                Text(
                  'Подана: ${createdAt.day}.${createdAt.month}.${createdAt.year}',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              const SizedBox(height: 12),
              Text('Ожидай решения администратора',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (status == 'rejected') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              Text('Заявка отклонена',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _application = null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Подать повторно',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Center(
              child: Icon(Icons.person_add, color: t.primary, size: 64)),
          const SizedBox(height: 16),
          Center(
            child: Text('Заявка на модератора',
                style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Расскажи почему хочешь стать модератором',
                style: TextStyle(color: t.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _reasonController,
            maxLines: 6,
            maxLength: 500,
            style: TextStyle(color: t.textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Причина (минимум 50 символов)',
              labelStyle: TextStyle(color: t.textSecondary),
              alignLabelWithHint: true,
              filled: true,
              fillColor: t.surface,
              counterStyle: TextStyle(color: t.textSecondary),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.border),
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.primary),
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_reasonController.text.length} / мин. 50',
            style: TextStyle(
              color: _reasonController.text.trim().length >= 50
                  ? Colors.green
                  : t.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitLoading ||
                      _reasonController.text.trim().length < 50
                  ? null
                  : _submitApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                disabledBackgroundColor: t.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('ОТПРАВИТЬ ЗАЯВКУ',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
