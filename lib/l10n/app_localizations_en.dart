// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appSubtitle => 'Interactive lineups for everyone';

  @override
  String get tabMaps => 'Maps';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get tabCollections => 'Collections';

  @override
  String get tabProfile => 'Profile';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get or => 'or';

  @override
  String get back => '← Back';

  @override
  String get continueBtn => 'CONTINUE';

  @override
  String get start => 'START';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get errorOccurred => 'An error occurred. Try again later';

  @override
  String get connectionError => 'Connection error. Check your internet.';

  @override
  String get welcome => 'Welcome!';

  @override
  String get loginToAccount => 'Sign in to account';

  @override
  String get signIn => 'SIGN IN';

  @override
  String get register => 'REGISTER';

  @override
  String get nickname => 'Nickname';

  @override
  String get password => 'Password';

  @override
  String get email => 'Email';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get enterNickname => 'Enter nickname';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get userNotFound => 'User with this nickname not found';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get loginFailed => 'Could not sign in. Try again later';

  @override
  String get googleLoginFailed => 'Could not sign in with Google. Try again';

  @override
  String get chooseAppTheme => 'Choose app theme';

  @override
  String get canChangeInProfile => 'Can be changed in profile later';

  @override
  String get createNicknameDesc => 'Create a unique nickname to get started';

  @override
  String get checkingNickname => 'Checking nickname...';

  @override
  String get nicknameFree => 'Nickname is available!';

  @override
  String get nicknameTaken => 'Nickname is taken';

  @override
  String get mustAcceptTerms => 'You must accept the Terms of Service';

  @override
  String get nameRules =>
      'Name must be 2–20 characters.\nLetters, numbers, _ and - only';

  @override
  String get nameTaken => 'This name is already taken. Try another!';

  @override
  String get nameCheckError => 'Name check error. No connection?';

  @override
  String get nameHint =>
      '• 2 to 20 characters\n• Letters, numbers, _ and -\n• Unique — no one can take it';

  @override
  String get iAgreePrefix => 'I have read and accept the ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get changeTheme => '← Change theme';

  @override
  String get createPassword => 'Create password';

  @override
  String get passwordNeeded => 'You\'ll need it to sign in';

  @override
  String get passwordHint => 'Password (minimum 6 characters)';

  @override
  String get repeatPassword => 'Repeat password';

  @override
  String get passwordMinSix => 'Password must be at least 6 characters';

  @override
  String get passwordsMismatch => 'Passwords do not match';

  @override
  String get accountCreationFailed =>
      'Could not create account. Try again later';

  @override
  String get passwordTooSimple =>
      'Password is too simple. Minimum 6 characters';

  @override
  String get emailAlreadyInUse => 'This email is already in use';

  @override
  String get suggestLineup => 'Suggest lineup';

  @override
  String get newsTooltip => 'News';

  @override
  String get ratingMapPool => 'RATING MAP POOL';

  @override
  String get otherMaps => 'OTHER MAPS';

  @override
  String get categoryLineups => 'Lineups';

  @override
  String get categoryLineupsDesc => 'Catch the enemy off guard!';

  @override
  String get categoryCombo => 'Combo';

  @override
  String get categoryComboDesc => 'Great agent combos!';

  @override
  String get categorySmoky => 'Smokes';

  @override
  String get categorySmokyDesc => 'Learn the best smokes for your agents!';

  @override
  String get categoryDefense => 'Defense';

  @override
  String get categoryDefenseDesc =>
      'Don\'t let the enemy take the site easily!';

  @override
  String get noLineupsYet => 'No lineups here yet, but they\'ll be added soon!';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lineups',
      one: '$count lineup',
      zero: 'No lineups',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => 'Exclusive access active for 1 hour';

  @override
  String patchLabel(String patch) {
    return 'Patch $patch';
  }

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountDeletedDesc =>
      'All data deleted. You can create a new account.';

  @override
  String get mainMenu => 'MAIN MENU';

  @override
  String get profileTitle => 'PROFILE';

  @override
  String get topAuthors => 'Top authors';

  @override
  String get signOutDialogTitle => 'Sign out?';

  @override
  String get signOutDialogMessage =>
      'You\'ll need your nickname and password to sign in again.';

  @override
  String get signOutBtn => 'Sign out';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountIrreversible => 'This action is irreversible!';

  @override
  String get deleteAccountContent =>
      'Will be deleted:\n• Your nickname\n• Level and progress\n• All pending lineups\n\nApproved lineups will remain.';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get linkEmailPassword => 'Link email and password';

  @override
  String get linkEmailDesc =>
      'Link email and password to your Google account to sign in either way.';

  @override
  String get newPassword => 'New password';

  @override
  String get fillAllFields => 'Fill in all fields';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordMinSixSymbols => 'Password — minimum 6 characters';

  @override
  String get emailPasswordLinked => 'Email and password linked ✅';

  @override
  String get emailAlreadyUsedByOther =>
      'This email is already used by another account';

  @override
  String get emailAlreadyLinked =>
      'This email is already linked to another account';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get repeatNewPassword => 'Repeat new password';

  @override
  String get newPasswordMinSix => 'New password must be at least 6 characters';

  @override
  String get passwordChanged => 'Password changed ✅';

  @override
  String get currentPasswordWrong => 'Current password is incorrect';

  @override
  String get appTheme => 'App theme';

  @override
  String approvedCount(int count) {
    return 'Approved: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return 'To $name: $count';
  }

  @override
  String get maximum => 'MAXIMUM';

  @override
  String get levelPrivileges => 'Level privileges';

  @override
  String cooldownMinutes(int minutes) {
    return 'Cooldown: $minutes min';
  }

  @override
  String borderColor(String name) {
    return 'Border color: $name';
  }

  @override
  String get animatedProfile => 'Animated profile';

  @override
  String get topAuthorPosition => 'Position in top authors';

  @override
  String get allLevels => 'All levels';

  @override
  String get currentLevel => 'Current';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups lineups • CD ${cd}m';
  }

  @override
  String get aboutApp => 'About app';

  @override
  String get aboutAppContent =>
      'Free app with interactive lineups for Valorant.\n\nNot affiliated with Riot Games.';

  @override
  String get feedback => 'Feedback';

  @override
  String get viewTutorial => 'View tutorial';

  @override
  String get signOutMenuTitle => 'Sign out of account';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get dangerZoneDesc =>
      'Deleting account is irreversible. All progress and level will be lost.';

  @override
  String get deleteMyAccount => 'DELETE MY ACCOUNT';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String nextLineupIn(int minutes) {
    return 'Next lineup in $minutes min.';
  }

  @override
  String get approvedStat => 'Approved';

  @override
  String get totalStat => 'Total';

  @override
  String get cooldownStat => 'CD';

  @override
  String newCount(int count) {
    return '$count new';
  }

  @override
  String get link => 'Link';

  @override
  String get change => 'Change';

  @override
  String get defaultPlayer => 'Player';

  @override
  String get favorites => 'Favorites';

  @override
  String get addToCollection => 'Add to collection';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get lineupFrom => 'Lineup by:';

  @override
  String get description => 'Description';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get possiblyOutdated => 'Possibly outdated — users report inaccuracy';

  @override
  String get isRelevant => 'Relevant?';

  @override
  String get needLevel2 => 'Need level 2';

  @override
  String get loginRequired => 'Sign in to account';

  @override
  String get votingFromLevel2 =>
      'Voting is available from level 2.\n\nBut you can watch an ad — and your vote will count!';

  @override
  String get howToGetLevel2 => 'How to get level 2? →';

  @override
  String get loginToVote => 'Sign in to vote.';

  @override
  String get watchAd => '📺 Watch ad';

  @override
  String get yourVote => 'Your vote';

  @override
  String get isLineupRelevant => 'Is the lineup relevant?';

  @override
  String get outdated => 'Outdated';

  @override
  String get relevant => 'Relevant';

  @override
  String get authorProfileUnavailable => 'Author profile unavailable';

  @override
  String get alreadyVoted => 'You already voted on this lineup';

  @override
  String get adLoading => 'Ad is loading, try in a second...';

  @override
  String get voteAccepted => '✅ Vote counted!';

  @override
  String get voteSaveError => 'Error saving vote';

  @override
  String get watchAdFull => 'Watch the ad to the end';

  @override
  String get adUnavailable => 'Ad unavailable, try later';

  @override
  String get watchAdForAccess => 'Watch the ad to the end to get access';

  @override
  String get adLabel => '📺 ad';

  @override
  String downloadingPercent(String percent) {
    return 'Loading $percent%...';
  }

  @override
  String get loadingAd => 'Loading ad...';

  @override
  String get savingVideo => 'Saving video...';

  @override
  String get savedOffline => 'Saved — available offline';

  @override
  String get onlineOnly => 'Online only';

  @override
  String get saveOffline => 'Save offline';

  @override
  String get videoSaved => 'Video saved';

  @override
  String get videoLoadError => 'Could not load video';

  @override
  String get videoComingSoon => 'Video coming soon';

  @override
  String get videoSavedSuccess => '✅ Video saved — available offline!';

  @override
  String get downloadError => 'Download error, try again';

  @override
  String get needExclusiveForLike => 'Exclusive access needed to like';

  @override
  String get exclusiveLineup => 'Exclusive lineup';

  @override
  String get watchAdForExclusive =>
      'Watch an ad to unlock all exclusive lineups for 1 hour';

  @override
  String get watchAdAccessBtn => '▶ Watch ad → access for 1 hour';

  @override
  String get watchAdForSave => 'Watch the ad to the end to save video';

  @override
  String get thanksForAd => 'Thanks for watching the ad!';

  @override
  String get adHelpsUs => 'It helps us develop the app 💪';

  @override
  String patchVersion(String version) {
    return 'Patch $version';
  }

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String screenshotN(int n) {
    return 'Screenshot $n';
  }

  @override
  String get exclusiveTag => '⭐ EXCLUSIVE';

  @override
  String get howToGetLevel2Title => 'How to get level 2?';

  @override
  String get xpDesc =>
      'Post lineups in the app — you earn XP for each one. Earn enough XP and your level will increase.';

  @override
  String get lineupRequirementsTitle => '📋 Lineup requirements';

  @override
  String get gotItWillPost => 'Got it, I\'ll post!';

  @override
  String get tabMolly => 'Mollies';

  @override
  String get tabReveal => 'Reveal';

  @override
  String get tabSmoky => 'Smokes';

  @override
  String get timingsSectionTitle => '⏱ Timings';

  @override
  String get searchLineups => 'Search lineups...';

  @override
  String get nothingFound => 'Nothing found 🔍';

  @override
  String get language => 'Language';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError =>
      'Could not load data. Check your internet and try again';

  @override
  String get favoritesEmpty => 'No saved lineups yet';

  @override
  String get favoritesEmptyDesc =>
      'Tap the bookmark icon on any lineup to save it';

  @override
  String get feedbackTitle => 'FEEDBACK';

  @override
  String get feedbackSendTab => 'Send';

  @override
  String get feedbackMyMessages => 'My messages';
}
