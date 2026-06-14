import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class RoleService {
  static final _db = FirebaseFirestore.instance;

  // Заполни после первого запуска: посмотри AuthService.userId и вставь сюда.
  // Затем вручную выставь role:'admin' в Firestore Console для этого uid.
  static const String _adminUid = '';

  static bool isAdminSession() {
    if (_adminUid.isEmpty) return false;
    return AuthService.userId == _adminUid;
  }

  static Future<String> getCurrentRole() async {
    final uid = AuthService.userId;
    if (uid == null) return 'user';
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return 'user';
    return doc.data()?['role'] ?? 'user';
  }

  static Future<void> submitApplication(String reason) async {
    final uid = AuthService.userId;
    if (uid == null) return;
    final username = await AuthService.getUsername() ?? 'Аноним';
    await _db.collection('moderator_applications').doc(uid).set({
      'username': username,
      'reason': reason,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> getApplicationStatus() async {
    final uid = AuthService.userId;
    if (uid == null) return null;
    final doc =
        await _db.collection('moderator_applications').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
