// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appSubtitle => 'تشكيلات تفاعلية للجميع';

  @override
  String get tabMaps => 'الخرائط';

  @override
  String get tabFavorites => 'المفضلة';

  @override
  String get tabCollections => 'المجموعات';

  @override
  String get tabProfile => 'الملف الشخصي';

  @override
  String get cancel => 'إلغاء';

  @override
  String get ok => 'موافق';

  @override
  String get or => 'أو';

  @override
  String get back => '→ رجوع';

  @override
  String get continueBtn => 'متابعة';

  @override
  String get start => 'ابدأ';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get noInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorOccurred => 'حدث خطأ. حاول مرة أخرى لاحقاً';

  @override
  String get connectionError => 'خطأ في الاتصال. تحقق من الإنترنت.';

  @override
  String get welcome => 'أهلاً بك!';

  @override
  String get loginToAccount => 'تسجيل الدخول إلى الحساب';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get register => 'التسجيل';

  @override
  String get nickname => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get signInWithGoogle => 'الدخول عبر Google';

  @override
  String get enterNickname => 'أدخل اسم المستخدم';

  @override
  String get enterPassword => 'أدخل كلمة المرور';

  @override
  String get userNotFound => 'لم يتم العثور على مستخدم بهذا الاسم';

  @override
  String get wrongPassword => 'كلمة المرور خاطئة';

  @override
  String get loginFailed => 'تعذر تسجيل الدخول. حاول لاحقاً';

  @override
  String get googleLoginFailed => 'تعذر تسجيل الدخول عبر Google. حاول مرة أخرى';

  @override
  String get chooseAppTheme => 'اختر سمة التطبيق';

  @override
  String get canChangeInProfile => 'يمكن تغييرها لاحقاً من الملف الشخصي';

  @override
  String get createNicknameDesc => 'أنشئ اسم مستخدم فريداً للبدء';

  @override
  String get checkingNickname => 'جاري التحقق من الاسم...';

  @override
  String get nicknameFree => 'الاسم متاح!';

  @override
  String get nicknameTaken => 'الاسم مستخدم';

  @override
  String get mustAcceptTerms => 'يجب قبول شروط الخدمة';

  @override
  String get nameRules =>
      'يجب أن يتكون الاسم من 2-20 حرفاً.\nأحرف وأرقام و _ و - فقط';

  @override
  String get nameTaken => 'هذا الاسم مستخدم بالفعل. جرب اسماً آخر!';

  @override
  String get nameCheckError => 'خطأ في التحقق من الاسم. لا يوجد اتصال؟';

  @override
  String get nameHint =>
      '• من 2 إلى 20 حرفاً\n• أحرف وأرقام و _ و -\n• فريد — لا يمكن لأحد أخذه';

  @override
  String get iAgreePrefix => 'لقد قرأت وأوافق على ';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get changeTheme => 'تغيير السمة →';

  @override
  String get createPassword => 'إنشاء كلمة مرور';

  @override
  String get passwordNeeded => 'ستحتاجها لتسجيل الدخول';

  @override
  String get passwordHint => 'كلمة المرور (6 أحرف على الأقل)';

  @override
  String get repeatPassword => 'أعد كلمة المرور';

  @override
  String get passwordMinSix => 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';

  @override
  String get passwordsMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get accountCreationFailed => 'تعذر إنشاء الحساب. حاول لاحقاً';

  @override
  String get passwordTooSimple => 'كلمة المرور بسيطة جداً. 6 أحرف على الأقل';

  @override
  String get emailAlreadyInUse => 'هذا البريد الإلكتروني مستخدم بالفعل';

  @override
  String get suggestLineup => 'اقتراح تشكيلة';

  @override
  String get newsTooltip => 'الأخبار';

  @override
  String get ratingMapPool => 'خرائط الرتبة';

  @override
  String get otherMaps => 'خرائط أخرى';

  @override
  String get categoryLineups => 'التشكيلات';

  @override
  String get categoryLineupsDesc => 'فاجئ العدو!';

  @override
  String get categoryCombo => 'كومبو';

  @override
  String get categoryComboDesc => 'كومبوهات رائعة للعملاء!';

  @override
  String get categorySmoky => 'الدخان';

  @override
  String get categorySmokyDesc => 'تعلم أفضل الدخان لعملائك!';

  @override
  String get categoryDefense => 'الدفاع';

  @override
  String get categoryDefenseDesc => 'لا تدع العدو يأخذ الموقع بسهولة!';

  @override
  String get noLineupsYet => 'لا توجد تشكيلات بعد، ستُضاف قريباً!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تشكيلات',
      many: '$count تشكيلة',
      few: '$count تشكيلات',
      two: 'تشكيلتان',
      one: 'تشكيلة واحدة',
      zero: 'لا تشكيلات',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'الوصول الحصري نشط لمدة ساعة';

  @override
  String patchLabel(String patch) {
    return 'التحديث $patch';
  }

  @override
  String get accountDeleted => 'تم حذف الحساب';

  @override
  String get accountDeletedDesc =>
      'تم حذف جميع البيانات. يمكنك إنشاء حساب جديد.';

  @override
  String get mainMenu => 'القائمة الرئيسية';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get topAuthors => 'أفضل المؤلفين';

  @override
  String get signOutDialogTitle => 'تسجيل الخروج؟';

  @override
  String get signOutDialogMessage =>
      'ستحتاج إلى اسم المستخدم وكلمة المرور لتسجيل الدخول مرة أخرى.';

  @override
  String get signOutBtn => 'تسجيل الخروج';

  @override
  String get deleteAccountTitle => 'حذف الحساب؟';

  @override
  String get deleteAccountIrreversible => 'هذا الإجراء لا يمكن التراجع عنه!';

  @override
  String get deleteAccountContent =>
      'سيتم حذف:\n• اسم المستخدم\n• المستوى والتقدم\n• جميع التشكيلات المعلقة\n\nستبقى التشكيلات الموافق عليها.';

  @override
  String get deleteForever => 'حذف نهائي';

  @override
  String get linkEmailPassword => 'ربط البريد الإلكتروني وكلمة المرور';

  @override
  String get linkEmailDesc =>
      'اربط البريد وكلمة المرور بحساب Google للدخول بأي طريقة.';

  @override
  String get newPassword => 'كلمة مرور جديدة';

  @override
  String get fillAllFields => 'أكمل جميع الحقول';

  @override
  String get enterValidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get passwordMinSixSymbols => 'كلمة المرور — 6 أحرف على الأقل';

  @override
  String get emailPasswordLinked => 'تم ربط البريد وكلمة المرور ✅';

  @override
  String get emailAlreadyUsedByOther => 'هذا البريد مستخدم من حساب آخر';

  @override
  String get emailAlreadyLinked => 'هذا البريد مرتبط بحساب آخر';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get repeatNewPassword => 'أعد كلمة المرور الجديدة';

  @override
  String get newPasswordMinSix =>
      'يجب أن تتكون كلمة المرور الجديدة من 6 أحرف على الأقل';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور ✅';

  @override
  String get currentPasswordWrong => 'كلمة المرور الحالية خاطئة';

  @override
  String get appTheme => 'سمة التطبيق';

  @override
  String approvedCount(int count) {
    return 'الموافق عليها: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return 'إلى $name: $count';
  }

  @override
  String get maximum => 'الحد الأقصى';

  @override
  String get levelPrivileges => 'امتيازات المستوى';

  @override
  String cooldownMinutes(int minutes) {
    return 'وقت الانتظار: $minutes دقيقة';
  }

  @override
  String borderColor(String name) {
    return 'لون الإطار: $name';
  }

  @override
  String get animatedProfile => 'ملف شخصي متحرك';

  @override
  String get topAuthorPosition => 'الموقع في قائمة أفضل المؤلفين';

  @override
  String get allLevels => 'جميع المستويات';

  @override
  String get currentLevel => 'الحالي';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups تشكيلة • انتظار $cd دقيقة';
  }

  @override
  String get aboutApp => 'حول التطبيق';

  @override
  String get aboutAppContent =>
      'تطبيق مجاني بتشكيلات تفاعلية لـ Valorant.\n\nغير مرتبط بـ Riot Games.';

  @override
  String get feedback => 'ملاحظات';

  @override
  String get viewTutorial => 'عرض الدرس التعليمي';

  @override
  String get signOutMenuTitle => 'تسجيل الخروج من الحساب';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get dangerZoneDesc =>
      'حذف الحساب لا يمكن التراجع عنه. سيُفقد كل التقدم والمستوى.';

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String nextLineupIn(int minutes) {
    return 'التشكيلة التالية خلال $minutes دقيقة.';
  }

  @override
  String get approvedStat => 'موافق عليه';

  @override
  String get totalStat => 'المجموع';

  @override
  String get cooldownStat => 'انتظار';

  @override
  String newCount(int count) {
    return '$count جديد';
  }

  @override
  String get link => 'ربط';

  @override
  String get change => 'تغيير';

  @override
  String get defaultPlayer => 'لاعب';

  @override
  String get favorites => 'المفضلة';

  @override
  String get addToCollection => 'إضافة إلى المجموعة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get lineupFrom => 'تشكيلة بقلم:';

  @override
  String get description => 'الوصف';

  @override
  String get screenshots => 'لقطات الشاشة';

  @override
  String get possiblyOutdated => 'ربما قديم — المستخدمون يُبلّغون عن عدم الدقة';

  @override
  String get isRelevant => 'هل هو محدث؟';

  @override
  String get needLevel2 => 'المستوى 2 مطلوب';

  @override
  String get loginRequired => 'سجل الدخول إلى الحساب';

  @override
  String get votingFromLevel2 =>
      'التصويت متاح من المستوى 2.\n\nلكن يمكنك مشاهدة إعلان — وسيُحسب صوتك!';

  @override
  String get howToGetLevel2 => 'كيف تصل إلى المستوى 2؟ →';

  @override
  String get loginToVote => 'سجل الدخول للتصويت.';

  @override
  String get watchAd => '📺 مشاهدة إعلان';

  @override
  String get yourVote => 'صوتك';

  @override
  String get isLineupRelevant => 'هل التشكيلة محدثة؟';

  @override
  String get outdated => 'قديم';

  @override
  String get relevant => 'محدث';

  @override
  String get authorProfileUnavailable => 'ملف المؤلف غير متاح';

  @override
  String get alreadyVoted => 'لقد صوّتت بالفعل على هذه التشكيلة';

  @override
  String get adLoading => 'الإعلان يتحمل، حاول بعد لحظة...';

  @override
  String get voteAccepted => '✅ تم احتساب الصوت!';

  @override
  String get voteSaveError => 'خطأ في حفظ الصوت';

  @override
  String get watchAdFull => 'شاهد الإعلان حتى النهاية';

  @override
  String get adUnavailable => 'الإعلان غير متاح، حاول لاحقاً';

  @override
  String get watchAdForAccess => 'شاهد الإعلان حتى النهاية للحصول على الوصول';

  @override
  String get adLabel => '📺 إعلان';

  @override
  String downloadingPercent(String percent) {
    return 'جاري التحميل $percent%...';
  }

  @override
  String get loadingAd => 'جاري تحميل الإعلان...';

  @override
  String get savingVideo => 'جاري حفظ الفيديو...';

  @override
  String get savedOffline => 'محفوظ — متاح بدون إنترنت';

  @override
  String get onlineOnly => 'متاح عبر الإنترنت فقط';

  @override
  String get saveOffline => 'حفظ بدون إنترنت';

  @override
  String get videoSaved => 'تم حفظ الفيديو';

  @override
  String get videoLoadError => 'تعذر تحميل الفيديو';

  @override
  String get videoComingSoon => 'الفيديو قريباً';

  @override
  String get videoSavedSuccess => '✅ تم حفظ الفيديو — متاح بدون إنترنت!';

  @override
  String get downloadError => 'خطأ في التنزيل، حاول مرة أخرى';

  @override
  String get needExclusiveForLike => 'الوصول الحصري مطلوب للإعجاب';

  @override
  String get exclusiveLineup => 'تشكيلة حصرية';

  @override
  String get watchAdForExclusive =>
      'شاهد إعلاناً لفتح جميع التشكيلات الحصرية لمدة ساعة';

  @override
  String get watchAdAccessBtn => '▶ مشاهدة إعلان → وصول لساعة';

  @override
  String get watchAdForSave => 'شاهد الإعلان حتى النهاية لحفظ الفيديو';

  @override
  String get thanksForAd => 'شكراً لمشاهدة الإعلان!';

  @override
  String get adHelpsUs => 'هذا يساعدنا في تطوير التطبيق 💪';

  @override
  String patchVersion(String version) {
    return 'التحديث $version';
  }

  @override
  String get difficultyEasy => 'سهل';

  @override
  String get difficultyMedium => 'متوسط';

  @override
  String get difficultyHard => 'صعب';

  @override
  String screenshotN(int n) {
    return 'لقطة $n';
  }

  @override
  String get exclusiveTag => '⭐ حصري';

  @override
  String get howToGetLevel2Title => 'كيف تصل إلى المستوى 2؟';

  @override
  String get xpDesc =>
      'انشر تشكيلات في التطبيق — تكسب XP لكل واحدة. اجمع XP كافياً وسيرتفع مستواك.';

  @override
  String get lineupRequirementsTitle => '📋 متطلبات التشكيلة';

  @override
  String get gotItWillPost => 'فهمت، سأنشر!';

  @override
  String get tabMolly => 'Molly';

  @override
  String get tabReveal => 'كشف';

  @override
  String get tabSmoky => 'دخان';

  @override
  String get timingsSectionTitle => '⏱ التوقيتات';

  @override
  String get searchLineups => 'البحث عن تشكيلات...';

  @override
  String get nothingFound => 'لم يتم العثور على شيء 🔍';

  @override
  String get language => 'اللغة';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError =>
      'تعذر تحميل البيانات. تحقق من الإنترنت وحاول مرة أخرى';

  @override
  String get favoritesEmpty => 'لا توجد تشكيلات محفوظة';

  @override
  String get favoritesEmptyDesc =>
      'اضغط على أيقونة المفضلة في أي تشكيلة لحفظها';

  @override
  String get feedbackTitle => 'الملاحظات';

  @override
  String get feedbackSendTab => 'إرسال';

  @override
  String get feedbackMyMessages => 'رسائلي';
}
