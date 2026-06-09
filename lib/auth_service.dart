import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:math';
import 'level_system.dart';
import 'notification_service.dart';
import 'push_queue_service.dart';

class NameTakenException implements Exception {
  const NameTakenException();
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get userId => _auth.currentUser?.uid;

  static String _randomEmail() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final str =
        List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
    return '$str@valorantlineups.app';
  }

  static Future<void> registerWithPassword(
      String username, String password) async {
    // Финальная проверка имени перед созданием аккаунта
    final existing = await _db
        .collection('users')
        .where('name_lower', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw const NameTakenException();

    final email = _randomEmail();
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final uid = cred.user!.uid;

    try {
      await _db.collection('users').doc(uid).set({
        'name': username,
        'name_lower': username.toLowerCase().trim(),
        'uid': uid,
        'user_email': email,
        'created_at': FieldValue.serverTimestamp(),
        'is_banned': false,
        'terms_accepted': true,
        'approved_lineups': 0,
      });
    } catch (e) {
      // Удаляем Auth-аккаунт если Firestore упал, чтобы не было мусора
      await _auth.currentUser?.delete();
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setBool('registered', true);
    await prefs.setString('user_email', email);

    await NotificationService.loginUser(uid);
    PushQueueService.startListening();
  }

  static Future<void> signInWithPassword(
      String username, String password) async {
    final snapshot = await _db
        .collection('users')
        .where('name_lower', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    final data = snapshot.docs.first.data();
    final foundEmail = data['user_email'] as String?;
    if (foundEmail == null || foundEmail.isEmpty) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    final email = foundEmail;
    final displayName = data['name'] as String? ?? username;

    await _auth.signInWithEmailAndPassword(email: email, password: password);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', displayName);
    await prefs.setBool('registered', true);
    await prefs.setString('user_email', email);

    final signedInUid = _auth.currentUser?.uid;
    if (signedInUid != null) await NotificationService.loginUser(signedInUid);
    PushQueueService.startListening();
  }

  static Future<bool> hasActiveSession() async {
    return _auth.currentUser != null;
  }

  // Web client ID (client_type: 3) из google-services.json — обязателен для idToken
  static const _webClientId =
      '288103111419-i95bsa8fl5ist67v6mjaiscm4728it3j.apps.googleusercontent.com';

  // Возвращает: null=отменено, true=новый пользователь (нужен ник), false=существующий (вошёл)
  static Future<bool?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: _webClientId);

    GoogleSignInAccount? googleUser;
    try {
      // Сбрасываем кэшированный аккаунт чтобы всегда показывать выбор аккаунта
      try { await googleSignIn.signOut(); } catch (_) {}
      googleUser = await googleSignIn.signIn();
    } catch (e) {
      // ApiException: 10 = DEVELOPER_ERROR
      // Причины: SHA-1 debug-keystore не добавлен в Firebase,
      //          или package_name в google-services.json не совпадает с applicationId.
      // Получи debug SHA-1: keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
      rethrow;
    }

    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw Exception('Google Sign-In: idToken is null. Проверь SHA-1 и web client ID в Firebase.');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final uid = userCred.user!.uid;
    final isNewFirebaseUser = userCred.additionalUserInfo?.isNewUser ?? true;

    await NotificationService.loginUser(uid);
    PushQueueService.startListening();

    if (isNewFirebaseUser) return true;
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        final name = doc.data()?['name'] as String? ??
            googleUser.displayName ??
            'Player';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', name);
        await prefs.setBool('registered', true);
        return false;
      } else {
        return true;
      }
    } on TimeoutException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', googleUser.displayName ?? 'Player');
      await prefs.setBool('registered', true);
      return false;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', googleUser.displayName ?? 'Player');
      await prefs.setBool('registered', true);
      return false;
    }
  }

  // Сохраняет ник для Google-пользователя после выбора
  static Future<void> saveGoogleUsername(String username) async {
    final existing = await _db
        .collection('users')
        .where('name_lower', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) throw const NameTakenException();

    final uid = userId!;
    await _db.collection('users').doc(uid).set({
      'name': username,
      'name_lower': username.toLowerCase().trim(),
      'uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'is_banned': false,
      'terms_accepted': true,
      'approved_lineups': 0,
    });

    // Приветственное письмо через Firebase «Trigger Email» Extension.
    // Требует расширение «Trigger Email from Firestore» в Firebase Console.
    // Если расширение не установлено — документ создаётся, но письмо не отправляется.
    final email = _auth.currentUser?.email;
    if (email != null) {
      Future(() async {
        try {
          await _db.collection('mail').add({
            'to': email,
            'message': {
              'subject': 'Добро пожаловать в Valorant Lineups!',
              'html': '<div style="font-family:sans-serif;max-width:500px;margin:auto">'
                  '<h2 style="color:#FF4655">🎮 Valorant Lineups</h2>'
                  '<p>Привет, <b>${_htmlEscape(username)}</b>!</p>'
                  '<p>Спасибо за регистрацию. Теперь тебе доступны:</p>'
                  '<ul>'
                  '<li>📍 Лайнапы по всем картам и агентам</li>'
                  '<li>⭐ Избранное — сохраняй полезные лайнапы</li>'
                  '<li>📤 Предлагай свои лайнапы сообществу</li>'
                  '</ul>'
                  '<p>Удачи в рейтинге! 🏆</p>'
                  '</div>',
            },
          });
        } catch (_) {}
      }).ignore();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setBool('registered', true);
  }

  static bool isGoogleUser() {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static bool hasEmailProvider() {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  static Future<void> linkEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.linkWithCredential(credential);
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static String _htmlEscape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;');

  static Future<void> signOut() async {
    PushQueueService.stopListening();
    await NotificationService.logoutUser();
    final googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) await googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('user_email');
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('registered') ?? false;
  }

  static Future<bool> isBanned() async {
    if (userId == null) return false;
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['is_banned'] ?? false;
  }

  static Future<int> getApprovedLineups() async {
    if (userId == null) return 0;
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return 0;
    return doc.data()?['approved_lineups'] ?? 0;
  }

  static Future<bool> canSubmitLineup() async {
    if (userId == null) return false;
    final approved = await getApprovedLineups();
    final cooldownMinutes = LevelSystem.getCooldownMinutes(approved);
    final cooldownAgo =
        DateTime.now().subtract(Duration(minutes: cooldownMinutes));
    final snapshot = await _db
        .collection('lineups')
        .where('user_id', isEqualTo: userId)
        .where('submitted_at', isGreaterThan: Timestamp.fromDate(cooldownAgo))
        .get();
    return snapshot.docs.isEmpty;
  }

  static Future<int> getCooldownRemainingMinutes() async {
    if (userId == null) return 0;
    final approved = await getApprovedLineups();
    final cooldownMinutes = LevelSystem.getCooldownMinutes(approved);
    final cooldownDuration = Duration(minutes: cooldownMinutes);
    final snapshot = await _db
        .collection('lineups')
        .where('user_id', isEqualTo: userId)
        .orderBy('submitted_at', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return 0;
    final lastSubmitted =
        (snapshot.docs.first.data()['submitted_at'] as Timestamp?)?.toDate();
    if (lastSubmitted == null) return 0;
    final nextAllowed = lastSubmitted.add(cooldownDuration);
    final remaining = nextAllowed.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inMinutes + 1;
  }

  static Future<String> getUserRole() async {
    if (userId == null) return 'user';
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return 'user';
    return doc.data()?['role'] ?? 'user';
  }

  static Future<void> incrementApprovedLineups(String uid) async {
    await _db.collection('users').doc(uid).update({
      'approved_lineups': FieldValue.increment(1),
    });
  }
}
