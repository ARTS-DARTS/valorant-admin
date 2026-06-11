class LevelSystem {
  static const List<Map<String, dynamic>> levels = [
    {
      'level': 1,
      'name': 'Новобранец',
      'minLineups': 0,
      'color': 0xFF808080, // серый
      'icon': '🎯',
      'cooldownMinutes': 60,
      'animated': false,
    },
    {
      'level': 2,
      'name': 'Разведчик',
      'minLineups': 3,
      'color': 0xFF4FC3F7, // голубой
      'icon': '🔍',
      'cooldownMinutes': 60,
      'animated': false,
    },
    {
      'level': 3,
      'name': 'Агент',
      'minLineups': 7,
      'color': 0xFF66BB6A, // зелёный
      'icon': '⚡',
      'cooldownMinutes': 50,
      'animated': false,
    },
    {
      'level': 4,
      'name': 'Специалист',
      'minLineups': 15,
      'color': 0xFFAB47BC, // фиолетовый
      'icon': '💎',
      'cooldownMinutes': 45,
      'animated': false,
    },
    {
      'level': 5,
      'name': 'Ветеран',
      'minLineups': 30,
      'color': 0xFFFF7043, // оранжевый
      'icon': '🔥',
      'cooldownMinutes': 30,
      'animated': false,
    },
    {
      'level': 6,
      'name': 'Элита',
      'minLineups': 50,
      'color': 0xFFFFD700, // золотой
      'icon': '👑',
      'cooldownMinutes': 20,
      'animated': true,
    },
    {
      'level': 7,
      'name': 'Легенда',
      'minLineups': 100,
      'color': 0xFFFF4655, // красный Valorant
      'icon': '🏆',
      'cooldownMinutes': 10,
      'animated': true,
    },
  ];

  static Map<String, dynamic> getLevel(int approvedLineups) {
    Map<String, dynamic> current = levels[0];
    for (final level in levels) {
      if (approvedLineups >= level['minLineups']) {
        current = level;
      }
    }
    return current;
  }

  static Map<String, dynamic>? getNextLevel(int approvedLineups) {
    final current = getLevel(approvedLineups);
    final currentIndex = levels.indexWhere(
          (l) => l['level'] == current['level'],
    );
    if (currentIndex < levels.length - 1) {
      return levels[currentIndex + 1];
    }
    return null;
  }

  static double getProgress(int approvedLineups) {
    final current = getLevel(approvedLineups);
    final next = getNextLevel(approvedLineups);
    if (next == null) return 1.0;
    final currentMin = current['minLineups'] as int;
    final nextMin = next['minLineups'] as int;
    return (approvedLineups - currentMin) / (nextMin - currentMin);
  }

  static int getCooldownMinutes(int approvedLineups) {
    return getLevel(approvedLineups)['cooldownMinutes'] as int;
  }
}