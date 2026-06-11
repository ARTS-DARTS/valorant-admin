import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
  ];

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive lineups for everyone'**
  String get appSubtitle;

  /// No description provided for @tabMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get tabMaps;

  /// No description provided for @tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tabFavorites;

  /// No description provided for @tabCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get tabCollections;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get back;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueBtn;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get start;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Try again later'**
  String get errorOccurred;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check your internet.'**
  String get connectionError;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @loginToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to account'**
  String get loginToAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get register;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @enterNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter nickname'**
  String get enterNickname;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User with this nickname not found'**
  String get userNotFound;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Try again later'**
  String get loginFailed;

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google. Try again'**
  String get googleLoginFailed;

  /// No description provided for @chooseAppTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose app theme'**
  String get chooseAppTheme;

  /// No description provided for @canChangeInProfile.
  ///
  /// In en, this message translates to:
  /// **'Can be changed in profile later'**
  String get canChangeInProfile;

  /// No description provided for @createNicknameDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a unique nickname to get started'**
  String get createNicknameDesc;

  /// No description provided for @checkingNickname.
  ///
  /// In en, this message translates to:
  /// **'Checking nickname...'**
  String get checkingNickname;

  /// No description provided for @nicknameFree.
  ///
  /// In en, this message translates to:
  /// **'Nickname is available!'**
  String get nicknameFree;

  /// No description provided for @nicknameTaken.
  ///
  /// In en, this message translates to:
  /// **'Nickname is taken'**
  String get nicknameTaken;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'You must accept the Terms of Service'**
  String get mustAcceptTerms;

  /// No description provided for @nameRules.
  ///
  /// In en, this message translates to:
  /// **'Name must be 2–20 characters.\nLetters, numbers, _ and - only'**
  String get nameRules;

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'This name is already taken. Try another!'**
  String get nameTaken;

  /// No description provided for @nameCheckError.
  ///
  /// In en, this message translates to:
  /// **'Name check error. No connection?'**
  String get nameCheckError;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'• 2 to 20 characters\n• Letters, numbers, _ and -\n• Unique — no one can take it'**
  String get nameHint;

  /// No description provided for @iAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the '**
  String get iAgreePrefix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @changeTheme.
  ///
  /// In en, this message translates to:
  /// **'← Change theme'**
  String get changeTheme;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createPassword;

  /// No description provided for @passwordNeeded.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need it to sign in'**
  String get passwordNeeded;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (minimum 6 characters)'**
  String get passwordHint;

  /// No description provided for @repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeatPassword;

  /// No description provided for @passwordMinSix.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinSix;

  /// No description provided for @passwordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsMismatch;

  /// No description provided for @accountCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create account. Try again later'**
  String get accountCreationFailed;

  /// No description provided for @passwordTooSimple.
  ///
  /// In en, this message translates to:
  /// **'Password is too simple. Minimum 6 characters'**
  String get passwordTooSimple;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use'**
  String get emailAlreadyInUse;

  /// No description provided for @suggestLineup.
  ///
  /// In en, this message translates to:
  /// **'Suggest lineup'**
  String get suggestLineup;

  /// No description provided for @newsTooltip.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get newsTooltip;

  /// No description provided for @ratingMapPool.
  ///
  /// In en, this message translates to:
  /// **'RATING MAP POOL'**
  String get ratingMapPool;

  /// No description provided for @otherMaps.
  ///
  /// In en, this message translates to:
  /// **'OTHER MAPS'**
  String get otherMaps;

  /// No description provided for @categoryLineups.
  ///
  /// In en, this message translates to:
  /// **'Lineups'**
  String get categoryLineups;

  /// No description provided for @categoryLineupsDesc.
  ///
  /// In en, this message translates to:
  /// **'Catch the enemy off guard!'**
  String get categoryLineupsDesc;

  /// No description provided for @categoryCombo.
  ///
  /// In en, this message translates to:
  /// **'Combo'**
  String get categoryCombo;

  /// No description provided for @categoryComboDesc.
  ///
  /// In en, this message translates to:
  /// **'Great agent combos!'**
  String get categoryComboDesc;

  /// No description provided for @categorySmoky.
  ///
  /// In en, this message translates to:
  /// **'Smokes'**
  String get categorySmoky;

  /// No description provided for @categorySmokyDesc.
  ///
  /// In en, this message translates to:
  /// **'Learn the best smokes for your agents!'**
  String get categorySmokyDesc;

  /// No description provided for @categoryDefense.
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get categoryDefense;

  /// No description provided for @categoryDefenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Don\'t let the enemy take the site easily!'**
  String get categoryDefenseDesc;

  /// No description provided for @noLineupsYet.
  ///
  /// In en, this message translates to:
  /// **'No lineups here yet, but they\'ll be added soon!'**
  String get noLineupsYet;

  /// No description provided for @lineupCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No lineups} one{{count} lineup} other{{count} lineups}}'**
  String lineupCountLabel(int count);

  /// No description provided for @exclusiveAccessActive.
  ///
  /// In en, this message translates to:
  /// **'Exclusive access active for 1 hour'**
  String get exclusiveAccessActive;

  /// No description provided for @patchLabel.
  ///
  /// In en, this message translates to:
  /// **'Patch {patch}'**
  String patchLabel(String patch);

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @accountDeletedDesc.
  ///
  /// In en, this message translates to:
  /// **'All data deleted. You can create a new account.'**
  String get accountDeletedDesc;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'MAIN MENU'**
  String get mainMenu;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTitle;

  /// No description provided for @topAuthors.
  ///
  /// In en, this message translates to:
  /// **'Top authors'**
  String get topAuthors;

  /// No description provided for @signOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutDialogTitle;

  /// No description provided for @signOutDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need your nickname and password to sign in again.'**
  String get signOutDialogMessage;

  /// No description provided for @signOutBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutBtn;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible!'**
  String get deleteAccountIrreversible;

  /// No description provided for @deleteAccountContent.
  ///
  /// In en, this message translates to:
  /// **'Will be deleted:\n• Your nickname\n• Level and progress\n• All pending lineups\n\nApproved lineups will remain.'**
  String get deleteAccountContent;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @linkEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Link email and password'**
  String get linkEmailPassword;

  /// No description provided for @linkEmailDesc.
  ///
  /// In en, this message translates to:
  /// **'Link email and password to your Google account to sign in either way.'**
  String get linkEmailDesc;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in all fields'**
  String get fillAllFields;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordMinSixSymbols.
  ///
  /// In en, this message translates to:
  /// **'Password — minimum 6 characters'**
  String get passwordMinSixSymbols;

  /// No description provided for @emailPasswordLinked.
  ///
  /// In en, this message translates to:
  /// **'Email and password linked ✅'**
  String get emailPasswordLinked;

  /// No description provided for @emailAlreadyUsedByOther.
  ///
  /// In en, this message translates to:
  /// **'This email is already used by another account'**
  String get emailAlreadyUsedByOther;

  /// No description provided for @emailAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This email is already linked to another account'**
  String get emailAlreadyLinked;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @repeatNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get repeatNewPassword;

  /// No description provided for @newPasswordMinSix.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 6 characters'**
  String get newPasswordMinSix;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed ✅'**
  String get passwordChanged;

  /// No description provided for @currentPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordWrong;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get appTheme;

  /// No description provided for @approvedCount.
  ///
  /// In en, this message translates to:
  /// **'Approved: {count}'**
  String approvedCount(int count);

  /// No description provided for @toNextLevel.
  ///
  /// In en, this message translates to:
  /// **'To {name}: {count}'**
  String toNextLevel(String name, int count);

  /// No description provided for @maximum.
  ///
  /// In en, this message translates to:
  /// **'MAXIMUM'**
  String get maximum;

  /// No description provided for @levelPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Level privileges'**
  String get levelPrivileges;

  /// No description provided for @cooldownMinutes.
  ///
  /// In en, this message translates to:
  /// **'Cooldown: {minutes} min'**
  String cooldownMinutes(int minutes);

  /// No description provided for @borderColor.
  ///
  /// In en, this message translates to:
  /// **'Border color: {name}'**
  String borderColor(String name);

  /// No description provided for @animatedProfile.
  ///
  /// In en, this message translates to:
  /// **'Animated profile'**
  String get animatedProfile;

  /// No description provided for @topAuthorPosition.
  ///
  /// In en, this message translates to:
  /// **'Position in top authors'**
  String get topAuthorPosition;

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get allLevels;

  /// No description provided for @currentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentLevel;

  /// No description provided for @levelRequirements.
  ///
  /// In en, this message translates to:
  /// **'{lineups} lineups • CD {cd}m'**
  String levelRequirements(int lineups, int cd);

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get aboutApp;

  /// No description provided for @aboutAppContent.
  ///
  /// In en, this message translates to:
  /// **'Free app with interactive lineups for Valorant.\n\nNot affiliated with Riot Games.'**
  String get aboutAppContent;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @viewTutorial.
  ///
  /// In en, this message translates to:
  /// **'View tutorial'**
  String get viewTutorial;

  /// No description provided for @signOutMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of account'**
  String get signOutMenuTitle;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// No description provided for @dangerZoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Deleting account is irreversible. All progress and level will be lost.'**
  String get dangerZoneDesc;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'DELETE MY ACCOUNT'**
  String get deleteMyAccount;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @nextLineupIn.
  ///
  /// In en, this message translates to:
  /// **'Next lineup in {minutes} min.'**
  String nextLineupIn(int minutes);

  /// No description provided for @approvedStat.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedStat;

  /// No description provided for @totalStat.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalStat;

  /// No description provided for @cooldownStat.
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get cooldownStat;

  /// No description provided for @newCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String newCount(int count);

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @defaultPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get defaultPlayer;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get addToCollection;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @lineupFrom.
  ///
  /// In en, this message translates to:
  /// **'Lineup by:'**
  String get lineupFrom;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @screenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// No description provided for @possiblyOutdated.
  ///
  /// In en, this message translates to:
  /// **'Possibly outdated — users report inaccuracy'**
  String get possiblyOutdated;

  /// No description provided for @isRelevant.
  ///
  /// In en, this message translates to:
  /// **'Relevant?'**
  String get isRelevant;

  /// No description provided for @needLevel2.
  ///
  /// In en, this message translates to:
  /// **'Need level 2'**
  String get needLevel2;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to account'**
  String get loginRequired;

  /// No description provided for @votingFromLevel2.
  ///
  /// In en, this message translates to:
  /// **'Voting is available from level 2.\n\nBut you can watch an ad — and your vote will count!'**
  String get votingFromLevel2;

  /// No description provided for @howToGetLevel2.
  ///
  /// In en, this message translates to:
  /// **'How to get level 2? →'**
  String get howToGetLevel2;

  /// No description provided for @loginToVote.
  ///
  /// In en, this message translates to:
  /// **'Sign in to vote.'**
  String get loginToVote;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'📺 Watch ad'**
  String get watchAd;

  /// No description provided for @yourVote.
  ///
  /// In en, this message translates to:
  /// **'Your vote'**
  String get yourVote;

  /// No description provided for @isLineupRelevant.
  ///
  /// In en, this message translates to:
  /// **'Is the lineup relevant?'**
  String get isLineupRelevant;

  /// No description provided for @outdated.
  ///
  /// In en, this message translates to:
  /// **'Outdated'**
  String get outdated;

  /// No description provided for @relevant.
  ///
  /// In en, this message translates to:
  /// **'Relevant'**
  String get relevant;

  /// No description provided for @authorProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Author profile unavailable'**
  String get authorProfileUnavailable;

  /// No description provided for @alreadyVoted.
  ///
  /// In en, this message translates to:
  /// **'You already voted on this lineup'**
  String get alreadyVoted;

  /// No description provided for @adLoading.
  ///
  /// In en, this message translates to:
  /// **'Ad is loading, try in a second...'**
  String get adLoading;

  /// No description provided for @voteAccepted.
  ///
  /// In en, this message translates to:
  /// **'✅ Vote counted!'**
  String get voteAccepted;

  /// No description provided for @voteSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving vote'**
  String get voteSaveError;

  /// No description provided for @watchAdFull.
  ///
  /// In en, this message translates to:
  /// **'Watch the ad to the end'**
  String get watchAdFull;

  /// No description provided for @adUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Ad unavailable, try later'**
  String get adUnavailable;

  /// No description provided for @watchAdForAccess.
  ///
  /// In en, this message translates to:
  /// **'Watch the ad to the end to get access'**
  String get watchAdForAccess;

  /// No description provided for @adLabel.
  ///
  /// In en, this message translates to:
  /// **'📺 ad'**
  String get adLabel;

  /// No description provided for @downloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Loading {percent}%...'**
  String downloadingPercent(String percent);

  /// No description provided for @loadingAd.
  ///
  /// In en, this message translates to:
  /// **'Loading ad...'**
  String get loadingAd;

  /// No description provided for @savingVideo.
  ///
  /// In en, this message translates to:
  /// **'Saving video...'**
  String get savingVideo;

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved — available offline'**
  String get savedOffline;

  /// No description provided for @onlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Online only'**
  String get onlineOnly;

  /// No description provided for @saveOffline.
  ///
  /// In en, this message translates to:
  /// **'Save offline'**
  String get saveOffline;

  /// No description provided for @videoSaved.
  ///
  /// In en, this message translates to:
  /// **'Video saved'**
  String get videoSaved;

  /// No description provided for @videoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load video'**
  String get videoLoadError;

  /// No description provided for @videoComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Video coming soon'**
  String get videoComingSoon;

  /// No description provided for @videoSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Video saved — available offline!'**
  String get videoSavedSuccess;

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Download error, try again'**
  String get downloadError;

  /// No description provided for @needExclusiveForLike.
  ///
  /// In en, this message translates to:
  /// **'Exclusive access needed to like'**
  String get needExclusiveForLike;

  /// No description provided for @exclusiveLineup.
  ///
  /// In en, this message translates to:
  /// **'Exclusive lineup'**
  String get exclusiveLineup;

  /// No description provided for @watchAdForExclusive.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to unlock all exclusive lineups for 1 hour'**
  String get watchAdForExclusive;

  /// No description provided for @watchAdAccessBtn.
  ///
  /// In en, this message translates to:
  /// **'▶ Watch ad → access for 1 hour'**
  String get watchAdAccessBtn;

  /// No description provided for @watchAdForSave.
  ///
  /// In en, this message translates to:
  /// **'Watch the ad to the end to save video'**
  String get watchAdForSave;

  /// No description provided for @thanksForAd.
  ///
  /// In en, this message translates to:
  /// **'Thanks for watching the ad!'**
  String get thanksForAd;

  /// No description provided for @adHelpsUs.
  ///
  /// In en, this message translates to:
  /// **'It helps us develop the app 💪'**
  String get adHelpsUs;

  /// No description provided for @patchVersion.
  ///
  /// In en, this message translates to:
  /// **'Patch {version}'**
  String patchVersion(String version);

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @screenshotN.
  ///
  /// In en, this message translates to:
  /// **'Screenshot {n}'**
  String screenshotN(int n);

  /// No description provided for @exclusiveTag.
  ///
  /// In en, this message translates to:
  /// **'⭐ EXCLUSIVE'**
  String get exclusiveTag;

  /// No description provided for @howToGetLevel2Title.
  ///
  /// In en, this message translates to:
  /// **'How to get level 2?'**
  String get howToGetLevel2Title;

  /// No description provided for @xpDesc.
  ///
  /// In en, this message translates to:
  /// **'Post lineups in the app — you earn XP for each one. Earn enough XP and your level will increase.'**
  String get xpDesc;

  /// No description provided for @lineupRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'📋 Lineup requirements'**
  String get lineupRequirementsTitle;

  /// No description provided for @gotItWillPost.
  ///
  /// In en, this message translates to:
  /// **'Got it, I\'ll post!'**
  String get gotItWillPost;

  /// No description provided for @tabMolly.
  ///
  /// In en, this message translates to:
  /// **'Mollies'**
  String get tabMolly;

  /// No description provided for @tabReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get tabReveal;

  /// No description provided for @tabSmoky.
  ///
  /// In en, this message translates to:
  /// **'Smokes'**
  String get tabSmoky;

  /// No description provided for @timingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'⏱ Timings'**
  String get timingsSectionTitle;

  /// No description provided for @searchLineups.
  ///
  /// In en, this message translates to:
  /// **'Search lineups...'**
  String get searchLineups;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found 🔍'**
  String get nothingFound;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language / Язык'**
  String get languageTitle;

  /// No description provided for @favoritesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load data. Check your internet and try again'**
  String get favoritesLoadError;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved lineups yet'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon on any lineup to save it'**
  String get favoritesEmptyDesc;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'FEEDBACK'**
  String get feedbackTitle;

  /// No description provided for @feedbackSendTab.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSendTab;

  /// No description provided for @feedbackMyMessages.
  ///
  /// In en, this message translates to:
  /// **'My messages'**
  String get feedbackMyMessages;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'ja',
    'ko',
    'pt',
    'ru',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
