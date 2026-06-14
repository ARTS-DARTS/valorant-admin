// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appSubtitle => '모두를 위한 인터랙티브 라인업';

  @override
  String get tabMaps => '지도';

  @override
  String get tabFavorites => '즐겨찾기';

  @override
  String get tabCollections => '컬렉션';

  @override
  String get tabProfile => '프로필';

  @override
  String get cancel => '취소';

  @override
  String get ok => '확인';

  @override
  String get or => '또는';

  @override
  String get back => '← 뒤로';

  @override
  String get continueBtn => '계속';

  @override
  String get start => '시작';

  @override
  String get comingSoon => '곧 출시';

  @override
  String get noInternet => '인터넷 연결 없음';

  @override
  String get errorOccurred => '오류가 발생했습니다. 나중에 다시 시도하세요';

  @override
  String get connectionError => '연결 오류. 인터넷을 확인하세요.';

  @override
  String get welcome => '환영합니다!';

  @override
  String get loginToAccount => '계정에 로그인';

  @override
  String get signIn => '로그인';

  @override
  String get register => '회원가입';

  @override
  String get nickname => '닉네임';

  @override
  String get password => '비밀번호';

  @override
  String get email => '이메일';

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get enterNickname => '닉네임을 입력하세요';

  @override
  String get enterPassword => '비밀번호를 입력하세요';

  @override
  String get userNotFound => '이 닉네임의 사용자를 찾을 수 없습니다';

  @override
  String get wrongPassword => '비밀번호가 틀렸습니다';

  @override
  String get loginFailed => '로그인할 수 없습니다. 나중에 다시 시도하세요';

  @override
  String get googleLoginFailed => 'Google로 로그인할 수 없습니다. 다시 시도하세요';

  @override
  String get chooseAppTheme => '앱 테마 선택';

  @override
  String get canChangeInProfile => '나중에 프로필에서 변경 가능';

  @override
  String get createNicknameDesc => '시작하려면 고유한 닉네임을 만드세요';

  @override
  String get checkingNickname => '닉네임 확인 중...';

  @override
  String get nicknameFree => '닉네임 사용 가능!';

  @override
  String get nicknameTaken => '닉네임이 이미 사용 중';

  @override
  String get mustAcceptTerms => '서비스 약관에 동의해야 합니다';

  @override
  String get nameRules => '이름은 2-20자여야 합니다.\n글자, 숫자, _ 및 - 만 가능';

  @override
  String get nameTaken => '이 이름은 이미 사용 중입니다. 다른 이름을 시도하세요!';

  @override
  String get nameCheckError => '이름 확인 오류. 연결 없음?';

  @override
  String get nameHint => '• 2~20자\n• 글자, 숫자, _ 및 -\n• 고유 — 누구도 가져갈 수 없음';

  @override
  String get iAgreePrefix => '읽고 동의합니다 ';

  @override
  String get termsOfService => '서비스 약관';

  @override
  String get changeTheme => '← 테마 변경';

  @override
  String get createPassword => '비밀번호 만들기';

  @override
  String get passwordNeeded => '로그인에 필요합니다';

  @override
  String get passwordHint => '비밀번호 (최소 6자)';

  @override
  String get repeatPassword => '비밀번호 반복';

  @override
  String get passwordMinSix => '비밀번호는 최소 6자여야 합니다';

  @override
  String get passwordsMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get accountCreationFailed => '계정을 만들 수 없습니다. 나중에 다시 시도하세요';

  @override
  String get passwordTooSimple => '비밀번호가 너무 단순합니다. 최소 6자';

  @override
  String get emailAlreadyInUse => '이 이메일은 이미 사용 중입니다';

  @override
  String get suggestLineup => '라인업 제안';

  @override
  String get newsTooltip => '뉴스';

  @override
  String get ratingMapPool => '랭크 맵 풀';

  @override
  String get otherMaps => '다른 맵';

  @override
  String get categoryLineups => '라인업';

  @override
  String get categoryLineupsDesc => '적을 방심하게 해라!';

  @override
  String get categoryCombo => '콤보';

  @override
  String get categoryComboDesc => '훌륭한 에이전트 콤보!';

  @override
  String get categorySmoky => '스모크';

  @override
  String get categorySmokyDesc => '에이전트를 위한 최고의 스모크를 배워라!';

  @override
  String get categoryDefense => '방어';

  @override
  String get categoryDefenseDesc => '적이 쉽게 사이트를 점령하지 못하게 해라!';

  @override
  String get noLineupsYet => '아직 라인업이 없지만 곧 추가될 예정입니다!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 라인업',
      zero: '라인업 없음',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => '1시간 동안 독점 접근 활성화';

  @override
  String patchLabel(String patch) {
    return '패치 $patch';
  }

  @override
  String get accountDeleted => '계정 삭제됨';

  @override
  String get accountDeletedDesc => '모든 데이터가 삭제되었습니다. 새 계정을 만들 수 있습니다.';

  @override
  String get mainMenu => '메인 메뉴';

  @override
  String get profileTitle => '프로필';

  @override
  String get topAuthors => '인기 작성자';

  @override
  String get signOutDialogTitle => '로그아웃?';

  @override
  String get signOutDialogMessage => '다시 로그인하려면 닉네임과 비밀번호가 필요합니다.';

  @override
  String get signOutBtn => '로그아웃';

  @override
  String get deleteAccountTitle => '계정 삭제?';

  @override
  String get deleteAccountIrreversible => '이 작업은 되돌릴 수 없습니다!';

  @override
  String get deleteAccountContent =>
      '삭제될 항목:\n• 닉네임\n• 레벨 및 진행 상황\n• 대기 중인 모든 라인업\n\n승인된 라인업은 유지됩니다.';

  @override
  String get deleteForever => '영구 삭제';

  @override
  String get linkEmailPassword => '이메일 및 비밀번호 연결';

  @override
  String get linkEmailDesc => 'Google 계정에 이메일과 비밀번호를 연결하여 어떤 방법으로든 로그인하세요.';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get fillAllFields => '모든 필드를 채우세요';

  @override
  String get enterValidEmail => '유효한 이메일을 입력하세요';

  @override
  String get passwordMinSixSymbols => '비밀번호 — 최소 6자';

  @override
  String get emailPasswordLinked => '이메일 및 비밀번호 연결됨 ✅';

  @override
  String get emailAlreadyUsedByOther => '이 이메일은 다른 계정에서 이미 사용 중입니다';

  @override
  String get emailAlreadyLinked => '이 이메일은 이미 다른 계정에 연결되어 있습니다';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get repeatNewPassword => '새 비밀번호 반복';

  @override
  String get newPasswordMinSix => '새 비밀번호는 최소 6자여야 합니다';

  @override
  String get passwordChanged => '비밀번호 변경됨 ✅';

  @override
  String get currentPasswordWrong => '현재 비밀번호가 틀렸습니다';

  @override
  String get appTheme => '앱 테마';

  @override
  String approvedCount(int count) {
    return '승인됨: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return '$name까지: $count';
  }

  @override
  String get maximum => '최대';

  @override
  String get levelPrivileges => '레벨 혜택';

  @override
  String cooldownMinutes(int minutes) {
    return '대기 시간: $minutes분';
  }

  @override
  String borderColor(String name) {
    return '테두리 색상: $name';
  }

  @override
  String get animatedProfile => '애니메이션 프로필';

  @override
  String get topAuthorPosition => '인기 작성자 순위';

  @override
  String get allLevels => '모든 레벨';

  @override
  String get currentLevel => '현재';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups개 라인업 • CD $cd분';
  }

  @override
  String get aboutApp => '앱 정보';

  @override
  String get aboutAppContent =>
      'Valorant를 위한 인터랙티브 라인업이 있는 무료 앱.\n\nRiot Games와 제휴하지 않음.';

  @override
  String get feedback => '피드백';

  @override
  String get viewTutorial => '튜토리얼 보기';

  @override
  String get signOutMenuTitle => '계정 로그아웃';

  @override
  String get dangerZone => '위험 구역';

  @override
  String get dangerZoneDesc => '계정 삭제는 되돌릴 수 없습니다. 모든 진행 상황과 레벨이 사라집니다.';

  @override
  String get deleteMyAccount => '내 계정 삭제';

  @override
  String get notifications => '알림';

  @override
  String get noNotifications => '알림 없음';

  @override
  String nextLineupIn(int minutes) {
    return '$minutes분 후 다음 라인업.';
  }

  @override
  String get approvedStat => '승인됨';

  @override
  String get totalStat => '총계';

  @override
  String get cooldownStat => 'CD';

  @override
  String newCount(int count) {
    return '$count개 새로운';
  }

  @override
  String get link => '연결';

  @override
  String get change => '변경';

  @override
  String get defaultPlayer => '플레이어';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get addToCollection => '컬렉션에 추가';

  @override
  String get removeFromFavorites => '즐겨찾기에서 제거';

  @override
  String get addToFavorites => '즐겨찾기에 추가';

  @override
  String get lineupFrom => '라인업 제작자:';

  @override
  String get description => '설명';

  @override
  String get screenshots => '스크린샷';

  @override
  String get possiblyOutdated => '구식일 수 있음 — 사용자들이 부정확성을 보고함';

  @override
  String get isRelevant => '현재 유효?';

  @override
  String get needLevel2 => '레벨 2 필요';

  @override
  String get loginRequired => '계정에 로그인';

  @override
  String get votingFromLevel2 => '투표는 레벨 2부터 가능합니다.\n\n하지만 광고를 보면 — 투표가 반영됩니다!';

  @override
  String get howToGetLevel2 => '레벨 2 얻는 방법? →';

  @override
  String get loginToVote => '투표하려면 로그인하세요.';

  @override
  String get watchAd => '📺 광고 보기';

  @override
  String get yourVote => '당신의 투표';

  @override
  String get isLineupRelevant => '라인업이 현재 유효한가요?';

  @override
  String get outdated => '구식';

  @override
  String get relevant => '유효';

  @override
  String get authorProfileUnavailable => '작성자 프로필을 사용할 수 없습니다';

  @override
  String get alreadyVoted => '이미 이 라인업에 투표했습니다';

  @override
  String get adLoading => '광고 로딩 중, 잠시 후 시도하세요...';

  @override
  String get voteAccepted => '✅ 투표 완료!';

  @override
  String get voteSaveError => '투표 저장 오류';

  @override
  String get watchAdFull => '광고를 끝까지 보세요';

  @override
  String get adUnavailable => '광고를 사용할 수 없습니다, 나중에 시도하세요';

  @override
  String get watchAdForAccess => '접근하려면 광고를 끝까지 보세요';

  @override
  String get adLabel => '📺 광고';

  @override
  String downloadingPercent(String percent) {
    return '로딩 $percent%...';
  }

  @override
  String get loadingAd => '광고 로딩 중...';

  @override
  String get savingVideo => '동영상 저장 중...';

  @override
  String get savedOffline => '저장됨 — 오프라인에서 사용 가능';

  @override
  String get onlineOnly => '온라인 전용';

  @override
  String get saveOffline => '오프라인으로 저장';

  @override
  String get videoSaved => '동영상 저장됨';

  @override
  String get videoLoadError => '동영상을 불러올 수 없습니다';

  @override
  String get videoComingSoon => '동영상 곧 출시';

  @override
  String get videoSavedSuccess => '✅ 동영상 저장됨 — 오프라인에서 사용 가능!';

  @override
  String get downloadError => '다운로드 오류, 다시 시도하세요';

  @override
  String get needExclusiveForLike => '좋아요를 누르려면 독점 접근이 필요합니다';

  @override
  String get exclusiveLineup => '독점 라인업';

  @override
  String get watchAdForExclusive => '1시간 동안 모든 독점 라인업을 열려면 광고를 보세요';

  @override
  String get watchAdAccessBtn => '▶ 광고 보기 → 1시간 접근';

  @override
  String get watchAdForSave => '동영상을 저장하려면 광고를 끝까지 보세요';

  @override
  String get thanksForAd => '광고를 봐주셔서 감사합니다!';

  @override
  String get adHelpsUs => '앱 개발에 도움이 됩니다 💪';

  @override
  String patchVersion(String version) {
    return '패치 $version';
  }

  @override
  String get difficultyEasy => '쉬움';

  @override
  String get difficultyMedium => '보통';

  @override
  String get difficultyHard => '어려움';

  @override
  String screenshotN(int n) {
    return '스크린샷 $n';
  }

  @override
  String get exclusiveTag => '⭐ 독점';

  @override
  String get howToGetLevel2Title => '레벨 2 얻는 방법?';

  @override
  String get xpDesc => '앱에 라인업을 올리세요 — 각각에 대해 XP를 얻습니다. 충분한 XP를 모으면 레벨이 올라갑니다.';

  @override
  String get lineupRequirementsTitle => '📋 라인업 요구 사항';

  @override
  String get gotItWillPost => '알겠습니다, 올리겠습니다!';

  @override
  String get tabMolly => 'Molly';

  @override
  String get tabReveal => '리빌';

  @override
  String get tabSmoky => '스모크';

  @override
  String get timingsSectionTitle => '⏱ 타이밍';

  @override
  String get searchLineups => '라인업 검색...';

  @override
  String get nothingFound => '찾을 수 없음 🔍';

  @override
  String get language => '언어';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError => '데이터를 불러올 수 없습니다. 인터넷을 확인하고 다시 시도하세요';

  @override
  String get favoritesEmpty => '저장된 라인업 없음';

  @override
  String get favoritesEmptyDesc => '저장하려면 라인업의 북마크 아이콘을 탭하세요';

  @override
  String get feedbackTitle => '피드백';

  @override
  String get feedbackSendTab => '보내기';

  @override
  String get feedbackMyMessages => '내 메시지';
}
