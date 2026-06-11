import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType { dark, standard, blue, light, colorblind }

class AppThemeData {
  final AppThemeType type;
  final String name;
  final String emoji;
  final Color primary;        // основной акцент (кнопки, заголовки)
  final Color background;     // фон Scaffold
  final Color surface;        // карточки/контейнеры
  final Color surface2;       // вторичная поверхность
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  const AppThemeData({
    required this.type,
    required this.name,
    required this.emoji,
    required this.primary,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });
}

class AppThemes {
  static const standard = AppThemeData(
    type: AppThemeType.standard,
    name: 'Стандартная',
    emoji: '🔴',
    primary: Color(0xFFFF4655),
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF1A1A1A),
    surface2: Color(0xFF2A2A2A),
    textPrimary: Colors.white,
    textSecondary: Colors.white54,
    border: Colors.white24,
  );

  static const dark = AppThemeData(
    type: AppThemeType.dark,
    name: 'Тёмная',
    emoji: '🌑',
    primary: Color(0xFFBB86FC),
    background: Color(0xFF050505),
    surface: Color(0xFF121212),
    surface2: Color(0xFF1E1E1E),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFAAAAAA),
    border: Color(0xFF333333),
  );

  static const blue = AppThemeData(
    type: AppThemeType.blue,
    name: 'Синяя',
    emoji: '🔵',
    primary: Color(0xFF4FC3F7),
    background: Color(0xFF0A0F1A),
    surface: Color(0xFF0D1B2A),
    surface2: Color(0xFF162032),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF8AB4D0),
    border: Color(0xFF1E3A5F),
  );

  static const light = AppThemeData(
    type: AppThemeType.light,
    name: 'Светлая',
    emoji: '☀️',
    primary: Color(0xFFE53935),
    background: Color(0xFFF5F5F5),
    surface: Colors.white,
    surface2: Color(0xFFEEEEEE),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF666666),
    border: Color(0xFFDDDDDD),
  );

  static const colorblind = AppThemeData(
    type: AppThemeType.colorblind,
    name: 'Для дальтоников',
    emoji: '👁',
    primary: Color(0xFFF5A623),   // оранжевый — хорошо различим
    background: Color(0xFF1A1A2E),
    surface: Color(0xFF16213E),
    surface2: Color(0xFF0F3460),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFCCCCCC),
    border: Color(0xFF4A90D9),
  );

  static const all = [standard, dark, blue, light, colorblind];

  static AppThemeData byType(AppThemeType type) {
    return all.firstWhere((t) => t.type == type, orElse: () => standard);
  }

  static Future<AppThemeType> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme') ?? 'standard';
    return AppThemeType.values.firstWhere(
      (t) => t.name == saved,
      orElse: () => AppThemeType.standard,
    );
  }

  static Future<void> save(AppThemeType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', type.name);
  }

  static ThemeData toMaterialTheme(AppThemeData t) {
    final isDark = t.background.computeLuminance() < 0.5;
    return ThemeData(
      scaffoldBackgroundColor: t.background,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: t.primary,
        onPrimary: Colors.white,
        secondary: t.primary,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: t.surface,
        onSurface: t.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.primary,
        iconTheme: IconThemeData(color: t.primary),
        titleTextStyle: TextStyle(
          color: t.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// InheritedWidget — предоставляет тему по всему дереву без Provider
class AppThemeNotifier extends InheritedNotifier<ValueNotifier<AppThemeData>> {
  const AppThemeNotifier({
    super.key,
    required ValueNotifier<AppThemeData> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppThemeData of(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<AppThemeNotifier>()
        ?.notifier;
    return notifier?.value ?? AppThemes.standard;
  }

  static ValueNotifier<AppThemeData>? notifierOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppThemeNotifier>()
        ?.notifier;
  }
}
