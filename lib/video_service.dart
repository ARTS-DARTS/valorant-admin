import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'auth_service.dart';

/// Сервис сжатия и загрузки видео в Firebase Storage.
///
/// pubspec.yaml dependencies:
///   video_compress: ^3.1.2
///   firebase_storage: ^12.0.0
///
/// android/app/src/main/AndroidManifest.xml — уже есть INTERNET permission.
class VideoService {
  VideoService._();

  static final _storage = FirebaseStorage.instance;

  /// Сжимает видео до 720p и загружает в Storage.
  /// Возвращает download URL или null при ошибке.
  static Future<String?> compressAndUpload(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // ─── Сжатие до 720p ──────────────────────────────────────────────
      onProgress?.call(0.05);

      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      if (info == null || info.file == null) return null;

      final compressedFile = info.file!;
      onProgress?.call(0.3);

      // ─── Загрузка в Firebase Storage ─────────────────────────────────
      final uid = AuthService.userId ?? 'unknown';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('lineups_video')
          .child(uid)
          .child('$timestamp.mp4');

      final uploadTask = ref.putFile(
        compressedFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Прогресс загрузки
      final progressSub = uploadTask.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred / snap.totalBytes;
        onProgress?.call(0.3 + progress * 0.7); // 30%→100%
      });

      final snapshot = await uploadTask;
      await progressSub.cancel();
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Удаляем сжатый временный файл
      try { await compressedFile.delete(); } catch (_) {}

      onProgress?.call(1.0);
      return downloadUrl;
    } catch (e) {
      return null;
    } finally {
      VideoCompress.cancelCompression();
    }
  }

  /// Удаляет видео из Storage по URL (при отклонении лайнапа).
  static Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }

  /// Размер файла в МБ — для проверки перед загрузкой.
  static double fileSizeMb(File file) {
    return file.lengthSync() / (1024 * 1024);
  }
}
