import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCache {
  AppImageCache._();

  static final CacheManager manager = CacheManager(
    Config(
      'app_image_cache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 800,
    ),
  );
}
