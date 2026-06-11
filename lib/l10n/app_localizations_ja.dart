// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appSubtitle => 'みんなのためのインタラクティブなラインナップ';

  @override
  String get tabMaps => 'マップ';

  @override
  String get tabFavorites => 'お気に入り';

  @override
  String get tabCollections => 'コレクション';

  @override
  String get tabProfile => 'プロフィール';

  @override
  String get cancel => 'キャンセル';

  @override
  String get ok => 'OK';

  @override
  String get or => 'または';

  @override
  String get back => '← 戻る';

  @override
  String get continueBtn => '続ける';

  @override
  String get start => '開始';

  @override
  String get comingSoon => 'もうすぐ';

  @override
  String get noInternet => 'インターネット接続なし';

  @override
  String get errorOccurred => 'エラーが発生しました。後でもう一度お試しください';

  @override
  String get connectionError => '接続エラー。インターネットを確認してください。';

  @override
  String get welcome => 'ようこそ！';

  @override
  String get loginToAccount => 'アカウントにログイン';

  @override
  String get signIn => 'ログイン';

  @override
  String get register => '登録';

  @override
  String get nickname => 'ニックネーム';

  @override
  String get password => 'パスワード';

  @override
  String get email => 'メール';

  @override
  String get signInWithGoogle => 'Googleでログイン';

  @override
  String get enterNickname => 'ニックネームを入力';

  @override
  String get enterPassword => 'パスワードを入力';

  @override
  String get userNotFound => 'このニックネームのユーザーが見つかりません';

  @override
  String get wrongPassword => 'パスワードが違います';

  @override
  String get loginFailed => 'ログインできませんでした。後でもう一度お試しください';

  @override
  String get googleLoginFailed => 'Googleでログインできませんでした。もう一度お試しください';

  @override
  String get chooseAppTheme => 'アプリのテーマを選ぶ';

  @override
  String get canChangeInProfile => '後でプロフィールで変更できます';

  @override
  String get createNicknameDesc => '始めるためにユニークなニックネームを作成してください';

  @override
  String get checkingNickname => 'ニックネームを確認中...';

  @override
  String get nicknameFree => 'ニックネームは利用可能です！';

  @override
  String get nicknameTaken => 'ニックネームはすでに使用されています';

  @override
  String get mustAcceptTerms => '利用規約に同意する必要があります';

  @override
  String get nameRules => '名前は2〜20文字でなければなりません。\n文字、数字、_および-のみ';

  @override
  String get nameTaken => 'この名前はすでに使用されています。別の名前をお試しください！';

  @override
  String get nameCheckError => '名前確認エラー。接続なし？';

  @override
  String get nameHint => '• 2〜20文字\n• 文字、数字、_および-\n• ユニーク — 誰も取ることができない';

  @override
  String get iAgreePrefix => '読んで同意します ';

  @override
  String get termsOfService => '利用規約';

  @override
  String get changeTheme => '← テーマを変更';

  @override
  String get createPassword => 'パスワードを作成';

  @override
  String get passwordNeeded => 'ログインに必要になります';

  @override
  String get passwordHint => 'パスワード（最低6文字）';

  @override
  String get repeatPassword => 'パスワードを繰り返す';

  @override
  String get passwordMinSix => 'パスワードは少なくとも6文字必要です';

  @override
  String get passwordsMismatch => 'パスワードが一致しません';

  @override
  String get accountCreationFailed => 'アカウントを作成できませんでした。後でもう一度お試しください';

  @override
  String get passwordTooSimple => 'パスワードが単純すぎます。最低6文字';

  @override
  String get emailAlreadyInUse => 'このメールアドレスはすでに使用されています';

  @override
  String get suggestLineup => 'ラインナップを提案';

  @override
  String get newsTooltip => 'ニュース';

  @override
  String get ratingMapPool => 'ランクマッププール';

  @override
  String get otherMaps => 'その他のマップ';

  @override
  String get categoryLineups => 'ラインナップ';

  @override
  String get categoryLineupsDesc => '敵を不意打ちにしよう！';

  @override
  String get categoryCombo => 'コンボ';

  @override
  String get categoryComboDesc => '素晴らしいエージェントコンボ！';

  @override
  String get categorySmoky => 'スモーク';

  @override
  String get categorySmokyDesc => 'エージェントのベストスモークを学ぼう！';

  @override
  String get categoryDefense => '防衛';

  @override
  String get categoryDefenseDesc => '敵がサイトを簡単に取れないようにしよう！';

  @override
  String get noLineupsYet => 'まだラインナップはありませんが、もうすぐ追加されます！';

  @override
  String lineupCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個のラインナップ',
      zero: 'ラインナップなし',
    );
    return '$_temp0';
  }

  @override
  String get exclusiveAccessActive => '1時間の限定アクセスが有効';

  @override
  String patchLabel(String patch) {
    return 'パッチ $patch';
  }

  @override
  String get accountDeleted => 'アカウントが削除されました';

  @override
  String get accountDeletedDesc => 'すべてのデータが削除されました。新しいアカウントを作成できます。';

  @override
  String get mainMenu => 'メインメニュー';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get topAuthors => 'トップ作成者';

  @override
  String get signOutDialogTitle => 'ログアウト？';

  @override
  String get signOutDialogMessage => '再度ログインするにはニックネームとパスワードが必要です。';

  @override
  String get signOutBtn => 'ログアウト';

  @override
  String get deleteAccountTitle => 'アカウントを削除？';

  @override
  String get deleteAccountIrreversible => 'この操作は元に戻せません！';

  @override
  String get deleteAccountContent =>
      '削除されるもの:\n• ニックネーム\n• レベルと進行状況\n• 全ての保留中のラインナップ\n\n承認済みのラインナップは残ります。';

  @override
  String get deleteForever => '永久に削除';

  @override
  String get linkEmailPassword => 'メールとパスワードを連携';

  @override
  String get linkEmailDesc => 'Googleアカウントにメールとパスワードを連携して、どちらの方法でもログインできます。';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get fillAllFields => 'すべてのフィールドを入力してください';

  @override
  String get enterValidEmail => '有効なメールアドレスを入力してください';

  @override
  String get passwordMinSixSymbols => 'パスワード — 最低6文字';

  @override
  String get emailPasswordLinked => 'メールとパスワードが連携されました ✅';

  @override
  String get emailAlreadyUsedByOther => 'このメールは別のアカウントで使用されています';

  @override
  String get emailAlreadyLinked => 'このメールはすでに別のアカウントに連携されています';

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get repeatNewPassword => '新しいパスワードを繰り返す';

  @override
  String get newPasswordMinSix => '新しいパスワードは少なくとも6文字必要です';

  @override
  String get passwordChanged => 'パスワードが変更されました ✅';

  @override
  String get currentPasswordWrong => '現在のパスワードが違います';

  @override
  String get appTheme => 'アプリのテーマ';

  @override
  String approvedCount(int count) {
    return '承認済み: $count';
  }

  @override
  String toNextLevel(String name, int count) {
    return '$nameまで: $count';
  }

  @override
  String get maximum => '最大';

  @override
  String get levelPrivileges => 'レベル特典';

  @override
  String cooldownMinutes(int minutes) {
    return 'クールダウン: $minutes分';
  }

  @override
  String borderColor(String name) {
    return '枠の色: $name';
  }

  @override
  String get animatedProfile => 'アニメーションプロフィール';

  @override
  String get topAuthorPosition => 'トップ作成者ランキング';

  @override
  String get allLevels => '全レベル';

  @override
  String get currentLevel => '現在';

  @override
  String levelRequirements(int lineups, int cd) {
    return '$lineups個のラインナップ • CD $cd分';
  }

  @override
  String get aboutApp => 'アプリについて';

  @override
  String get aboutAppContent =>
      'Valorantのインタラクティブなラインナップを提供する無料アプリ。\n\nRiot Gamesとは提携していません。';

  @override
  String get feedback => 'フィードバック';

  @override
  String get viewTutorial => 'チュートリアルを見る';

  @override
  String get signOutMenuTitle => 'アカウントからログアウト';

  @override
  String get dangerZone => '危険ゾーン';

  @override
  String get dangerZoneDesc => 'アカウント削除は元に戻せません。全ての進行状況とレベルが失われます。';

  @override
  String get deleteMyAccount => 'アカウントを削除';

  @override
  String get notifications => '通知';

  @override
  String get noNotifications => '通知なし';

  @override
  String nextLineupIn(int minutes) {
    return '$minutes分後に次のラインナップ。';
  }

  @override
  String get approvedStat => '承認済み';

  @override
  String get totalStat => '合計';

  @override
  String get cooldownStat => 'CD';

  @override
  String newCount(int count) {
    return '$count個の新着';
  }

  @override
  String get link => '連携';

  @override
  String get change => '変更';

  @override
  String get defaultPlayer => 'プレイヤー';

  @override
  String get favorites => 'お気に入り';

  @override
  String get addToCollection => 'コレクションに追加';

  @override
  String get removeFromFavorites => 'お気に入りから削除';

  @override
  String get addToFavorites => 'お気に入りに追加';

  @override
  String get lineupFrom => 'ラインナップ作成者:';

  @override
  String get description => '説明';

  @override
  String get screenshots => 'スクリーンショット';

  @override
  String get possiblyOutdated => '古い可能性あり — ユーザーが不正確さを報告しています';

  @override
  String get isRelevant => '有効？';

  @override
  String get needLevel2 => 'レベル2が必要';

  @override
  String get loginRequired => 'アカウントにログイン';

  @override
  String get votingFromLevel2 => '投票はレベル2から利用できます。\n\n広告を見ることで — 投票がカウントされます！';

  @override
  String get howToGetLevel2 => 'レベル2の取得方法？ →';

  @override
  String get loginToVote => '投票するにはログインしてください。';

  @override
  String get watchAd => '📺 広告を見る';

  @override
  String get yourVote => 'あなたの投票';

  @override
  String get isLineupRelevant => 'ラインナップは現在有効ですか？';

  @override
  String get outdated => '古い';

  @override
  String get relevant => '有効';

  @override
  String get authorProfileUnavailable => '作成者のプロフィールは利用できません';

  @override
  String get alreadyVoted => 'このラインナップにはすでに投票しました';

  @override
  String get adLoading => '広告を読み込み中、少し待ってから試してください...';

  @override
  String get voteAccepted => '✅ 投票が記録されました！';

  @override
  String get voteSaveError => '投票の保存エラー';

  @override
  String get watchAdFull => '広告を最後まで見てください';

  @override
  String get adUnavailable => '広告は利用できません、後で試してください';

  @override
  String get watchAdForAccess => 'アクセスするには広告を最後まで見てください';

  @override
  String get adLabel => '📺 広告';

  @override
  String downloadingPercent(String percent) {
    return '読み込み中 $percent%...';
  }

  @override
  String get loadingAd => '広告を読み込み中...';

  @override
  String get savingVideo => '動画を保存中...';

  @override
  String get savedOffline => '保存済み — オフラインで利用可能';

  @override
  String get onlineOnly => 'オンラインのみ';

  @override
  String get saveOffline => 'オフラインで保存';

  @override
  String get videoSaved => '動画が保存されました';

  @override
  String get videoLoadError => '動画を読み込めませんでした';

  @override
  String get videoComingSoon => '動画は近日公開';

  @override
  String get videoSavedSuccess => '✅ 動画が保存されました — オフラインで利用可能！';

  @override
  String get downloadError => 'ダウンロードエラー、もう一度試してください';

  @override
  String get needExclusiveForLike => 'いいねには限定アクセスが必要です';

  @override
  String get exclusiveLineup => '限定ラインナップ';

  @override
  String get watchAdForExclusive => '広告を見て1時間すべての限定ラインナップをアンロック';

  @override
  String get watchAdAccessBtn => '▶ 広告を見る → 1時間アクセス';

  @override
  String get watchAdForSave => '動画を保存するには広告を最後まで見てください';

  @override
  String get thanksForAd => '広告を見てくれてありがとうございます！';

  @override
  String get adHelpsUs => 'アプリの開発に役立ちます 💪';

  @override
  String patchVersion(String version) {
    return 'パッチ $version';
  }

  @override
  String get difficultyEasy => '簡単';

  @override
  String get difficultyMedium => '普通';

  @override
  String get difficultyHard => '難しい';

  @override
  String screenshotN(int n) {
    return 'スクリーンショット $n';
  }

  @override
  String get exclusiveTag => '⭐ 限定';

  @override
  String get howToGetLevel2Title => 'レベル2の取得方法？';

  @override
  String get xpDesc =>
      'アプリにラインナップを投稿してください — 各投稿でXPを獲得します。十分なXPを集めるとレベルアップします。';

  @override
  String get lineupRequirementsTitle => '📋 ラインナップ要件';

  @override
  String get gotItWillPost => 'わかりました、投稿します！';

  @override
  String get tabMolly => 'Molly';

  @override
  String get tabReveal => 'リビール';

  @override
  String get tabSmoky => 'スモーク';

  @override
  String get timingsSectionTitle => '⏱ タイミング';

  @override
  String get searchLineups => 'ラインナップを検索...';

  @override
  String get nothingFound => '見つかりません 🔍';

  @override
  String get language => '言語';

  @override
  String get languageTitle => 'Language / Язык';

  @override
  String get favoritesLoadError => 'データを読み込めませんでした。インターネットを確認して再試行してください';

  @override
  String get favoritesEmpty => '保存されたラインナップなし';

  @override
  String get favoritesEmptyDesc => '保存するにはラインナップのブックマークアイコンをタップしてください';

  @override
  String get feedbackTitle => 'フィードバック';

  @override
  String get feedbackSendTab => '送信';

  @override
  String get feedbackMyMessages => 'マイメッセージ';
}
