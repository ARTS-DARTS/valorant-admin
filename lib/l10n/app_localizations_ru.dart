// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appSubtitle => 'Интерактивные лайнапы для всех';

  @override
  String get tabMaps => 'Карты';

  @override
  String get tabFavorites => 'Избранное';

  @override
  String get tabCollections => 'Коллекции';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'OK';

  @override
  String get or => 'или';

  @override
  String get back => '← Назад';

  @override
  String get continueBtn => 'ПРОДОЛЖИТЬ';

  @override
  String get start => 'НАЧАТЬ';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get noInternet => 'Нет подключения к интернету';

  @override
  String get errorOccurred => 'Произошла ошибка. Попробуйте позже';

  @override
  String get connectionError => 'Ошибка соединения. Проверь интернет.';

  @override
  String get welcome => 'Добро пожаловать!';

  @override
  String get loginToAccount => 'Войди в аккаунт';

  @override
  String get signIn => 'ВОЙТИ';

  @override
  String get register => 'РЕГИСТРАЦИЯ';

  @override
  String get nickname => 'Никнейм';

  @override
  String get password => 'Пароль';

  @override
  String get email => 'Email';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get enterNickname => 'Введи никнейм';

  @override
  String get enterPassword => 'Введи пароль';

  @override
  String get userNotFound => 'Пользователь с таким ником не найден';

  @override
  String get wrongPassword => 'Неверный пароль';

  @override
  String get loginFailed => 'Не удалось войти. Попробуйте позже';

  @override
  String get googleLoginFailed =>
      'Не удалось войти через Google. Попробуйте ещё раз';

  @override
  String get chooseAppTheme => 'Выбери тему приложения';

  @override
  String get canChangeInProfile => 'Её можно будет изменить в профиле';

  @override
  String get createNicknameDesc => 'Придумай уникальный никнейм чтобы начать';

  @override
  String get checkingNickname => 'Проверяем никнейм...';

  @override
  String get nicknameFree => 'Никнейм свободен!';

  @override
  String get nicknameTaken => 'Никнейм уже занят';

  @override
  String get mustAcceptTerms =>
      'Необходимо принять пользовательское соглашение';

  @override
  String get nameRules =>
      'Имя должно быть от 2 до 20 символов.\nТолько буквы, цифры, _ и -';

  @override
  String get nameTaken => 'Это имя уже занято. Попробуй другое!';

  @override
  String get nameCheckError => 'Ошибка проверки имени. Нет соединения?';

  @override
  String get nameHint =>
      '• От 2 до 20 символов\n• Буквы, цифры, _ и -\n• Имя уникально — его никто не сможет взять';

  @override
  String get iAgreePrefix => 'Я прочитал и принимаю ';

  @override
  String get termsOfService => 'Пользовательское соглашение';

  @override
  String get changeTheme => '← Изменить тему';

  @override
  String get createPassword => 'Создай пароль';

  @override
  String get passwordNeeded => 'Понадобится для входа в аккаунт';

  @override
  String get passwordHint => 'Пароль (минимум 6 символов)';

  @override
  String get repeatPassword => 'Повтори пароль';

  @override
  String get passwordMinSix => 'Пароль должен быть минимум 6 символов';

  @override
  String get passwordsMismatch => 'Пароли не совпадают';

  @override
  String get accountCreationFailed =>
      'Не удалось создать аккаунт. Попробуйте позже';

  @override
  String get passwordTooSimple => 'Пароль слишком простой. Минимум 6 символов';

  @override
  String get emailAlreadyInUse => 'Этот email уже используется';

  @override
  String get suggestLineup => 'Предложить лайнап';

  @override
  String get newsTooltip => 'Новости';

  @override
  String get ratingMapPool => 'МАППУЛ РЕЙТИНГА';

  @override
  String get otherMaps => 'ОСТАЛЬНЫЕ КАРТЫ';

  @override
  String get categoryLineups => 'Лайнапы';

  @override
  String get categoryLineupsDesc => 'Заставь противника врасплох!';

  @override
  String get categoryCombo => 'Комбо';

  @override
  String get categoryComboDesc => 'Удачные комбо агентов!';

  @override
  String get categorySmoky => 'Смоки';

  @override
  String get categorySmokyDesc => 'Узнай фишечные смоки на своих агентов!';

  @override
  String get categoryDefense => 'Защита';

  @override
  String get categoryDefenseDesc => 'Не дай врагу зайти на сайт так легко!';

  @override
  String get noLineupsYet =>
      'Пока что тут нет лайнапов, но скоро они будут добавлены!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count лайнапов',
      many: '$count лайнапов',
      few: '$count лайнапа',
      one: '$count лайнап',
      zero: 'Нет лайнапов',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'Эксклюзивный доступ активен на 1 час';

  @override
  String patchLabel(String patch) {
    return 'Патч $patch';
  }

  @override
  String get accountDeleted => 'Аккаунт удалён';

  @override
  String get accountDeletedDesc =>
      'Все данные удалены. Ты можешь создать новый аккаунт.';

  @override
  String get mainMenu => 'ГЛАВНОЕ МЕНЮ';

  @override
  String get profileTitle => 'ПРОФИЛЬ';

  @override
  String get topAuthors => 'Топ авторов';

  @override
  String get signOutDialogTitle => 'Выйти из аккаунта?';

  @override
  String get signOutDialogMessage =>
      'Для входа снова потребуется никнейм и пароль.';

  @override
  String get signOutBtn => 'Выйти';

  @override
  String get deleteAccountTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountIrreversible => 'Это действие необратимо!';

  @override
  String get deleteAccountContent =>
      'Будут удалены:\n• Ваш никнейм\n• Уровень и прогресс\n• Все pending лайнапы\n\nОдобренные лайнапы останутся.';

  @override
  String get deleteForever => 'Удалить навсегда';

  @override
  String get linkEmailPassword => 'Привязать email и пароль';

  @override
  String get linkEmailDesc =>
      'Привяжи email и пароль к своему аккаунту Google, чтобы входить любым способом.';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get fillAllFields => 'Заполни все поля';

  @override
  String get enterValidEmail => 'Введи корректный email';

  @override
  String get passwordMinSixSymbols => 'Пароль — минимум 6 символов';

  @override
  String get emailPasswordLinked => 'Email и пароль привязаны ✅';

  @override
  String get emailAlreadyUsedByOther =>
      'Этот email уже используется другим аккаунтом';

  @override
  String get emailAlreadyLinked => 'Этот email уже привязан к другому аккаунту';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get repeatNewPassword => 'Повтори новый пароль';

  @override
  String get newPasswordMinSix => 'Новый пароль должен быть минимум 6 символов';

  @override
  String get passwordChanged => 'Пароль изменён ✅';

  @override
  String get currentPasswordWrong => 'Текущий пароль неверный';

  @override
  String get appTheme => 'Тема приложения';

  @override
  String approvedCount(int count) {
    return 'Одобренных: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return 'До $name: $count';
  }

  @override
  String get maximum => 'МАКСИМУМ';

  @override
  String get levelPrivileges => 'Привилегии уровня';

  @override
  String cooldownMinutes(int minutes) {
    return 'КД отправки: $minutes минут';
  }

  @override
  String borderColor(String name) {
    return 'Цвет рамки: $name';
  }

  @override
  String get animatedProfile => 'Анимированный профиль';

  @override
  String get topAuthorPosition => 'Позиция в топе авторов';

  @override
  String get allLevels => 'Все уровни';

  @override
  String get currentLevel => 'Текущий';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups лайнапов • КД $cdм';
  }

  @override
  String get aboutApp => 'О приложении';

  @override
  String get aboutAppContent =>
      'Бесплатное приложение с интерактивными лайнапами для Valorant.\n\nНе аффилировано с Riot Games.';

  @override
  String get feedback => 'Обратная связь';

  @override
  String get viewTutorial => 'Посмотреть обучение';

  @override
  String get signOutMenuTitle => 'Выйти из аккаунта';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get dangerZoneDesc =>
      'Удаление аккаунта необратимо. Весь прогресс и уровень будут потеряны.';

  @override
  String get deleteMyAccount => 'УДАЛИТЬ МОЙ АККАУНТ';

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Уведомлений нет';

  @override
  String nextLineupIn(int minutes) {
    return 'Следующий лайнап через $minutes мин.';
  }

  @override
  String get approvedStat => 'Одобрено';

  @override
  String get totalStat => 'Всего';

  @override
  String get cooldownStat => 'КД';

  @override
  String newCount(int count) {
    return '$count новых';
  }

  @override
  String get link => 'Привязать';

  @override
  String get change => 'Сменить';

  @override
  String get defaultPlayer => 'Игрок';

  @override
  String get favorites => 'Избранное';

  @override
  String get addToCollection => 'В коллекцию';

  @override
  String get removeFromFavorites => 'Убрать из избранного';

  @override
  String get addToFavorites => 'В избранное';

  @override
  String get lineupFrom => 'Лайнап от:';

  @override
  String get description => 'Описание';

  @override
  String get screenshots => 'Скриншоты';

  @override
  String get possiblyOutdated =>
      'Возможно устарело — пользователи отмечают неактуальность';

  @override
  String get isRelevant => 'Актуально?';

  @override
  String get needLevel2 => 'Нужен 2-й уровень';

  @override
  String get loginRequired => 'Войдите в аккаунт';

  @override
  String get votingFromLevel2 =>
      'Голосование доступно с 2-го уровня.\n\nНо вы можете посмотреть рекламу — и ваш голос засчитается!';

  @override
  String get howToGetLevel2 => 'Как получить 2-й уровень? →';

  @override
  String get loginToVote => 'Войдите в аккаунт чтобы голосовать.';

  @override
  String get watchAd => '📺 Смотреть рекламу';

  @override
  String get yourVote => 'Ваш голос';

  @override
  String get isLineupRelevant => 'Лайнап актуален?';

  @override
  String get outdated => 'Устарело';

  @override
  String get relevant => 'Актуально';

  @override
  String get authorProfileUnavailable => 'Профиль автора недоступен';

  @override
  String get alreadyVoted => 'Вы уже голосовали за этот лайнап';

  @override
  String get adLoading => 'Реклама загружается, попробуй через секунду...';

  @override
  String get voteAccepted => '✅ Голос засчитан!';

  @override
  String get voteSaveError => 'Ошибка при сохранении голоса';

  @override
  String get watchAdFull => 'Досмотри рекламу до конца';

  @override
  String get adUnavailable => 'Реклама недоступна, попробуй позже';

  @override
  String get watchAdForAccess =>
      'Досмотри рекламу до конца чтобы получить доступ';

  @override
  String get adLabel => '📺 реклама';

  @override
  String downloadingPercent(String percent) {
    return 'Загрузка $percent%...';
  }

  @override
  String get loadingAd => 'Загружаем рекламу...';

  @override
  String get savingVideo => 'Сохраняем видео...';

  @override
  String get savedOffline => 'Сохранено — доступно без интернета';

  @override
  String get onlineOnly => 'Только онлайн';

  @override
  String get saveOffline => 'Сохранить оффлайн';

  @override
  String get videoSaved => 'Видео сохранено';

  @override
  String get videoLoadError => 'Не удалось загрузить видео';

  @override
  String get videoComingSoon => 'Видео скоро появится';

  @override
  String get videoSavedSuccess => '✅ Видео сохранено — доступно без интернета!';

  @override
  String get downloadError => 'Ошибка загрузки, попробуй ещё раз';

  @override
  String get needExclusiveForLike => 'Для лайка нужен эксклюзивный доступ';

  @override
  String get exclusiveLineup => 'Эксклюзивный лайнап';

  @override
  String get watchAdForExclusive =>
      'Посмотри рекламу чтобы открыть все эксклюзивные лайнапы на 1 час';

  @override
  String get watchAdAccessBtn => '▶ Смотреть рекламу → доступ на 1 час';

  @override
  String get watchAdForSave =>
      'Досмотри рекламу до конца чтобы сохранить видео';

  @override
  String get thanksForAd => 'Спасибо за просмотр рекламы!';

  @override
  String get adHelpsUs => 'Это помогает нам развивать приложение 💪';

  @override
  String patchVersion(String version) {
    return 'Патч $version';
  }

  @override
  String get difficultyEasy => 'Легко';

  @override
  String get difficultyMedium => 'Средне';

  @override
  String get difficultyHard => 'Сложно';

  @override
  String screenshotN(int n) {
    return 'Скриншот $n';
  }

  @override
  String get exclusiveTag => '⭐ ЭКСКЛЮЗИВ';

  @override
  String get howToGetLevel2Title => 'Как получить 2-й уровень?';

  @override
  String get xpDesc =>
      'Выкладывай лайнапы в приложение — за каждый начисляется опыт. Набери достаточно XP, и уровень повысится.';

  @override
  String get lineupRequirementsTitle => '📋 ТЗ для лайнапов';

  @override
  String get gotItWillPost => 'Понятно, буду выкладывать!';

  @override
  String get tabMolly => 'Молики';

  @override
  String get tabReveal => 'Ревил';

  @override
  String get tabSmoky => 'Смоки';

  @override
  String get timingsSectionTitle => '⏱ Тайминги';

  @override
  String get searchLineups => 'Поиск лайнапов...';

  @override
  String get nothingFound => 'Ничего не найдено 🔍';

  @override
  String get language => 'Язык';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError =>
      'Не удалось загрузить данные. Проверьте интернет и попробуйте ещё раз';

  @override
  String get favoritesEmpty => 'Нет сохранённых лайнапов';

  @override
  String get favoritesEmptyDesc =>
      'Нажми на закладку на любом лайнапе чтобы сохранить';

  @override
  String get feedbackTitle => 'ОБРАТНАЯ СВЯЗЬ';

  @override
  String get feedbackSendTab => 'Отправить';

  @override
  String get feedbackMyMessages => 'Мои сообщения';
}
