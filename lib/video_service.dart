import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'auth_service.dart';

class VideoService {
  VideoService._();

  static const _accessKey = '593e98c47f3f44ba8c19ab31aa65fbfc';
  static const _secretKey = '72b0e462bc594ccd95c500d4b4a99605';
  static const _bucket    = 'valorant-lineups-video';
  static const _endpoint  = 's3.ru-3.storage.selcloud.ru';
  static const _region    = 'ru-3';
  static const _host      = '$_bucket.$_endpoint';
  static const _cdnHost   = 'd5adab93-7400-49ad-b1f9-66966c03d203.selstorage.ru';

  // ── AWS4 helpers ───────────────────────────────────────────────────────────
  static List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  static String _hexHash(List<int> data) => sha256.convert(data).toString();

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _awsDate(DateTime d) =>
      '${d.year}${_pad(d.month)}${_pad(d.day)}';

  static String _awsDateTime(DateTime d) =>
      '${_awsDate(d)}T${_pad(d.hour)}${_pad(d.minute)}${_pad(d.second)}Z';

  static List<int> _signingKey(String dateStamp) {
    var k = _hmac(utf8.encode('AWS4$_secretKey'), dateStamp);
    k = _hmac(k, _region);
    k = _hmac(k, 's3');
    k = _hmac(k, 'aws4_request');
    return k;
  }

  static Map<String, String> _sign({
    required String method,
    required String objectKey,
    required List<int> body,
    String contentType = '',
    String acl = '',
  }) {
    final now         = DateTime.now().toUtc();
    final dateStamp   = _awsDate(now);
    final amzDate     = _awsDateTime(now);
    final payloadHash = _hexHash(body);
    final hasCT       = contentType.isNotEmpty;
    final hasAcl      = acl.isNotEmpty;

    // Canonical headers must be sorted alphabetically
    final signedHeaders = [
      if (hasCT) 'content-type',
      'host',
      if (hasAcl) 'x-amz-acl',
      'x-amz-content-sha256',
      'x-amz-date',
    ].join(';');

    final canonicalHeaders = [
      if (hasCT) 'content-type:$contentType',
      'host:$_host',
      if (hasAcl) 'x-amz-acl:$acl',
      'x-amz-content-sha256:$payloadHash',
      'x-amz-date:$amzDate',
    ].map((h) => '$h\n').join();

    final canonicalRequest =
        '$method\n/$objectKey\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    final credScope = '$dateStamp/$_region/s3/aws4_request';
    final strToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credScope\n${_hexHash(utf8.encode(canonicalRequest))}';
    final signature = _hmac(_signingKey(dateStamp), strToSign)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final auth =
        'AWS4-HMAC-SHA256 Credential=$_accessKey/$credScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return {
      'Authorization':        auth,
      if (hasCT) 'Content-Type': contentType,
      if (hasAcl) 'x-amz-acl':  acl,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date':           amzDate,
    };
  }

  // ── Публичный API ──────────────────────────────────────────────────────────

  /// Сжимает видео до 720p и загружает на Selectel S3.
  /// Возвращает публичный URL или null при ошибке.
  static Future<String?> compressAndUpload(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
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

      final uid       = AuthService.userId ?? 'unknown';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final objectKey = 'lineups_videos/${uid}_$timestamp.mp4';
      final bytes     = await compressedFile.readAsBytes();

      final headers = _sign(
        method:      'PUT',
        objectKey:   objectKey,
        body:        bytes,
        contentType: 'video/mp4',
        acl:         'public-read',
      )..['Content-Length'] = bytes.length.toString();

      final res = await http.put(
        Uri.parse('https://$_host/$objectKey'),
        headers: headers,
        body:    bytes,
      );

      try { await compressedFile.delete(); } catch (_) {}

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      onProgress?.call(1.0);
      return 'https://$_cdnHost/$objectKey';
    } catch (_) {
      return null;
    } finally {
      VideoCompress.cancelCompression();
    }
  }

  /// Удаляет видео с Selectel S3 по URL (поддерживает оба формата: s3 и selstorage CDN).
  static Future<void> deleteByUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // Извлекаем object key из пути (работает для обоих URL форматов)
      final objectKey = uri.path.substring(1);
      final s3Uri     = Uri.parse('https://$_host/$objectKey');
      final headers   = _sign(
        method:    'DELETE',
        objectKey: objectKey,
        body:      const [],
      );
      await http.delete(s3Uri, headers: headers);
    } catch (_) {}
  }

  /// Размер файла в МБ — для проверки перед загрузкой.
  static double fileSizeMb(File file) =>
      file.lengthSync() / (1024 * 1024);
}
