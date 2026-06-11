import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_service.dart';

/// Перехватывает Flutter/Dart ошибки и сохраняет в Firestore → app_errors.
/// Лимит: 50 записей на сессию, чтобы не спамить при рекурсивных сбоях.
class ErrorLoggingService {
  static bool _initialized = false;
  static int _sessionCount = 0;
  static const _maxPerSession = 50;
  static String? _appVersion;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    // Flutter framework errors (rendering, widget build, etc.)
    final prevFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      prevFlutterHandler?.call(details);
      _write(
        type: 'flutter',
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
      );
    };

    // Dart unhandled async exceptions (Future, isolates, etc.)
    PlatformDispatcher.instance.onError = (error, stack) {
      _write(
        type: 'dart',
        message: error.toString(),
        stack: stack.toString(),
      );
      return false; // false = пусть система тоже обрабатывает (debug console)
    };
  }

  static void _write({
    required String type,
    required String message,
    String? stack,
  }) {
    if (_sessionCount >= _maxPerSession) return;
    _sessionCount++;
    _writeAsync(type: type, message: message, stack: stack);
  }

  static Future<void> _writeAsync({
    required String type,
    required String message,
    String? stack,
  }) async {
    try {
      String trimmed(String s, int max) =>
          s.length > max ? '${s.substring(0, max)}…' : s;

      await FirebaseFirestore.instance.collection('app_errors').add({
        'type': type,
        'message': trimmed(message, 2000),
        if (stack != null) 'stack': trimmed(stack, 5000),
        'userId': AuthService.userId,
        'platform': defaultTargetPlatform.name,
        'appVersion': _appVersion ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
